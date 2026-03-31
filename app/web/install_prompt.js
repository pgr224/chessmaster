/**
 * Install Prompt Handler for Chess Master PWA & Native App
 */

let deferredInstallPrompt = null;
const APK_DOWNLOAD_URL = '/downloads/chessmaster.apk';
const DMG_DOWNLOAD_URL = '/downloads/chessmaster.dmg'; // Placeholder for Apple direct download
const VAPID_PUBLIC_KEY = 'BCX...'; // USER: Please replace with your actual VAPID Public Key

function showInstallBanner() {
    if (isStandalone()) return;

    const overlay = document.createElement('div');
    overlay.id = 'install-banner-overlay';
    overlay.style.display = 'flex';

    const isAndroid = /android/i.test(navigator.userAgent);
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const isDesktop = !isMobile();

    overlay.innerHTML = `
        <div id="install-banner-content">
            <div id="install-banner-inner">
                <img id="install-banner-icon" src="icons/Icon-192.png" alt="Chess Master">
                <div id="install-banner-title">Chess Master</div>
                <div id="install-banner-text">The full grandmaster experience. Install for offline notifications, zero-lag play, and desktop integration.</div>
                
                <!-- PWA Primary Option -->
                <button class="install-button pwa-button" id="pwa-install-btn">
                    ⭐ Add to Home Screen (Web App)
                </button>

                <div class="divider"><span>OR DOWNLOAD DIRECTLY</span></div>

                <div id="direct-downloads">
                   ${isAndroid ? `
                     <a href="${APK_DOWNLOAD_URL}" class="direct-link anim-pulse">
                        📦 Download Android APK
                     </a>
                   ` : ''}
                   ${isIOS || isDesktop ? `
                     <a href="${DMG_DOWNLOAD_URL}" class="direct-link">
                        🍎 Download for macOS/iOS (.dmg)
                     </a>
                   ` : ''}
                </div>

                <div id="banner-actions">
                    <button id="share-banner-btn" class="secondary-action">🔗 Share App</button>
                    <button id="dismiss-install" class="secondary-action">Continue in Browser</button>
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Capture the PWA install prompt event
    const pwaBtn = document.getElementById('pwa-install-btn');
    if (!deferredInstallPrompt) {
        pwaBtn.style.opacity = '0.5';
        pwaBtn.innerText = 'Add to Home Screen (Use Browser Menu)';
    }

    // Handlers
    document.getElementById('dismiss-install').addEventListener('click', () => {
        overlay.style.display = 'none';
        sessionStorage.setItem('install_banner_dismissed', 'true');
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
        overlay.style.display = 'none';
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
    e.preventDefault();
    deferredInstallPrompt = e;
    setTimeout(showInstallBanner, 5000); 
});

// For iOS, which doesn't support beforeinstallprompt, we show it manually
if (isMobile() && /iPad|iPhone|iPod/.test(navigator.userAgent) && !isStandalone()) {
    setTimeout(showInstallBanner, 3000);
}
