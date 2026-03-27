import os
import json

paths = {
    'king': "M 22.5,11.63 L 22.5,6 L 20,6 L 20,3.5 L 25,3.5 L 25,6 L 22.5,6 L 22.5,11.63 M 20,8 L 25,8 M 22.5,11.63 A 8,8 0 0,0 12,20 L 33,20 A 8,8 0 0,0 22.5,11.63 M 12,20 A 8,8 0 0,0 12,28 M 33,20 A 8,8 0 0,1 33,28 M 12,28 L 33,28 M 12,32 L 33,32 M 11.5,35 L 33.5,35 M 11.5,35 L 11.5,39.5 L 33.5,39.5 L 33.5,35 M 15,32 L 15,35 M 30,32 L 30,35",
    'queen': "M 9 26 C 17.5 24.5 30 24.5 36 26 L 38 14 L 31 17 L 30 9 L 25.5 14 L 22.5 9 L 19.5 14 L 15 9 L 14 17 L 7 14 L 9 26 z M 11 26 A 15 15 0 0 0 34 26 M 11 28 A 15 15 0 0 0 34 28 M 11 30 A 15 15 0 0 0 34 30 M 11.5 32 L 33.5 32 L 33.5 36 L 11.5 36 M 15 30 L 15 32 M 30 30 L 30 32 M 8.5 12.5 A 1.5 1.5 0 1 1 5.5 12.5 A 1.5 1.5 0 1 1 8.5 12.5 z M 16.5 7.5 A 1.5 1.5 0 1 1 13.5 7.5 A 1.5 1.5 0 1 1 16.5 7.5 z M 24 7.5 A 1.5 1.5 0 1 1 21 7.5 A 1.5 1.5 0 1 1 24 7.5 z M 31.5 7.5 A 1.5 1.5 0 1 1 28.5 7.5 A 1.5 1.5 0 1 1 31.5 7.5 z M 39.5 12.5 A 1.5 1.5 0 1 1 36.5 12.5 A 1.5 1.5 0 1 1 39.5 12.5 z",
    'rook': "M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z M 11 14 L 11 9 L 15 9 L 15 11 L 20 11 L 20 9 L 25 9 L 25 11 L 30 11 L 30 9 L 34 9 L 34 14 L 11 14 z M 31 14 C 31 14 34 23 34 32 L 11 32 C 11 23 14 14 14 14 M 14 14 L 31 14",
    'bishop': "M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z M 11 32 L 34 32 C 34 32 32 23 23 23 C 14 23 11 32 11 32 z M 22.5 24 L 22.5 14 M 22.5 11 A 3.5 3.5 0 1 1 22.5 4 A 3.5 3.5 0 1 1 22.5 11 z",
    'knight': "M 22 10 C 32 10 32.5 22.5 31 26 C 29 20 23 20 20 20 C 23 27 21 32 15 32 C 13.5 32 11 28 11 28 C 11 28 14 26 14 24 C 14 22 11 20 9 20 C 6.5 20 5 22 5 22 C 5 22 8 13 13 11 C 15 10 18 10 22 10 M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z",
    'pawn': "M 22 9 C 19.8 9 18 10.8 18 13 C 18 15.2 19.8 17 22 17 C 24.2 17 26 15.2 26 13 C 26 10.8 24.2 9 22 9 z M 22 18 C 18 18 16 22 16 25 C 16 30 20 32 20 32 L 25 32 C 25 32 28 30 28 25 C 28 22 26 18 22 18 z M 9 39 L 36 39 L 36 36 L 9 36 L 9 39 z M 12 36 L 12 32 L 33 32 L 33 36 L 12 36 z"
}

# Add internal cutout paths so pieces like Rook, Bishop have their holes
cutouts = {
    'rook': "M 15 32 L 30 32 L 30 14 L 15 14 z",
    'bishop': "M 20 18 A 2 2 0 1 1 25 18 A 2 2 0 1 1 20 18 z M 12 32 L 33 32 C 33 32 31 23 22 23 C 13 23 12 32 12 32 z", # The slot is complicated, simplified here
}

# The true beautiful SVG paths for chess pieces are highly detailed. Using standard ones:
# I will use high quality simplified paths that look great with 3D filters.
# Let's write the generation python script!

TEMPLATE = '''<svg width="128" height="128" viewBox="0 0 45 45" xmlns="http://www.w3.org/2000/svg">
  <defs>
    {defs}
  </defs>
  <path d="{path}" fill="{fill}" stroke="{stroke}" stroke-width="{stroke_width}" filter="{filter}" />
</svg>'''

THEMES = {
    'modern_flat': {
        'white': {'fill': '#f0f0f0', 'stroke': '#cccccc', 'stroke_width': '0', 'defs': '', 'filter': ''},
        'black': {'fill': '#333333', 'stroke': '#1a1a1a', 'stroke_width': '0', 'defs': '', 'filter': ''}
    },
    'classic_3d': {
        'white': {
            'fill': 'url(#whiteGloss)', 
            'stroke': '#4a4a4a', 
            'stroke_width': '0.5',
            'defs': """
                <linearGradient id="whiteGloss" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#ffffff"/>
                    <stop offset="50%" stop-color="#dddddd"/>
                    <stop offset="100%" stop-color="#a0a0a0"/>
                </linearGradient>
                <filter id="shadowWhite" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="1" dy="2" stdDeviation="1.5" flood-color="#000" flood-opacity="0.3"/>
                </filter>
            """,
            'filter': 'url(#shadowWhite)'
        },
        'black': {
            'fill': 'url(#blackGloss)', 
            'stroke': '#111111', 
            'stroke_width': '0.5',
            'defs': """
                <linearGradient id="blackGloss" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stop-color="#555555"/>
                    <stop offset="30%" stop-color="#333333"/>
                    <stop offset="100%" stop-color="#000000"/>
                </linearGradient>
                <filter id="shadowBlack">
                    <feDropShadow dx="1" dy="2" stdDeviation="1.5" flood-color="#000" flood-opacity="0.5"/>
                </filter>
            """,
            'filter': 'url(#shadowBlack)'
        }
    },
    'metal': {
        'white': {
            'fill': 'url(#gold)', 
            'stroke': '#b8860b', 
            'stroke_width': '0.5',
            'defs': """
                <linearGradient id="gold" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stop-color="#fced8e"/>
                    <stop offset="50%" stop-color="#d4af37"/>
                    <stop offset="100%" stop-color="#8a611c"/>
                </linearGradient>
                <filter id="metalShadow">
                    <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.4"/>
                    <feSpecularLighting surfaceScale="2" specularConstant="1" specularExponent="20" lighting-color="#fff">
                        <fePointLight x="-50" y="-50" z="200" />
                    </feSpecularLighting>
                </filter>
            """,
            'filter': 'url(#metalShadow)'
        },
        'black': {
            'fill': 'url(#silver)', 
            'stroke': '#444444', 
            'stroke_width': '0.5',
            'defs': """
                <linearGradient id="silver" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stop-color="#ffffff"/>
                    <stop offset="50%" stop-color="#888888"/>
                    <stop offset="100%" stop-color="#333333"/>
                </linearGradient>
            """,
            'filter': 'url(#metalShadow)'
        }
    },
    'neon': {
        'white': {
            'fill': 'none', 
            'stroke': '#0ff', 
            'stroke_width': '2',
            'defs': """
                <filter id="cyanGlow" x="-50%" y="-50%" width="200%" height="200%">
                    <feGaussianBlur stdDeviation="1.5" result="coloredBlur"/>
                    <feMerge>
                        <feMergeNode in="coloredBlur"/>
                        <feMergeNode in="SourceGraphic"/>
                    </feMerge>
                </filter>
            """,
            'filter': 'url(#cyanGlow)'
        },
        'black': {
            'fill': 'none', 
            'stroke': '#f0f', 
            'stroke_width': '2',
            'defs': """
                <filter id="magentaGlow" x="-50%" y="-50%" width="200%" height="200%">
                    <feGaussianBlur stdDeviation="1.5" result="coloredBlur"/>
                    <feMerge>
                        <feMergeNode in="coloredBlur"/>
                        <feMergeNode in="SourceGraphic"/>
                    </feMerge>
                </filter>
            """,
            'filter': 'url(#magentaGlow)'
        }
    },
    'fantasy': {
        'white': {
            'fill': 'url(#bluemagic)', 
            'stroke': '#fff', 
            'stroke_width': '0.5',
            'defs': """
                <radialGradient id="bluemagic" cx="50%" cy="30%" r="50%">
                    <stop offset="0%" stop-color="#00f2fe"/>
                    <stop offset="100%" stop-color="#4facfe"/>
                </radialGradient>
            """,
            'filter': 'url(#shadowWhite)'
        },
        'black': {
            'fill': 'url(#darkmagic)', 
            'stroke': '#fff', 
            'stroke_width': '0.2',
            'defs': """
                <radialGradient id="darkmagic" cx="50%" cy="30%" r="50%">
                    <stop offset="0%" stop-color="#434343"/>
                    <stop offset="100%" stop-color="#000000"/>
                </radialGradient>
            """,
            'filter': 'url(#shadowBlack)'
        }
    }
}

import shutil

base_dir = r"d:\\PP942920DRIVE\\PROJECTS\\chess\\app\\assets\\pieces"

# First, clean .keep files
for root, dirs, files in os.walk(base_dir):
    for f in files:
        if f == '.keep':
            os.remove(os.path.join(root, f))

# Let's generate SVG files
for theme, colors in THEMES.items():
    theme_dir = os.path.join(base_dir, theme)
    os.makedirs(theme_dir, exist_ok=True)
    
    for color, config in colors.items():
        for piece, path in paths.items():
            svg_content = TEMPLATE.format(
                defs=config['defs'],
                path=path,
                fill=config['fill'],
                stroke=config['stroke'],
                stroke_width=config['stroke_width'],
                filter=config['filter']
            )
            filename = f"{color}_{piece}.svg"
            filepath = os.path.join(theme_dir, filename)
            with open(filepath, 'w') as f:
                f.write(svg_content)

print(f"Generated complete piece sets for {len(THEMES)} themes!")
