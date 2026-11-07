const cacheName = 'mizan-v2';
const files = [
  './', 'index.html', 'flutter_bootstrap.js', 'main.dart.js',
  'app_logo.svg', 'sqlite3.wasm', 'sqflite_sw.js',
  'assets/AssetManifest.bin.json', 'assets/AssetManifest.bin', 'assets/FontManifest.json',
  'assets/assets/NotoSansArabic.ttf', 'assets/fonts/MaterialIcons-Regular.otf', 'assets/fonts/fallback/Roboto-Regular.ttf',
  'assets/shaders/ink_sparkle.frag', 'assets/shaders/stretch_effect.frag',
  'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm'
];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache =>
    cache.addAll(files.map(file => new Request(file, {cache: 'reload'})))
  ).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const key of await caches.keys()) {
    if (key.startsWith('mizan-') && key !== cacheName) await caches.delete(key);
  }
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    try {
      const response = await fetch(event.request);
      if (response.ok) await cache.put(event.request, response.clone());
      return response;
    } catch (_) {
      return await cache.match(event.request, {ignoreSearch: true}) ||
        (event.request.mode === 'navigate' ? await cache.match('./') : null) ||
        Response.error();
    }
  })());
});


