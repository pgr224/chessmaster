/**
 * Install Prompt Handler for Chess Master PWA & Native App
 */

let deferredInstallPrompt = null;
const GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=com.chessmaster.app';
const APP_STORE_URL = 'https://apps.apple.com/app/chess-master-premium/id1234567890'; // Replace with real ID if available

// Check if running in standalone mode (already installed PWA)
function isStandalone() {
    return (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true);
}

// Detect mobile device
function isMobile() {
    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    return /android/i.test(userAgent) || (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream);
}

// Show the premium install banner
function showInstallBanner() {
    // Prevent showing if already standalone (app version)
    if (isStandalone()) return;

    // Only show on mobile devices since these have "native app" formats
    if (!isMobile()) return;

    // Check if dismissed recently (session based or localstorage)
    const dismissed = sessionStorage.getItem('install_banner_dismissed');
    if (dismissed === 'true') return;

    const overlay = document.createElement('div');
    overlay.id = 'install-banner-overlay';
    overlay.style.display = 'flex';

    const isAndroid = /android/i.test(navigator.userAgent);
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    
    let storeUrl = isAndroid ? GOOGLE_PLAY_URL : APP_STORE_URL;
    let storeName = isAndroid ? 'Google Play' : 'App Store';
    let storeIcon = isAndroid ? 'assets/icons/play_store.png' : 'assets/icons/app_store.png'; // Placeholder path

    overlay.innerHTML = `
        <div id="install-banner-content">
            <div id="install-banner-inner">
                <img id="install-banner-icon" src="icons/Icon-192.png" alt="Chess Master">
                <div id="install-banner-title">Chess Master</div>
                <div id="install-banner-text">Experience the full premium chess adventure. High performance, zero lag, and instant play.</div>
                
                <a href="${storeUrl}" target="_blank" class="install-button" id="store-install-btn">
                     Install on ${storeName}
                </a>

                <button class="install-button pwa-button" id="pwa-install-btn" style="display: none;">
                    Add to Home Screen
                </button>

                <div id="dismiss-install">Continue in Browser</div>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Initial handle for native PWA prompt if available
    const pwaBtn = document.getElementById('pwa-install-btn');
    if (deferredInstallPrompt) {
        pwaBtn.style.display = 'flex';
    }

    // Handlers
    document.getElementById('dismiss-install').addEventListener('click', () => {
        overlay.style.display = 'none';
        sessionStorage.setItem('install_banner_dismissed', 'true');
    });

    document.getElementById('pwa-install-btn').addEventListener('click', async () => {
        if (deferredInstallPrompt) {
            deferredInstallPrompt.prompt();
            const { outcome } = await deferredInstallPrompt.userChoice;
            console.log(`User response to install prompt: ${outcome}`);
            deferredInstallPrompt = null;
            overlay.style.display = 'none';
        }
    });

    document.getElementById('store-install-btn').addEventListener('click', () => {
        overlay.style.display = 'none';
    });
}

// Capture the PWA install prompt event
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredInstallPrompt = e;
    
    const pwaBtn = document.getElementById('pwa-install-btn');
    if (pwaBtn) {
        pwaBtn.style.display = 'flex';
    }

    // Optionally show banner automatically on the first suitable event
    setTimeout(showInstallBanner, 5000); // 5s delay for non-intrusive start
});

// For iOS, which doesn't support beforeinstallprompt, we show it manually
if (isMobile() && /iPad|iPhone|iPod/.test(navigator.userAgent) && !isStandalone()) {
    setTimeout(showInstallBanner, 3000);
}
