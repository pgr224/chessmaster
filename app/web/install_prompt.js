/**
 * Install Prompt Handler for Chess Master PWA & Native App
 */

let deferredInstallPrompt = null;

function isIOS() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent);
}

function showInstallBanner() {
    if (isStandalone()) return;
    if (document.getElementById('install-banner-overlay')) return;
    try {
        if (sessionStorage.getItem('install_banner_dismissed') === 'true') return;
    } catch (_) {}

    const overlay = document.createElement('div');
    overlay.id = 'install-banner-overlay';
    overlay.style.display = 'flex';

    const isIOSDevice = isIOS();

    overlay.innerHTML = `
        <div id="install-banner-content" role="dialog" aria-modal="true" aria-labelledby="install-banner-title">
            <button id="close-install" aria-label="Close install banner">&times;</button>
            <img id="install-banner-icon" src="icons/Icon-192.png" alt="Chess Master">
            <div id="install-banner-title">Install Chess Master</div>
            <div id="install-banner-text">Add Chess Master to your home screen for quick access. Share with friends in one tap.</div>
            ${isIOSDevice ? '<div id="install-banner-hint">On iPhone/iPad: tap Share, then Add to Home Screen.</div>' : ''}

            <div id="banner-actions">
                <button class="install-button" id="pwa-install-btn">Install</button>
                <button id="share-banner-btn" class="secondary-action">Share</button>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Capture the PWA install prompt event
    const pwaBtn = document.getElementById('pwa-install-btn');
    const closeBanner = () => {
        overlay.remove();
        try { sessionStorage.setItem('install_banner_dismissed', 'true'); } catch (_) {}
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

    document.getElementById('share-banner-btn').addEventListener('click', async () => {
        const url = new URL('.', document.baseURI).href;
        if (navigator.share) {
            try {
                await navigator.share({ title: 'Chess Master', text: 'Play chess with me! ♟️', url });
            } catch (_) {}
        } else {
            alert('Copy this link to share: ' + url);
        }
    });

    pwaBtn.addEventListener('click', async () => {
        try {
            if (deferredInstallPrompt) {
                await deferredInstallPrompt.prompt();
                await deferredInstallPrompt.userChoice;
                deferredInstallPrompt = null;
            }
        } catch (_) {}
        closeBanner();
    });
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
    window.addEventListener('flutter-first-frame', () => {
        setTimeout(showInstallBanner, 3000);
    }, { once: true });
}
