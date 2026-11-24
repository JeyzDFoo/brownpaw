{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's own service worker is deprecated and
// only unregisters itself. index.html registers offline-sw.js instead,
// which keeps the app opening with no signal. CanvasKit comes from this
// site rather than Google's CDN so it's cached with the rest of the app.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
});
