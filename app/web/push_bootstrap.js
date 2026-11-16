/** Push setup runs after launch; permission is requested only from an explicit action. */
(function () {
  'use strict';

  let registrationPromise;
  let syncing;
  let syncingAllowsDisabled = false;
  let generation = 0;
  let syncingGeneration = 0;
  let apiBase;

  function readStoredValue(key) {
    let value = localStorage.getItem(key) ?? localStorage.getItem(`flutter.${key}`);
    // SharedPreferences JSON-encodes strings; older clients stored values directly.
    for (let i = 0; i < 2 && typeof value === 'string'; i++) {
      try { value = JSON.parse(value); } catch (_) { break; }
    }
    return value;
  }

  function register() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(null);
    if (!registrationPromise) {
      const scope = new URL('.', document.baseURI);
      registrationPromise = navigator.serviceWorker.register(new URL('sw.js', scope).href, {
        scope: scope.pathname,
      }).then(registration => registration.active ? registration : navigator.serviceWorker.ready).catch(() => {
        registrationPromise = null;
        return null;
      });
    }
    return registrationPromise;
  }

  function decodeKey(key) {
    const padded = key + '='.repeat((4 - key.length % 4) % 4);
    return Uint8Array.from(atob(padded.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
  }

  async function syncSubscription(allowDisabled, startedAt) {
    if (!apiBase || !('PushManager' in window) || !('Notification' in window) ||
        Notification.permission !== 'granted') return false;

    try {
      const rawToken = readStoredValue('auth_token');
      const user = readStoredValue('user_data');
      const token = typeof rawToken === 'string' ? rawToken.replace(/^Bearer\s+/i, '').trim() : '';
      if (!token || !user?.id || user.is_guest ||
          (!allowDisabled && readStoredValue('notifications') === false)) return false;

      const registration = await register();
      if (!registration || startedAt !== generation) return false;
      let subscription = await registration.pushManager.getSubscription();
      if (startedAt !== generation) return false;
      // An existing subscription already carries its application server key.
      if (!subscription) {
        const response = await fetch(`${apiBase}/api/push/vapid-public-key`);
        if (!response.ok) return false;
        const { publicKey } = await response.json();
        if (!publicKey || startedAt !== generation) return false;
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: decodeKey(publicKey),
        });
      }
      if (startedAt !== generation) {
        await subscription.unsubscribe();
        return false;
      }
      const response = await fetch(`${apiBase}/api/push/subscribe`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ userId: user.id, deviceId: user.device_id || 'web', subscription }),
      });
      return response.ok;
    } catch (_) {
      // Storage, push support and connectivity are optional for playing chess.
      return false;
    }
  }

  function sync(allowDisabled = false) {
    // The settings toggle persists asynchronously. Its explicit enable action takes
    // precedence over the previous stored value, including a pending passive sync.
    if (syncing && (syncingGeneration !== generation ||
        (allowDisabled && !syncingAllowsDisabled))) {
      return syncing.then(() => sync(allowDisabled));
    }
    if (!syncing) {
      syncingAllowsDisabled = allowDisabled;
      syncingGeneration = generation;
      syncing = syncSubscription(allowDisabled, generation).finally(() => { syncing = null; });
    }
    return syncing;
  }

  window.ChessPush = {
    configure(url) {
      if (typeof url === 'string' && url.trim()) apiBase = url.trim().replace(/\/+$/, '');
    },
    sync: () => sync(),
    async enable() {
      if (!('Notification' in window) || !('PushManager' in window)) return false;
      try {
        if (Notification.permission === 'default') await Notification.requestPermission();
        return await sync(true);
      } catch (_) { return false; }
    },
    async disable() {
      // Invalidate pending subscription creation before touching the existing one.
      generation++;
      try {
        if (!('serviceWorker' in navigator)) return;
        const scope = new URL('.', document.baseURI);
        const registration = await (registrationPromise ??
          navigator.serviceWorker.getRegistration(scope.href));
        const subscription = await registration?.pushManager.getSubscription();
        if (!subscription) return;
        // Browser revocation also works after sign-out has removed the JWT.
        await subscription.unsubscribe();
        const rawToken = readStoredValue('auth_token');
        const token = typeof rawToken === 'string' ? rawToken.replace(/^Bearer\s+/i, '').trim() : '';
        if (apiBase && token) await fetch(`${apiBase}/api/push/unsubscribe`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ endpoint: subscription.endpoint }),
        });
      } catch (_) { /* Local revocation must not block sign-out or settings. */ }
    },
  };

  // Registration and subscription must not compete with Flutter's initial download.
  window.addEventListener('load', () => {
    const start = () => { register().then(() => sync()); };
    if ('requestIdleCallback' in window) window.requestIdleCallback(start, { timeout: 5000 });
    else setTimeout(start, 0);
  }, { once: true });
})();
