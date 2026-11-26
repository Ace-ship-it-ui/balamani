'use strict';

const offlinePage = new URL('offline.html', self.registration.scope).href;
const cacheName = 'balamani-bookings-offline-v1';

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.add(offlinePage)));
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET' || event.request.mode !== 'navigate'
    || !event.request.url.startsWith(self.registration.scope)) return;

  event.respondWith(fetch(event.request).catch(async () => {
    const cache = await caches.open(cacheName);
    return (await cache.match(offlinePage)) || Response.error();
  }));
});
