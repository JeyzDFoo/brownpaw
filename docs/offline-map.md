# Offline map

## What's built

- **Me > Offline > Offline map > Download** (iPhone and Android apps)
  saves the Lower Mainland and Sea to Sky (Squamish/Whistler to the
  border, the Strait to Hope) at overview zooms, then close-ups around
  every run's put-in, take-out and pin: zoom 13 within 6 km, 14 within
  3 km, 15 within 1.5 km. About 3,500 tiles, roughly 80 to 90 MB. It skips
  tiles already saved, so **Update** only fetches what's missing.
- Every map uses saved tiles first and the network after
  (`lib/widgets/map_tiles.dart`); with no signal the map still draws.
- The web app keeps tiles you've viewed (service worker), but has no
  download button: browsers limit storage too much for a whole region.
- The card only appears when the app is built with a tile provider that
  allows offline downloads. OpenStreetMap's free tiles forbid bulk
  downloading, so with the default tiles nothing changes for users.
- Maps now show the providers' required credit line.

## Recommended provider: Stadia Maps

| Provider | Offline downloads | Cost |
|---|---|---|
| **Stadia Maps** | Allowed on a paid plan, up to 100 MB of tiles per device, cache headers respected | Paid plans from $20/month |
| Thunderforest (Outdoors) | "Bulk downloading" only on Small Business | $255/month |
| OpenStreetMap | Not allowed | Free |
| Self-hosted (Protomaps PMTiles) | Unlimited | Storage/egress only, but needs a vector map renderer: a bigger build |

Stadia's "Outdoors" style shows rivers, terrain and trails well for
paddling. The 3,500-tile plan is sized to stay under its 100 MB limit.

## Turn it on

1. Sign up at stadiamaps.com, pick a paid plan that covers commercial
   mobile use, create a property and copy its API key. Under the
   property's authentication settings, allow the app's bundle ids.
2. Build with:

       --dart-define=MAP_TILE_URL='https://tiles.stadiamaps.com/tiles/outdoors/{z}/{x}/{y}.png?api_key=YOUR_KEY'
       --dart-define=MAP_TILE_ATTRIBUTION='© Stadia Maps © OpenMapTiles © OpenStreetMap contributors'

   for example `flutter build ipa --dart-define=...` and
   `flutter build appbundle --dart-define=...`. The key ships in the app
   (map keys always do); restrict it to the app in Stadia's dashboard.
   Building the web app with the same flags switches its tiles too (keep
   the web domain on the key's allow list).
3. Open Me > Offline map > Download on Wi-Fi.

Sources: https://stadiamaps.com/faqs/ ,
https://docs.stadiamaps.com/tutorials/offline-maps-with-flutter-maplibre-gl ,
https://www.thunderforest.com/terms/ , https://www.thunderforest.com/pricing/
