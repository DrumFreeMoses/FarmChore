// FarmChore Service Worker
// Handles offline caching and background WebSocket push notifications.

const CACHE_NAME = 'farmchore-v3';
const RELAY_CONNECT = 'farmchore-relay-connect';
const RELAY_EVENT = 'farmchore-relay-event';

// Static assets to pre-cache for offline use.
const PRECACHE = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
];

// ── Install: pre-cache static assets ────────────────────────────

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE))
  );
  self.skipWaiting();
});

// ── Activate: clean old caches ──────────────────────────────────

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// ── Fetch: cache-first for static assets, network-first for API ─

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Never cache WebSocket or API requests.
  if (url.protocol === 'ws:' || url.protocol === 'wss:') return;
  if (url.pathname.startsWith('/api/')) return;

  // Never cache sw.js itself — always fetch fresh so updates propagate.
  if (url.pathname.endsWith('sw.js')) return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        // Only cache same-origin GET responses.
        if (event.request.method !== 'GET') return response;
        if (url.origin !== self.location.origin) return response;
        if (!response.ok) return response;
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      });
    })
  );
});

// ── Background WebSocket relay connection ───────────────────────
// The main app sends a 'farmchore-relay-connect' message with {relayUrl, pubkey}.
// The service worker opens a WebSocket, subscribes for events tagged with
// the user's pubkey, and shows browser notifications when events arrive.

let relayWs = null;
let relaySubId = null;
let relayPubkey = null;

self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || !data.type) return;

  switch (data.type) {
    case RELAY_CONNECT:
      connectToRelay(data.relayUrl, data.pubkey, data.apiKey);
      break;
    case 'farmchore-relay-disconnect':
      disconnectRelay();
      break;
  }
});

function connectToRelay(url, pubkey, apiKey) {
  disconnectRelay();
  relayPubkey = pubkey;

  // Append API key as query parameter if provided.
  let connectUrl = url;
  if (apiKey) {
    const separator = url.includes('?') ? '&' : '?';
    connectUrl = url + separator + 'key=' + encodeURIComponent(apiKey);
  }

  try {
    relayWs = new WebSocket(connectUrl);

    relayWs.onopen = () => {
      console.log('[SW] Relay connected:', url);
      // Subscribe to events tagged with our pubkey (assignments, comments, etc.).
      relaySubId = 'sw-' + Date.now();
      relayWs.send(JSON.stringify([
        'REQ',
        relaySubId,
        {
          '#p': [pubkey],
          'kinds': [31501, 31502, 31503, 31505, 31506, 31507],
        },
      ]));
    };

    relayWs.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg[0] === 'EVENT' && msg.length >= 3) {
          handleRelayEvent(msg[2]);
        }
      } catch (_) {}
    };

    relayWs.onclose = () => {
      console.log('[SW] Relay disconnected, reconnecting in 10s...');
      setTimeout(() => connectToRelay(url, pubkey, apiKey), 10000);
    };

    relayWs.onerror = () => {
      relayWs?.close();
    };
  } catch (_) {
    setTimeout(() => connectToRelay(url, pubkey), 10000);
  }
}

function disconnectRelay() {
  if (relayWs) {
    relayWs.onclose = null;
    relayWs.close();
    relayWs = null;
  }
  relaySubId = null;
}

function handleRelayEvent(event) {
  // Determine notification title and body from event kind.
  let title = 'FarmChore';
  let body = '';
  const kind = event.kind;

  if (kind === 31502) {
    // Assignment
    const assignee = getTag(event, 'p');
    body = assignee ? 'New chore assigned to you' : 'New chore assignment';
  } else if (kind === 31505) {
    // Heads-up
    body = event.content || 'New heads-up from the farm';
  } else if (kind === 31506) {
    // Farm message
    body = event.content || 'New message from the farm';
  } else if (kind === 31507) {
    // Comment
    body = event.content || 'New comment on a chore';
  } else if (kind === 31503) {
    // Edit
    body = event.content || 'A chore was updated';
  } else {
    return; // Don't notify for other kinds.
  }

  // Don't notify for our own events.
  if (event.pubkey === relayPubkey) return;

  // Show the notification.
  self.registration.showNotification(title, {
    body: body.substring(0, 200),
    icon: './icons/Icon-192.png',
    badge: './icons/Icon-192.png',
    tag: event.id, // Deduplicates if same event arrives twice.
    data: { eventId: event.id, kind: kind },
  });
}

function getTag(event, tagName) {
  if (!event.tags) return null;
  for (const tag of event.tags) {
    if (tag[0] === tagName) return tag[1];
  }
  return null;
}

// ── Notification click: focus the app ──────────────────────────

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clients) => {
      // If app is already open, focus it.
      for (const client of clients) {
        if (client.url.includes('./') && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open the app.
      return self.clients.open('./');
    })
  );
});
