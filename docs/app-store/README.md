# App Store product page images

Rendered from the real Flutter screens with sample Lower Mainland data
(test/store_screenshots), then framed by tool/store_assets/compose.py.

| File | Size | Where it goes in App Store Connect |
| --- | --- | --- |
| `iphone-6.9/*.png` | 1320 x 2868 | App Previews and Screenshots, iPhone 6.9" |
| `iphone-6.5/*.png` | 1284 x 2778 | iPhone 6.5" (only needed if 6.9" is not supplied) |
| `iphone-6.3/*.png` | 1206 x 2622 | iPhone with Dynamic Island (medium display), 6.1"/6.3" |
| `universal-5244x2950.png` | 5244 x 2950 (16:9) | Header, with "Use header asset in search results" ticked: fills both slots |
| `header-3840x1646.png` | 3840 x 1646 (21:9) | Header and Search Results, Header |
| `search-results-3840x2560.png` | 3840 x 2560 (3:2) | Header and Search Results, Search Results |

Header and search results assets show on iOS 27 and later, are optional and
are reviewed separately from app versions.

Screenshot order: logbook (put-in check-in), quick log, gauges, gauge chart,
guide, run beta, dark mode.

## Regenerate

    STORE_SHOTS=1 flutter test test/store_screenshots
    python3 tool/store_assets/compose.py   # needs Pillow

Captions live in `SHOTS` in compose.py. Map tiles are off in tests, so the
guide is shown as a list and the run page is scrolled past its map.

Play Store graphics (feature graphic 1024 x 500, phone screenshots) are not
made yet; compose.py can add them from the same raw screens.
