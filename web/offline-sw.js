// Lets Brownpaw open with no signal, e.g. at a put-in.
//
// - The app itself (this site's files): network first, so a deploy shows
//   up straight away online; the last copy is used offline.
// - Flutter's engine, the Firebase SDK and fonts from Google's CDNs:
//   versioned URLs, so cache first. Without the Firebase SDK the app
//   can't start offline.
// - Map tiles you've already looked at: cache first, refreshed in the
//   background, capped at MAX_TILES. This only keeps tiles you viewed; it
//   never downloads areas in bulk, which OpenStreetMap doesn't allow.
// - Everything else (Firestore, sign-in) goes straight to the network;
//   Firestore keeps its own offline copy.

const APP_CACHE = 'brownpaw-app-v1';
const CDN_CACHE = 'brownpaw-cdn-v1';
const TILE_CACHE = 'brownpaw-tiles-v1';
const CACHES = [APP_CACHE, CDN_CACHE, TILE_CACHE];
const MAX_TILES = 3000;
const PRECACHE = [
  './', 'index.html', 'flutter_bootstrap.js', 'main.dart.js',
  'manifest.json', 'favicon.png',
  'splash/img/light-2x.png', 'splash/img/dark-2x.png',
  'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm',
  'assets/FontManifest.json', 'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  // What the app needs to start. The first visit fetches these before this
  // worker is running, so fetch them again here; one missing file (e.g.
  // a renderer variant a build doesn't have) mustn't stop the rest.
  event.waitUntil(caches.open(APP_CACHE).then((cache) => Promise.all(
    PRECACHE.map((path) => cache.add(path).catch(() => {})),
  )));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (!CACHES.includes(name)) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);

  if (url.origin === self.location.origin) {
    if (url.pathname.startsWith('/__/')) return; // Firebase Hosting internals
    event.respondWith(networkFirst(request, request.mode === 'navigate'));
  } else if (url.hostname === 'www.gstatic.com'
      && (url.pathname.startsWith('/flutter-') || url.pathname.startsWith('/firebasejs/'))
      || url.hostname === 'fonts.gstatic.com'
      || url.hostname === 'fonts.googleapis.com') {
    event.respondWith(cacheFirst(request, CDN_CACHE));
  } else if (url.hostname === 'tile.openstreetmap.org') {
    event.respondWith(tile(event, request));
  }
});

async function networkFirst(request, isNavigation) {
  const cache = await caches.open(APP_CACHE);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(isNavigation ? 'index.html' : request, response.clone());
    return response;
  } catch (e) {
    const cached = await cache.match(isNavigation ? 'index.html' : request,
      { ignoreSearch: !isNavigation });
    if (cached) return cached;
    throw e;
  }
}

async function cacheFirst(request, name) {
  const cache = await caches.open(name);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok || response.type === 'opaque') cache.put(request, response.clone());
  return response;
}

async function tile(event, request) {
  const cache = await caches.open(TILE_CACHE);
  const cached = await cache.match(request);
  const refresh = fetch(request).then(async (response) => {
    if (response.ok) {
      await cache.put(request, response.clone());
      await trimTiles(cache);
    }
    return response;
  });
  if (cached) {
    event.waitUntil(refresh.catch(() => {}));
    return cached;
  }
  return refresh;
}

async function trimTiles(cache) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - MAX_TILES; i++) await cache.delete(keys[i]);
}
