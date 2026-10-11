// The SVG preview of themes: a fetch display, the 16 ANSI colors with their
// faint text colors, selected text, and a block cursor. render.js writes preview.svg with it, and the web
// generator draws its columns with it.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('./theme.js'));
  else root.MzTermPreview = factory(root.MzTermColors);
})(typeof self !== 'undefined' ? self : this, function (gc) {
  'use strict';

  // The size of one theme panel.
  const panelWidth = 524;
  const panelHeight = 386;
  // The distance between two rows of the preview of the README.
  const rowStep = panelHeight + 24;

  const escape = (s) =>
    String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  const rect = (x, y, w, h, fill) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"/>`;

  const text = (x, y, value, fill, size = 14, bold = false) =>
    `<text x="${x}" y="${y}" fill="${fill}" font-size="${size}"${bold ? ' font-weight="bold"' : ''} ` +
    `xml:space="preserve">${escape(value)}</text>`;

  const pad = (s, n) => String(s).padEnd(n);

  // One theme at x, y: a list of SVG elements. `name` and `seed` are the
  // labels of the theme.
  const panel = (theme, { x, y, name, seed }) => {
    const { palette, foreground: fg, variant } = theme;
    const parts = [rect(x, y, panelWidth, panelHeight, theme.background)];
    parts.push(text(x + 24, y + 24, `${name} / ${variant} / ${seed}`, fg, 14, true));
    parts.push(text(x + 21, y + 64, '$ theme-fetch', fg));
    // Four ASCII panes echo a classic desktop logo; colors come from ANSI slots.
    for (let line = 0; line < 6; line++) {
      (line < 3 ? [1, 2] : [4, 3]).forEach((slot, pane) => {
        parts.push(text(x + 24 + pane * 62, y + 104 + line * 20, '#####', palette[slot], 14, true));
      });
    }
    const facts = [
      ['user', 'guest@ghostty'],
      ['theme', name],
      ['mode', variant],
      ['seed', seed],
      ['bg', theme.background],
      ['fg', fg],
    ];
    facts.forEach(([key, value], i) => {
      parts.push(text(x + 168, y + 104 + i * 20, pad(key, 5), palette[6], 14, true));
      parts.push(text(x + 224, y + 104 + i * 20, value, fg));
    });
    // Each ANSI color, and below it a strip of the color of faint text in
    // that color.
    palette.forEach((c, i) => {
      const sx = x + 24 + (i % 8) * 59;
      const sy = y + 230 + Math.floor(i / 8) * 41;
      parts.push(rect(sx, sy, 53, 25, c));
      parts.push(rect(sx, sy + 27, 53, 6, gc.faintText(theme, c)));
    });
    parts.push(text(x + 24, y + 324, 'ANSI 0–7 / 8–15, faint below', fg, 12));
    parts.push(text(x + 260, y + 324, `faint text (${theme['faint-opacity']})`, gc.faintText(theme, fg), 12));
    parts.push(rect(x + 24, y + 340, 151, 23, theme['selection-background']));
    parts.push(text(x + 28, y + 357, 'selected text', theme['selection-foreground']));
    parts.push(text(x + 200, y + 357, '$ ', fg));
    parts.push(rect(x + 219, y + 340, 10, 23, theme['cursor-color']));
    parts.push(text(x + 220, y + 357, '_', theme['cursor-text']));
    return parts;
  };

  // An SVG document. `before` goes before the group with the font.
  const svg = (width, height, title, desc, body, before = []) =>
    [
      `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" ` +
        `viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title desc">`,
      `<title id="title">${escape(title)}</title>`,
      `<desc id="desc">${escape(desc)}</desc>`,
      ...before,
      '<g font-family="Iosevka, DejaVu Sans Mono, Liberation Mono, monospace" font-size="14">',
      ...body,
      '</g>',
      '</svg>',
      '',
    ].join('\n');

  const desc =
    'Dark and light themes with a simulated fetch display, 16 ANSI colors with their faint text colors, ' +
    'selected text, and a block cursor.';

  // The preview of the README: a row for each preset { name, color, themes },
  // with the dark theme at the left and the light theme at the right.
  const presetsSvg = (presets) => {
    const width = 1120;
    const height = 104 + presets.length * rowStep;
    const body = [
      text(24, 38, 'MZ-TERM-COLORS', '#ffffff', 24, true),
      text(24, 66, 'terminal colors generated using a single seed color', '#ffffff'),
    ];
    presets.forEach((preset, row) => {
      ['dark', 'light'].forEach((variant, col) => {
        body.push(
          ...panel(preset.themes[variant], {
            x: 24 + col * 548,
            y: 88 + row * rowStep,
            name: preset.name,
            seed: preset.color,
          }),
        );
      });
    });
    return svg(width, height, 'mz-term-colors — orange, teal, and navy seeds', desc, body, [
      '<rect width="100%" height="100%" fill="#181a1b"/>',
    ]);
  };

  // The place of a theme that is not given: a panel of the same size.
  const emptyPanel = (variant, { x, y }) => [
    rect(x, y, panelWidth, panelHeight, '#2a2c2d'),
    text(x + 24, y + 24, `no ${variant} theme`, '#9aa0a3', 14, true),
  ];

  // A column of one color: the dark theme above the light theme, without a
  // margin. Two columns have the same size, so one can go on the other. A
  // theme that is null gives an empty panel.
  const columnWidth = panelWidth;
  const columnGap = 8;
  const columnHeight = 2 * panelHeight + columnGap;
  const columnSvg = (themes, { name, seed }) => {
    const place = (variant, y) =>
      themes[variant] ? panel(themes[variant], { x: 0, y, name, seed }) : emptyPanel(variant, { x: 0, y });
    return svg(columnWidth, columnHeight, `mz-term-colors — ${name}`, desc, [
      ...place('dark', 0),
      ...place('light', panelHeight + columnGap),
    ]);
  };

  return { panelWidth, panelHeight, columnWidth, columnHeight, panel, presetsSvg, columnSvg };
});
