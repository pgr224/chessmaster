import fs from 'fs';
import path from 'path';

const paths = {
    king: "M 22.5,11.63 L 22.5,6 L 20,6 L 20,3.5 L 25,3.5 L 25,6 L 22.5,6 L 22.5,11.63 M 20,8 L 25,8 M 22.5,11.63 A 8,8 0 0,0 12,20 L 33,20 A 8,8 0 0,0 22.5,11.63 M 12,20 A 8,8 0 0,0 12,28 M 33,20 A 8,8 0 0,1 33,28 M 12,28 L 33,28 M 12,32 L 33,32 M 11.5,35 L 33.5,35 M 11.5,35 L 11.5,39.5 L 33.5,39.5 L 33.5,35 M 15,32 L 15,35 M 30,32 L 30,35",
    queen: "M 9 26 C 17.5 24.5 30 24.5 36 26 L 38 14 L 31 17 L 30 9 L 25.5 14 L 22.5 9 L 19.5 14 L 15 9 L 14 17 L 7 14 L 9 26 z M 11 26 A 15 15 0 0 0 34 26 M 11 28 A 15 15 0 0 0 34 28 M 11 30 A 15 15 0 0 0 34 30 M 11.5 32 L 33.5 32 L 33.5 36 L 11.5 36 M 15 30 L 15 32 M 30 30 L 30 32 M 8.5 12.5 A 1.5 1.5 0 1 1 5.5 12.5 A 1.5 1.5 0 1 1 8.5 12.5 z M 16.5 7.5 A 1.5 1.5 0 1 1 13.5 7.5 A 1.5 1.5 0 1 1 16.5 7.5 z M 24 7.5 A 1.5 1.5 0 1 1 21 7.5 A 1.5 1.5 0 1 1 24 7.5 z M 31.5 7.5 A 1.5 1.5 0 1 1 28.5 7.5 A 1.5 1.5 0 1 1 31.5 7.5 z M 39.5 12.5 A 1.5 1.5 0 1 1 36.5 12.5 A 1.5 1.5 0 1 1 39.5 12.5 z",
    rook: "M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z M 11 14 L 11 9 L 15 9 L 15 11 L 20 11 L 20 9 L 25 9 L 25 11 L 30 11 L 30 9 L 34 9 L 34 14 L 11 14 z M 31 14 C 31 14 34 23 34 32 L 11 32 C 11 23 14 14 14 14 M 14 14 L 31 14",
    bishop: "M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z M 11 32 L 34 32 C 34 32 32 23 23 23 C 14 23 11 32 11 32 z M 22.5 24 L 22.5 14 M 22.5 11 A 3.5 3.5 0 1 1 22.5 4 A 3.5 3.5 0 1 1 22.5 11 z",
    knight: "M 22 10 C 32 10 32.5 22.5 31 26 C 29 20 23 20 20 20 C 23 27 21 32 15 32 C 13.5 32 11 28 11 28 C 11 28 14 26 14 24 C 14 22 11 20 9 20 C 6.5 20 5 22 5 22 C 5 22 8 13 13 11 C 15 10 18 10 22 10 M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z",
    pawn: "M 22 9 C 19.8 9 18 10.8 18 13 C 18 15.2 19.8 17 22 17 C 24.2 17 26 15.2 26 13 C 26 10.8 24.2 9 22 9 z M 22 18 C 18 18 16 22 16 25 C 16 30 20 32 20 32 L 25 32 C 25 32 28 30 28 25 C 28 22 26 18 22 18 z M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z"
};

const TEMPLATE = (defs, pathD, fill, stroke, stroke_width, filter) => `<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 45 45" xmlns="http://www.w3.org/2000/svg">
  <defs>
    ${defs}
  </defs>
  <path d="${pathD}" fill="${fill}" stroke="${stroke}" stroke-width="${stroke_width}" filter="${filter}" />
</svg>`;

const THEMES = {
    'modern_flat': {
        white: { fill: '#f0f0f0', stroke: '#cccccc', stroke_width: '0', defs: '', filter: '' },
        black: { fill: '#333333', stroke: '#1a1a1a', stroke_width: '0', defs: '', filter: '' }
    },
    'classic_3d': {
        white: {
            fill: 'url(#whiteGloss)', stroke: '#4a4a4a', stroke_width: '0.5',
            defs: `
                <linearGradient id="whiteGloss" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#ffffff"/>
                    <stop offset="50%" stop-color="#dddddd"/>
                    <stop offset="100%" stop-color="#a0a0a0"/>
                </linearGradient>
                <filter id="shadowWhite" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="1.5" dy="2.5" stdDeviation="1.5" flood-color="#000" flood-opacity="0.35"/>
                </filter>
            `,
            filter: 'url(#shadowWhite)'
        },
        black: {
            fill: 'url(#blackGloss)', stroke: '#111111', stroke_width: '0.5',
            defs: `
                <linearGradient id="blackGloss" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#555555"/>
                    <stop offset="30%" stop-color="#333333"/>
                    <stop offset="100%" stop-color="#000000"/>
                </linearGradient>
                <filter id="shadowBlack" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="1.5" dy="2.5" stdDeviation="1.5" flood-color="#000" flood-opacity="0.5"/>
                </filter>
            `,
            filter: 'url(#shadowBlack)'
        }
    },
    'metal': {
        white: {
            fill: 'url(#gold)', stroke: '#b8860b', stroke_width: '0.5',
            defs: `
                <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#fff4b0"/>
                    <stop offset="40%" stop-color="#d4af37"/>
                    <stop offset="80%" stop-color="#a67c00"/>
                    <stop offset="100%" stop-color="#5d4300"/>
                </linearGradient>
                <filter id="metalShadow">
                    <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.6"/>
                </filter>
            `,
            filter: 'url(#metalShadow)'
        },
        black: {
            fill: 'url(#silver)', stroke: '#444444', stroke_width: '0.5',
            defs: `
                <linearGradient id="silver" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#ffffff"/>
                    <stop offset="40%" stop-color="#b0b0b0"/>
                    <stop offset="80%" stop-color="#696969"/>
                    <stop offset="100%" stop-color="#222222"/>
                </linearGradient>
                <filter id="metalShadowBlack">
                    <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.6"/>
                </filter>
            `,
            filter: 'url(#metalShadowBlack)'
        }
    },
    'neon': {
        white: {
            fill: 'none', stroke: '#00ffff', stroke_width: '1.5',
            defs: `
                <filter id="cyanGlow" x="-50%" y="-50%" width="200%" height="200%">
                    <feGaussianBlur stdDeviation="2.5" result="coloredBlur"/>
                    <feMerge>
                        <feMergeNode in="coloredBlur"/>
                        <feMergeNode in="SourceGraphic"/>
                    </feMerge>
                </filter>
            `,
            filter: 'url(#cyanGlow)'
        },
        black: {
            fill: 'none', stroke: '#ff00ff', stroke_width: '1.5',
            defs: `
                <filter id="magentaGlow" x="-50%" y="-50%" width="200%" height="200%">
                    <feGaussianBlur stdDeviation="2.5" result="coloredBlur"/>
                    <feMerge>
                        <feMergeNode in="coloredBlur"/>
                        <feMergeNode in="SourceGraphic"/>
                    </feMerge>
                </filter>
            `,
            filter: 'url(#magentaGlow)'
        }
    },
    'fantasy': {
        white: {
            fill: 'url(#bluemagic)', stroke: '#ffffff', stroke_width: '0.3',
            defs: `
                <radialGradient id="bluemagic" cx="50%" cy="30%" r="50%">
                    <stop offset="0%" stop-color="#0ff"/>
                    <stop offset="80%" stop-color="#0044ff"/>
                    <stop offset="100%" stop-color="#000088"/>
                </radialGradient>
                <filter id="glowW" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="0" stdDeviation="3" flood-color="#0ff" flood-opacity="0.6"/>
                </filter>
            `,
            filter: 'url(#glowW)'
        },
        black: {
            fill: 'url(#darkmagic)', stroke: '#ffffff', stroke_width: '0.2',
            defs: `
                <radialGradient id="darkmagic" cx="50%" cy="30%" r="50%">
                    <stop offset="0%" stop-color="#5500ff"/>
                    <stop offset="80%" stop-color="#220055"/>
                    <stop offset="100%" stop-color="#000000"/>
                </radialGradient>
                <filter id="glowB" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="0" stdDeviation="3" flood-color="#50f" flood-opacity="0.6"/>
                </filter>
            `,
            filter: 'url(#glowB)'
        }
    }
};

const baseDir = path.join('d:\\', 'PP942920DRIVE', 'PROJECTS', 'chess', 'app', 'assets', 'pieces');

// Ensure base dir exists
if (!fs.existsSync(baseDir)) {
    fs.mkdirSync(baseDir, { recursive: true });
}

// Clean existing .keep files
const rmKeepFiles = (dir) => {
    fs.readdirSync(dir, { withFileTypes: true }).forEach(dirent => {
        const fullPath = path.join(dir, dirent.name);
        if (dirent.isDirectory()) rmKeepFiles(fullPath);
        else if (dirent.name === '.keep') fs.unlinkSync(fullPath);
    });
};
rmKeepFiles(baseDir);

// Generate SVGs
Object.entries(THEMES).forEach(([theme, colors]) => {
    const themeDir = path.join(baseDir, theme);
    if (!fs.existsSync(themeDir)) fs.mkdirSync(themeDir, { recursive: true });
    
    Object.entries(colors).forEach(([color, config]) => {
        Object.entries(paths).forEach(([piece, pathD]) => {
            // Give gradients unique IDs per theme and color to avoid flutter_svg bleeding
            let defs = config.defs;
            let fill = config.fill;
            let filter = config.filter;
            
            const uniqueId = `${theme}_${color}`;
            defs = defs.replace(/id="(.*?)"/g, `id="$1_${uniqueId}"`);
            fill = fill.replace(/url\(\#(.*?)\)/g, `url(#$1_${uniqueId})`);
            filter = filter.replace(/url\(\#(.*?)\)/g, `url(#$1_${uniqueId})`);

            const svg = TEMPLATE(defs, pathD, fill, config.stroke, config.stroke_width, filter);
            const filename = `${color}_${piece}.svg`;
            fs.writeFileSync(path.join(themeDir, filename), svg);
        });
    });
});

console.log('Successfully generated full SVG piece sets for all requested themes!');
