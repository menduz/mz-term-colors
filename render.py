#!/usr/bin/env python3
"""Render the current Nix themes as a deterministic fetch-style SVG."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent


def render(presets):
    width, height = 1120, 104 + len(presets) * 400
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        '<title id="title">mz-term-colors — orange, teal, and navy seeds</title>',
        '<desc id="desc">Dark and light themes with a simulated fetch display, '
        '16 ANSI colors, selected text, and a block cursor.</desc>',
        '<rect width="100%" height="100%" fill="#181a1b"/>',
        '<g font-family="Iosevka, DejaVu Sans Mono, Liberation Mono, monospace" font-size="14">',
    ]

    def rect(x, y, w, h, color):
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>')

    def text(x, y, value, color, size=14, bold=False):
        weight = ' font-weight="bold"' if bold else ''
        parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}"{weight} '
                     f'xml:space="preserve">{escape(value)}</text>')

    text(24, 38, 'MZ-TERM-COLORS', '#ffffff', 24, True)
    text(24, 66, 'terminal colors generated using a single seed color', '#ffffff')
    for row, preset in enumerate(presets):
        for col, variant in enumerate(('dark', 'light')):
            theme = preset['themes'][variant]
            palette, fg = theme['palette'], theme['foreground']
            x, y = 24 + col * 548, 88 + row * 400
            rect(x, y, 524, 376, theme['background'])
            text(x + 24, y + 24, f"{preset['name']} / {variant} / {preset['color']}", fg, bold=True)
            text(x + 21, y + 64, '$ theme-fetch', fg)
            # Four ASCII panes echo a classic desktop logo; colors come from ANSI slots.
            for line in range(6):
                for pane, slot in enumerate((1, 2) if line < 3 else (4, 3)):
                    text(x + 24 + pane * 62, y + 104 + line * 20, '#####', palette[slot], bold=True)
            facts = [
                ('user', 'guest@ghostty'),
                ('theme', preset['name']),
                ('mode', variant),
                ('seed', preset['color']),
                ('bg', theme['background']),
                ('fg', fg),
            ]
            for i, (key, value) in enumerate(facts):
                text(x + 168, y + 104 + i * 20, f'{key:5}', palette[6], bold=True)
                text(x + 224, y + 104 + i * 20, value, fg)
            for i, color in enumerate(palette):
                sx, sy = x + 24 + (i % 8) * 59, y + 230 + (i // 8) * 31
                rect(sx, sy, 53, 25, color)
            text(x + 24, y + 314, 'ANSI 0–7 / 8–15', fg, 12)
            rect(x + 24, y + 330, 151, 23, theme['selection-background'])
            text(x + 28, y + 347, 'selected text', theme['selection-foreground'])
            text(x + 200, y + 347, '$ ', fg)
            rect(x + 219, y + 330, 10, 23, theme['cursor-color'])
            text(x + 220, y + 347, '_', theme['cursor-text'])
    parts.extend(['</g>', '</svg>', ''])
    return '\n'.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-o', '--output', type=Path, default=ROOT / 'preview.svg',
                        help='SVG path (default: preview.svg beside this script)')
    args = parser.parse_args()
    try:
        result = subprocess.run(
            ['nix', '--extra-experimental-features', 'nix-command flakes', 'eval',
             '--json', '--no-write-lock-file', f'path:{ROOT}#previewData'],
            check=True, capture_output=True, text=True,
        )
        args.output.write_text(render(json.loads(result.stdout)), encoding='utf-8')
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr, end='')
        return error.returncode
    except (OSError, ValueError) as error:
        print(f'render: {error}', file=sys.stderr)
        return 1
    print(f'Wrote {args.output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
