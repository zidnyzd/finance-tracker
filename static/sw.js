const CACHE = 'zira-v1';
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll([
      '/', '/login', '/static/manifest.json'
    ]))
  );
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(k => k !== CACHE).map(k => caches.delete(k))
  )));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(r =>
      r || fetch(e.request).then(fr => {
        if (fr.ok && fr.type === 'basic') {
          const clone = fr.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return fr;
      })
    )
  );
});
