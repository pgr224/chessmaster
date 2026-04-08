/**
 * Install Prompt Handler for Chess Master PWA & Native App
 */

let deferredInstallPrompt = null;
const APK_DOWNLOAD_URL = '/downloads/chessmaster.apk';
const DMG_DOWNLOAD_URL = '/downloads/chessmaster.dmg'; // Placeholder for Apple direct download
const VAPID_PUBLIC_KEY = 'BCX...'; // USER: Please replace with your actual VAPID Public Key

function isIOS() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent);
}

function showInstallBanner() {
    if (isStandalone()) return;
    if (document.getElementById('install-banner-overlay')) return;

    const overlay = document.createElement('div');
    overlay.id = 'install-banner-overlay';
    overlay.style.display = 'flex';

    const isAndroid = /android/i.test(navigator.userAgent);
    const isIOSDevice = isIOS();
    const isDesktop = !isMobile();

    overlay.innerHTML = `
        <div id="install-banner-content" role="dialog" aria-modal="true" aria-labelledby="install-banner-title">
            <button id="close-install" aria-label="Close install banner">&times;</button>
            <img id="install-banner-icon" src="icons/Icon-192.png" alt="Chess Master">
            <div id="install-banner-title">Install Chess Master</div>
            <div id="install-banner-text">Install for faster launch and offline play. Share with friends in one tap.</div>
            ${isIOSDevice ? '<div id="install-banner-hint">On iPhone/iPad: tap Share, then Add to Home Screen.</div>' : ''}

            <div id="banner-actions">
                <button class="install-button" id="pwa-install-btn">Install</button>
                <button id="share-banner-btn" class="secondary-action">Share</button>
            </div>

            <div id="direct-downloads">
                ${isAndroid ? `<a href="${APK_DOWNLOAD_URL}" class="direct-link">Download Android APK</a>` : ''}
                ${isIOS || isDesktop ? `<a href="${DMG_DOWNLOAD_URL}" class="direct-link">Download for macOS/iOS</a>` : ''}
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Capture the PWA install prompt event
    const pwaBtn = document.getElementById('pwa-install-btn');
    const closeBanner = () => {
        overlay.remove();
        sessionStorage.setItem('install_banner_dismissed', 'true');
    };

    if (!deferredInstallPrompt) {
        pwaBtn.style.opacity = '0.5';
        pwaBtn.innerText = isIOSDevice ? 'Open Share Menu' : 'Install from Browser Menu';
    }

    // Handlers
    document.getElementById('close-install').addEventListener('click', closeBanner);
    overlay.addEventListener('click', (event) => {
        if (event.target === overlay) closeBanner();
    });

    document.getElementById('share-banner-btn').addEventListener('click', () => {
        if (navigator.share) {
            navigator.share({
                title: 'Chess Master',
                text: 'Play the best chess app online! ♟️',
                url: window.location.origin,
            });
        } else {
            alert('Copy this link to share: ' + window.location.origin);
        }
    });

    pwaBtn.addEventListener('click', async () => {
        if (deferredInstallPrompt) {
            deferredInstallPrompt.prompt();
            const { outcome } = await deferredInstallPrompt.userChoice;
            console.log(`User response to install prompt: ${outcome}`);
            deferredInstallPrompt = null;
        }
        
        // Always try to request notification permission after intent
        requestNotificationPermission();
        closeBanner();
    });
}

/**
 * Web Push Subscription Logic
 */
async function requestNotificationPermission() {
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
        console.log('Notification permission granted.');
        await subscribeUser();
    }
}

async function subscribeUser() {
    try {
        const registration = await navigator.serviceWorker.ready;
        const subscription = await registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
        });

        // Send to our Cloudflare backend
        const userId = localStorage.getItem('chess_user_id'); // Assuming stored on login
        if (userId) {
            await fetch('/api/push/subscribe', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ userId, subscription })
            });
            console.log('User is subscribed to Push Notifications');
        }
    } catch (e) {
        console.error('Failed to subscribe user:', e);
    }
}

function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
        outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
}

// Check if running in standalone mode (already installed PWA)
function isStandalone() {
    return (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true);
}

// Detect mobile device
function isMobile() {
    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    return /android/i.test(userAgent) || (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream);
}

window.addEventListener('beforeinstallprompt', (e) => {
    // Let supported browsers manage their native install prompt flow.
    // We store the event only as a best-effort fallback, but we do not
    // call preventDefault here, which removes the browser warning about
    // suppressing the prompt without ever showing it.
    deferredInstallPrompt = e;
});

window.addEventListener('appinstalled', () => {
    deferredInstallPrompt = null;
    const overlay = document.getElementById('install-banner-overlay');
    if (overlay) {
        overlay.remove();
    }
});

// For iOS, which doesn't support beforeinstallprompt, we show it manually
if (isMobile() && isIOS() && !isStandalone()) {
    setTimeout(showInstallBanner, 3000);
}
