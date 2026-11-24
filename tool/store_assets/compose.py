"""Frames the rendered app screens into App Store marketing images.

Run from the repo root after rendering the screens:

    STORE_SHOTS=1 flutter test test/store_screenshots
    python3 tool/store_assets/compose.py

Writes to docs/app-store/: iPhone 6.9" and 6.5" screenshots, the product
page header (3840x1646, 21:9) and the search results image (3840x2560, 3:2).
Needs Pillow.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SCREENS = ROOT / "build" / "store_screens"
OUT = ROOT / "docs" / "app-store"
FONTS = ROOT / "fonts"

# Riverstone palette (lib/theme/app_theme.dart).
LIGHT = dict(
    paper=(236, 239, 234), ink=(58, 43, 34), muted=(122, 106, 94),
    faint=(220, 225, 218), accent=(166, 90, 36), glacier=(44, 124, 130),
    glacier_soft=(214, 236, 236), bezel=(32, 28, 25),
)
DARK = dict(
    paper=(27, 25, 22), ink=(241, 232, 222), muted=(181, 166, 152),
    faint=(54, 48, 43), accent=(224, 147, 90), glacier=(111, 193, 197),
    glacier_soft=(31, 59, 61), bezel=(70, 63, 57),
)

SHOTS = [
    ("1_logbook", "Your season,\nlogged for you",
     "It spots you at the put-in and fills in the flow.", LIGHT),
    ("2_quick_log", "Log a run\nin seconds",
     "Run, date, flow and crew are already filled in.", LIGHT),
    ("3_gauges", "Every gauge\nyou paddle",
     "Live flows for Lower Mainland rivers, at a glance.", LIGHT),
    ("4_gauge", "Know when\nit's running",
     "Two weeks of flow, and an alert when it's in.", LIGHT),
    ("5_guide", "Find your\nnext run",
     "See what's running now, Chilliwack to Squamish.", LIGHT),
    ("6_run_scrolled", "Beta for\nevery run",
     "Put-ins, take-outs and hazards for each run.", LIGHT),
    ("1_logbook_dark", "Easy on the eyes\nat dawn patrol",
     "Light and dark, to match your phone.", DARK),
]


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"Nunito-{weight}.ttf"), int(size))


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def with_status_bar(screen, dark):
    """Adds the iOS status bar, Dynamic Island and home indicator."""
    im = screen.convert("RGB").copy()
    d = ImageDraw.Draw(im)
    s = im.width / 440  # pixels per point
    fg = (241, 232, 222) if dark else (20, 16, 14)
    # Time.
    d.text((72 * s, 31 * s), "9:41", font=font(800, 17 * s), fill=fg,
           anchor="mm")
    # Dynamic Island.
    iw, ih, top = 125 * s, 37 * s, 11 * s
    d.rounded_rectangle(((im.width - iw) / 2, top, (im.width + iw) / 2,
                         top + ih), radius=ih / 2, fill=(0, 0, 0))
    # Signal bars.
    x, base = 330 * s, 37 * s
    for i, h in enumerate((4, 6.5, 9, 11.5)):
        bx = x + i * 4.6 * s
        d.rounded_rectangle((bx, base - h * s, bx + 3 * s, base),
                            radius=0.8 * s, fill=fg)
    # Wi-Fi: three arcs.
    cx, cy = 364 * s, 38 * s
    for r in (11.5, 7.5, 3.5):
        rr = r * s
        if r == 3.5:
            d.pieslice((cx - rr, cy - rr, cx + rr, cy + rr), 225, 315,
                       fill=fg)
        else:
            d.arc((cx - rr, cy - rr, cx + rr, cy + rr), 225, 315, fill=fg,
                  width=int(2.2 * s))
    # Battery.
    bx, by, bw, bh = 383 * s, 25.5 * s, 25 * s, 12 * s
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=3.5 * s,
                        outline=fg, width=int(1.1 * s))
    d.rounded_rectangle((bx + 2 * s, by + 2 * s, bx + bw - 2 * s,
                         by + bh - 2 * s), radius=2 * s, fill=fg)
    d.rounded_rectangle((bx + bw + 1.2 * s, by + 4 * s, bx + bw + 2.6 * s,
                         by + bh - 4 * s), radius=1 * s, fill=fg)
    # Home indicator.
    hw = 140 * s
    d.rounded_rectangle(((im.width - hw) / 2, im.height - 13 * s,
                         (im.width + hw) / 2, im.height - 8 * s),
                        radius=2.5 * s, fill=fg)
    return im


def phone(screen, width, palette, dark):
    """The screen in a simple rounded bezel, with a soft shadow."""
    screen = with_status_bar(screen, dark)
    sw = int(width)
    sh = round(screen.height * sw / screen.width)
    screen = screen.resize((sw, sh), Image.LANCZOS)
    bezel = round(sw * 0.028)
    radius = round(sw * 0.13)
    fw, fh = sw + 2 * bezel, sh + 2 * bezel
    pad = round(sw * 0.08)
    out = Image.new("RGBA", (fw + 2 * pad, fh + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad, pad + pad * 0.35, pad + fw, pad + fh + pad * 0.35),
        radius=radius + bezel, fill=(30, 20, 10, 70 if not dark else 140))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(pad * 0.45)))
    frame = Image.new("RGBA", (fw, fh), palette["bezel"] + (255,))
    out.paste(frame, (pad, pad), rounded_mask((fw, fh), radius + bezel))
    out.paste(screen, (pad + bezel, pad + bezel),
              rounded_mask((sw, sh), radius))
    return out, pad


def wrap(draw, text, fnt, width):
    lines = []
    for para in text.split("\n"):
        words, line = para.split(), ""
        for w in words:
            trial = (line + " " + w).strip()
            if draw.textlength(trial, font=fnt) <= width or not line:
                line = trial
            else:
                lines.append(line)
                line = w
        lines.append(line)
    return lines


def pebble_blob(size, box, color):
    """A big soft pebble shape behind the phone."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    r = (x1 - x0) * 0.42
    d.rounded_rectangle(box, radius=r, fill=color + (255,))
    return layer


def screenshot(name, title, sub, palette, W, H):
    dark = palette is DARK
    img = Image.new("RGBA", (W, H), palette["paper"] + (255,))
    u = W / 1320  # layout unit
    img.alpha_composite(pebble_blob(
        (W, H), (int(-140 * u), int(1250 * u), int(W + 160 * u),
                 int(H + 600 * u)), palette["faint"]))

    d = ImageDraw.Draw(img)
    y = 150 * u
    tf = font(900, 112 * u)
    for line in title.split("\n"):
        d.text((W / 2, y), line, font=tf, fill=palette["ink"], anchor="ma")
        y += 128 * u
    y += 22 * u
    sf = font(700, 46 * u)
    for line in wrap(d, sub, sf, W - 240 * u):
        d.text((W / 2, y), line, font=sf, fill=palette["muted"], anchor="ma")
        y += 60 * u

    screen = Image.open(SCREENS / f"{name}.png")
    ph, pad = phone(screen, 930 * u, palette, dark)
    top = int(max(y + 50 * u, 700 * u)) - pad
    img.alpha_composite(ph, (int((W - ph.width) / 2), top))
    return img.convert("RGB")


def logo(size, color=None):
    mark = Image.open(ROOT / "images" / "splash.png").convert("RGBA")
    bbox = mark.getbbox()
    mark = mark.crop(bbox)
    scale = size / max(mark.size)
    return mark.resize((round(mark.width * scale), round(mark.height * scale)),
                       Image.LANCZOS)


def hero(W, H, headline, sub, names, palette=LIGHT, phone_w=None,
         text_x=0.10, centre_x=0.725, blob=True):
    """Wide image: brand and headline beside three fanned phones."""
    img = Image.new("RGBA", (W, H), palette["paper"] + (255,))
    u = H / 1646
    if blob:
        img.alpha_composite(pebble_blob(
        (W, H), (int(W * (centre_x - 0.255)), int(H * 0.12), int(W * 1.1),
                 int(H * 1.5)), palette["faint"]))
    d = ImageDraw.Draw(img)

    # Text block, left of centre.
    x = W * text_x
    mark = logo(150 * u)
    tf = font(900, 128 * u)
    lines = headline.split("\n")
    sf = font(700, 62 * u)
    sub_lines = wrap(d, sub, sf, W * 0.30)
    block = mark.height + 60 * u + len(lines) * 145 * u + 30 * u + \
        len(sub_lines) * 82 * u
    y = (H - block) / 2
    img.alpha_composite(mark, (int(x), int(y)))
    d.text((x + mark.width + 36 * u, y + mark.height / 2), "Brownpaw",
           font=font(900, 84 * u), fill=palette["accent"], anchor="lm")
    y += mark.height + 60 * u
    for line in lines:
        d.text((x, y), line, font=tf, fill=palette["ink"])
        y += 145 * u
    y += 30 * u
    for line in sub_lines:
        d.text((x, y), line, font=sf, fill=palette["muted"])
        y += 82 * u

    # Three phones, the middle one forward.
    pw = phone_w or 520 * u
    centre = W * centre_x
    spots = [(-0.95, 0.20, -6), (0.95, 0.20, 6), (0, 0.08, 0)]
    for (name, (dx, dy, rot)) in zip([names[0], names[2], names[1]], spots):
        screen = Image.open(SCREENS / f"{name}.png")
        ph, pad = phone(screen, pw * (1 if dx == 0 else 0.9), palette, False)
        ph = ph.rotate(rot, resample=Image.BICUBIC, expand=True)
        px = centre + dx * pw - ph.width / 2
        py = H * dy
        img.alpha_composite(ph, (int(px), int(py)))
    return img.convert("RGB")


def search(W, H, phrase, names, palette=LIGHT):
    """3:2 search results image: the app's screens, clearly, plus one phrase."""
    img = Image.new("RGBA", (W, H), palette["paper"] + (255,))
    u = H / 2560
    img.alpha_composite(pebble_blob(
        (W, H), (int(-W * 0.05), int(H * 0.45), int(W * 1.05),
                 int(H * 1.6)), palette["faint"]))
    d = ImageDraw.Draw(img)
    d.text((W / 2, 170 * u), phrase, font=font(900, 190 * u),
           fill=palette["ink"], anchor="ma")
    pw = 900 * u
    gap = 130 * u
    total = 3 * pw + 2 * gap
    for i, name in enumerate(names):
        screen = Image.open(SCREENS / f"{name}.png")
        ph, pad = phone(screen, pw, palette, False)
        x = (W - total) / 2 + i * (pw + gap) - pad
        y = 520 * u - pad + (0 if i == 1 else 90 * u)
        img.alpha_composite(ph, (int(x), int(y)))
    return img.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for size, (W, H) in {"iphone-6.9": (1320, 2868),
                         "iphone-6.5": (1284, 2778),
                         "iphone-6.3": (1206, 2622)}.items():
        folder = OUT / size
        folder.mkdir(exist_ok=True)
        for i, (name, title, sub, pal) in enumerate(SHOTS, 1):
            out = screenshot(name, title, sub, pal, W, H)
            out.save(folder / f"{i:02d}_{name.split('_', 1)[1]}.png",
                     optimize=True)

    hero(3840, 1646, "The automated\nwhitewater logbook",
         "Gauges and a guidebook for the Lower Mainland, in your pocket.",
         ["1_logbook", "4_gauge", "5_guide"]).save(
        OUT / "header-3840x1646.png", optimize=True)
    # One 16:9 PNG Apple can use for both slots. Its crops keep about the
    # middle 4425 x 2248, so the design is drawn at that size and centred.
    W, H, sw, sh = 5244, 2950, 4425, 2248
    uni = Image.new("RGBA", (W, H), LIGHT["paper"] + (255,))
    ox, oy = (W - sw) // 2, (H - sh) // 2
    inner = hero(sw, sh, "The automated\nwhitewater logbook",
                 "Gauges and a guidebook for the Lower Mainland, in your "
                 "pocket.", ["1_logbook", "4_gauge", "5_guide"],
                 text_x=0.04, centre_x=0.70, blob=False)
    uni.paste(inner, (ox, oy))
    uni.convert("RGB").save(OUT / "universal-5244x2950.png", optimize=True)
    search(3840, 2560, "Your whitewater logbook",
           ["1_logbook", "4_gauge", "5_guide"]).save(
        OUT / "search-results-3840x2560.png", optimize=True)


if __name__ == "__main__":
    main()
