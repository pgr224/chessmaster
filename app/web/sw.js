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

  if (event.action === 'close') return;
  const data = event.notification.data || {};
  const scope = self.registration.scope;
  const targetUrl = new URL(scope);
  const params = new URLSearchParams();
  if (data.requestId && data.type === 'CHALLENGE_RECEIVED') {
    params.set('accept_challenge', data.requestId);
    if (event.action === 'accept') params.set('auto_accept', 'true');
  } else if (data.requestId && data.type === 'XP_DIRECT_REQUEST') {
    params.set('xp_request_id', data.requestId);
    if (event.action === 'accept_xp') params.set('auto_accept_xp', 'true');
    if (event.action === 'reject_xp') params.set('auto_reject_xp', 'true');
  }
  // Flutter's default router uses hash URLs. Preserve the app's deployment base.
  if(data.tournamentId)targetUrl.hash=`/tournament/${encodeURIComponent(data.tournamentId)}`;
  else if(data.gameId)targetUrl.hash=`/room/${encodeURIComponent(data.gameId)}`;
  else if (params.size) targetUrl.hash = `/lobby?${params}`;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.startsWith(scope) && 'focus' in client) {
          return client.navigate(targetUrl.href).then(c => c ? c.focus() : undefined);
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl.href);
      }
    })
  );
});

// This worker only handles push; static assets use the browser's HTTP cache.
self.addEventListener('install', (e) => {
    // skipWaiting ensures the new SW activates immediately
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(clients.claim());
});
