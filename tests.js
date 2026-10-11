#!/usr/bin/env node
// Checks of the theme generator (lib/theme.js). `nix flake check` runs this
// file, and tests.nix checks the Nix library and the Home Manager module.
'use strict';
const gc = require('./lib/theme.js');

const c = gc.color;
let failures = 0;
const check = (what, ok) => {
  if (!ok) {
    failures++;
    console.error(`mz-term-colors check failed: ${what}`);
  }
};

const samples = [
  '#008080', '#800080', '#800000', '#599764', '#f29718', '#ffff00',
  '#00ff00', '#0000ff', '#ff0000', '#000000', '#ffffff', '#808080',
  // The base backgrounds of the dark and the light variant.
  '#0f1419', '#fafaf5',
];

// The required ratios, fixed here: a change of the defaults of the library
// must not make the checks weaker.
const ratios = {
  text: 7, cursor: 3, selection: 4.5, selectionBackground: 1.5, palette: 4.5, bright: 3, brightBlack: 1.4, minimum: 1, faint: 3,
};

// The color that Ghostty draws for a glyph of color fg with an opacity (1,
// or `faint-opacity` for faint text) on a cell of color bg. Ghostty
// multiplies the linear color by the opacity before it compares the contrast
// with `minimum-contrast` (when it is more than 1). If the contrast is less,
// the glyph is opaque black or white. Refer to cell_text.v.glsl and
// contrasted_color in common.glsl (src/renderer/shaders/glsl) of Ghostty.
const drawn = (minimum, bg, fg, opacity = 1) => {
  const lf = c.luminance(fg) * opacity;
  const lb = c.luminance(bg);
  const ratio = (Math.max(lf, lb) + 0.05) / (Math.min(lf, lb) + 0.05);
  if (minimum > 1 && ratio < minimum) {
    return c.contrast(bg, '#ffffff') > c.contrast(bg, '#000000') ? '#ffffff' : '#000000';
  }
  return opacity === 1 ? fg : c.mix(bg, fg, opacity);
};

const range = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => from + i);

// The checks of one theme. `args` are the arguments of mkTheme.
const checkTheme = (args) => {
  const t = gc.mkTheme(args);
  const variant = args.variant || 'dark';
  const bg = t.background;
  const at = (what) => `${JSON.stringify(args)}: ${what}`;
  const slot = (i) => t.palette[i];
  const slots = variant === 'dark' ? [0] : [7, 15];
  // The bright colors red to cyan of the light variant.
  const lightBright = (i) => variant === 'light' && i >= 9 && i <= 14;
  const lines = gc.toGhostty(t).split('\n');
  const has = (line) => lines.includes(line);

  check(at(`the background is ${variant}`), (variant === 'dark') === c.isDark(bg));
  check(at('text contrast'), c.contrast(bg, t.foreground) >= ratios.text);
  check(at('cursor contrast'), c.contrast(bg, t['cursor-color']) >= ratios.cursor);
  check(at('cursor text contrast'), c.contrast(t['cursor-color'], t['cursor-text']) >= ratios.selection);
  check(at('selection contrast'), c.contrast(bg, t['selection-background']) >= ratios.selectionBackground);
  check(at('selection text contrast'), c.contrast(t['selection-background'], t['selection-foreground']) >= ratios.selection);
  check(at('16 colors'), t.palette.length === 16);
  // Programs write text in the ANSI colors: each color that is not of the
  // role of the background has the contrast of text (AA). The bright colors
  // red to cyan of the light variant have the bright ratio, and bright black
  // has the bright black ratio.
  const required = (i) => (i === 8 ? ratios.brightBlack : lightBright(i) ? ratios.bright : ratios.palette);
  t.palette.forEach((p, i) => {
    if (slots.includes(i)) return;
    const r = c.contrast(bg, p);
    check(at(`palette ${i} (${p}) contrast ${r}`), r >= required(i));
  });
  // Bright black stays dim: it keeps its source color, or it gets only a
  // little more than its ratio.
  {
    const source = c.normalize((args.palette || gc.palettes[variant])[8]);
    check(at(`palette 8 (${slot(8)}) stays dim`), slot(8) === source || c.contrast(bg, slot(8)) < ratios.brightBlack + 0.1);
  }
  // The colors of the role of the background keep the source colors.
  for (const i of slots) {
    check(at(`palette ${i} keeps its color`), slot(i) === c.normalize((args.palette || gc.palettes[variant])[i]));
  }
  const min = t['minimum-contrast'];
  const opacity = t['faint-opacity'];
  // `minimum-contrast` is off: with 3, Ghostty drew faint black (dark) in
  // opaque white, and faint white (light) in opaque black.
  check(at('minimum-contrast is off'), min === ratios.minimum);
  // Faint text has the faint ratio, with the `faint-opacity` of the theme.
  check(at(`faint-opacity ${opacity}`), opacity >= 0.5 && opacity <= 1);
  check(at('faint text contrast'), c.contrast(bg, drawn(min, bg, t.foreground, opacity)) >= ratios.faint);
  // Faint text stays faint: Ghostty does not replace it with opaque black or
  // white, in the foreground and in each of the 16 colors.
  t.palette.forEach((p, i) => {
    check(at(`faint palette ${i} (${p}) stays faint`), drawn(min, bg, p, opacity) === c.mix(bg, p, opacity));
  });
  check(at('faint foreground stays faint'), drawn(min, bg, t.foreground, opacity) === c.mix(bg, t.foreground, opacity));
  // The faint colors of the preview are the colors that Ghostty draws.
  for (const fg of [...t.palette, t.foreground]) {
    check(at(`faint ${fg}`), gc.faintText(t, fg) === drawn(min, bg, fg, opacity));
  }
  // A bright color (9..14) is lighter than its normal color (1..6), in both
  // variants.
  for (const i of range(1, 6)) {
    check(at(`palette ${i}: bright is lighter`), c.luminance(slot(i + 8)) > c.luminance(slot(i)));
  }
  // In the light variant, a bright color is clearly different from its
  // normal color: the normal color has 1.3 times the contrast or more.
  if (variant === 'light') {
    for (const i of range(1, 6)) {
      check(at(`palette ${i}: bright is different`), c.contrast(bg, slot(i)) >= 1.3 * c.contrast(bg, slot(i + 8)));
    }
  }
  // The Ghostty file holds each value.
  check(at('file: minimum-contrast'), has(`minimum-contrast = ${t['minimum-contrast']}`));
  check(at('file: faint-opacity'), lines.some((l) => /^faint-opacity = [0-9.]+$/.test(l) && Number(l.split(' = ')[1]) === t['faint-opacity']));
  t.palette.forEach((p, i) => check(at(`file: palette ${i}`), has(`palette = ${i}=${p}`)));
};

// Each sample in both variants, and more difficult cases: a strong tint, no
// tint, and the palette of the other variant (light colors on a light
// background, dark colors on a dark background).
const cases = samples.flatMap((color) => [
  { color, variant: 'dark' },
  { color, variant: 'light' },
  { color, variant: 'dark', tint: 0.3 },
  { color, variant: 'light', tint: 0.25 },
  { color, variant: 'dark', tint: 0 },
  { color, variant: 'light', tint: 0 },
  { color, variant: 'light', palette: gc.palettes.dark },
  { color, variant: 'dark', palette: gc.palettes.light },
]);
cases.forEach(checkTheme);

// Known values: the WCAG contrast of black and white is 21, and the dark
// theme of #008080 is the theme of the sandboxes of nix-config.
check('contrast of black and white', Math.abs(c.contrast('#000000', '#ffffff') - 21) < 1e-3);
check('normalize', c.normalize('008080') === '#008080' && c.normalize('#00AAff') === '#00aaff');
{
  const t = gc.mkTheme({ color: '#008080' });
  check('dark #008080', t.background === '#0d2125' && t.foreground === '#cad6d6' && t['cursor-color'] === '#008080');
}
// The light theme of #f29718, the host theme of nix-config: the tint 0.3
// gives a peach background. The normal colors reach 4.5; blue and magenta
// keep their source colors. The bright colors reach 3. White (7) and
// bright white (15) keep the colors of the background role, and faint text in
// white is the mix of white and the background.
{
  const t = gc.mkTheme({ color: '#f29718', variant: 'light' });
  const expected = [
    '#1a1a1a', '#c21010', '#3b6e08', '#745d00', '#1565a8', '#a8404a', '#176e51', '#d0cdc8',
    '#4a4a4a', '#e44141', '#668446', '#90771c', '#2e80be', '#ba6071', '#308d76', '#fafaf5',
  ];
  check(
    'light #f29718',
    t.background === '#f8dcb3' &&
      t.foreground === '#30271a' &&
      JSON.stringify(t.palette) === JSON.stringify(expected) &&
      t['minimum-contrast'] === 1 &&
      t['faint-opacity'] === 0.55 &&
      drawn(t['minimum-contrast'], t.background, '#d0cdc8') === '#d0cdc8' &&
      gc.faintText(t, '#d0cdc8') === c.mix(t.background, '#d0cdc8', 0.55),
  );
}
// The dark theme of #f29718: bright black (8) has the contrast of the theme
// of nix-config before mz-term-colors (#323232 on #0f1419, 1.44), not 4.5.
// Black stays black, and faint black is the mix of black and the background,
// as in that theme. On that background, bright black keeps #323232.
check('bright black on #0f1419', gc.mkTheme({ color: '#0f1419' }).palette[8] === '#323232');
{
  const t = gc.mkTheme({ color: '#f29718' });
  check(
    'dark #f29718',
    t.palette[8] === '#3e3e3e' &&
      t['faint-opacity'] === 0.5 &&
      t['minimum-contrast'] === 1 &&
      drawn(t['minimum-contrast'], t.background, '#000000') === '#000000' &&
      gc.faintText(t, '#000000') === c.mix(t.background, '#000000', 0.5),
  );
}
// A seed equal to the background: the selection was the background, now it is
// lighter. The selection of #f29718 keeps the seed.
{
  const t = gc.mkTheme({ color: '#0f1419' });
  check('dark #0f1419 selection', t.background === '#0f1419' && t['selection-background'] === '#33373c');
  const orange = gc.mkThemes({ color: '#f29718' });
  check('#f29718 selection', orange.dark['selection-background'] === '#f29718' && orange.light['selection-background'] === '#f29718');
}
// A strong tint of white makes a gray background. The tint is less, thus the
// text keeps its contrast.
{
  const t = gc.mkTheme({ color: '#ffffff', tint: 0.3 });
  check(
    'a strong tint is less',
    c.isDark(t.background) &&
      t.background !== c.mix(gc.variants.dark.background, '#ffffff', 0.3) &&
      c.contrast(t.background, t.foreground) >= ratios.text,
  );
}
// fromGhostty reads what toGhostty writes, for each theme.
for (const args of cases) {
  const t = gc.mkTheme(args);
  check(`${JSON.stringify(args)}: fromGhostty`, JSON.stringify(gc.fromGhostty(gc.toGhostty(t))) === JSON.stringify({ ...t, color: null }));
}
// A file with colors without "#", comments, a named color, and no cursor, no
// selection and no palette entries 2..15: these take the values of Ghostty.
{
  const t = gc.fromGhostty('# comment\nbackground = 0f1419\nforeground = "e0e0e0"\npalette = 0=000000\npalette = 1 = tomato\nfont-size = 9\n', {
    resolveName: (n) => (n === 'tomato' ? '#ff6347' : null),
  });
  check(
    'fromGhostty defaults',
    t.variant === 'dark' &&
      t.background === '#0f1419' &&
      t.palette[0] === '#000000' &&
      t.palette[1] === '#ff6347' &&
      t.palette[2] === gc.ghosttyDefaults.palette[2] &&
      t['cursor-color'] === '#e0e0e0' &&
      t['selection-background'] === '#e0e0e0' &&
      t['selection-foreground'] === '#0f1419' &&
      t['minimum-contrast'] === 1 &&
      t['faint-opacity'] === 0.5,
  );
  const cell = gc.fromGhostty('background = #ffffff\nforeground = #000000\ncursor-color = cell-background\n');
  check('fromGhostty cell-background', cell.variant === 'light' && cell['cursor-color'] === '#ffffff');
}
check('fromGhostty names the line', (() => {
  try {
    gc.fromGhostty('background = #000000\npalette = 1=tomato\n');
    return false;
  } catch (e) {
    return e.message === 'line 2: "tomato" is not a color';
  }
})());
// A whole faint-opacity keeps ".0" in the file, as the Nix generator wrote it.
check('faint-opacity 1.0', gc.toGhostty(gc.mkTheme({ color: '#808080', contrast: { faint: 21 } })).includes('faint-opacity = 1.0\n'));
check('a bad color throws', (() => {
  try {
    gc.mkTheme({ color: 'teal' });
    return false;
  } catch (e) {
    return true;
  }
})());

if (failures > 0) {
  console.error(`${failures} checks failed`);
  process.exit(1);
}
console.log(`${cases.length} themes checked`);
