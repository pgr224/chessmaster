/*
 * Chess Master - Custom Service Worker for Web Push Notifications (Firebase-free)
 */

self.addEventListener('push', function(event) {
  if (!(self.Notification && self.Notification.permission === 'granted')) {
    return;
  }

  let data = {};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data = { title: 'Chess Master', body: event.data.text() };
    }
  }

  const category = data?.data?.category || 'system';
  const title = data.title || (category === 'challenges'
    ? '♟️ New Match Invite!'
    : 'Chess Master Notification');
  const isXpRequest = data?.data?.type === 'XP_DIRECT_REQUEST';
  const options = {
    body: data.body || 'Someone challenged you to a game!',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: isXpRequest
      ? [
          { action: 'accept_xp', title: 'Donate Now' },
          { action: 'reject_xp', title: 'Reject' }
        ]
      : [
          { action: 'accept', title: '⚔️ Accept Invite' },
          { action: 'close', title: 'Dismiss' }
        ]
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const data = event.notification.data;
  let targetUrl = '/'; // Default to root

  if (data.type === 'CHALLENGE_RECEIVED' && data.requestId) {
    // Redirect to the Lobby with the challenge ID as a query param
    targetUrl = `/lobby?accept_challenge=${data.requestId}`;
  }

  if (data.type === 'XP_DIRECT_REQUEST' && data.requestId) {
    targetUrl = `/lobby?xp_request_id=${data.requestId}`;
  }

  if (event.action === 'accept') {
     // User specifically clicked "Accept"
     targetUrl += '&auto_accept=true';
  }

  if (event.action === 'accept_xp') {
    targetUrl += '&auto_accept_xp=true';
  }

  if (event.action === 'reject_xp') {
    targetUrl += '&auto_reject_xp=true';
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.includes(new URL('/', self.location.origin).href) && 'focus' in client) {
          return client.navigate(targetUrl).then(c => c.focus());
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// Basic Caching (Optional, but good for PWA feel)
const CACHE_NAME = 'chessmaster-v1';
self.addEventListener('install', (e) => {
    // skipWaiting ensures the new SW activates immediately
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(clients.claim());
});
