// mz-term-colors: terminal themes from one color. Plain JavaScript, no
// packages. Node, the Nix builds (lib/default.nix) and the web generator
// (web/index.html) use this file.
//
//   const gc = require('./lib/theme.js');   // in a browser: MzTermColors
//   gc.toGhostty(gc.mkTheme({ color: '#008080', variant: 'light' }))
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.MzTermColors = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // Colors "#rrggbb" in sRGB. The luminance and the contrast ratio are the
  // values of WCAG 2.1.
  const color = (() => {
    // Make a color "#rrggbb" from "rrggbb", "#rrggbb" or "#RRGGBB". Another
    // value throws an error.
    const normalize = (c) => {
      const hex = String(c).replace(/^#/, '').toLowerCase();
      if (!/^[0-9a-f]{6}$/.test(hex)) {
        throw new Error(`mz-term-colors: "${c}" is not a color. Give "#rrggbb".`);
      }
      return '#' + hex;
    };

    // The three channels of a color, 0 to 255.
    const channels = (c) => {
      const hex = normalize(c).slice(1);
      return [0, 1, 2].map((i) => parseInt(hex.slice(2 * i, 2 * i + 2), 16));
    };

    // Make a color from three channels. A channel is rounded and kept in 0..255.
    const fromChannels = (cs) =>
      '#' +
      cs
        .map((n) => Math.max(0, Math.min(255, Math.floor(n + 0.5))).toString(16).padStart(2, '0'))
        .join('');

    // Mix the color b into the color a. t = 0 gives a, t = 1 gives b.
    const mix = (a, b, t) => {
      const cb = channels(b);
      return fromChannels(channels(a).map((x, i) => x * (1 - t) + cb[i] * t));
    };

    // A channel (0 to 255) as linear light.
    const linear = (n) => {
      const c = n / 255.0;
      return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    };

    const luminance = (c) => {
      const [r, g, b] = channels(c).map(linear);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };

    // The contrast ratio of two colors, 1 to 21.
    const contrast = (a, b) => {
      const la = luminance(a);
      const lb = luminance(b);
      return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    };

    // True if white text has more contrast on the color than black text.
    const isDark = (c) => contrast(c, '#ffffff') >= contrast(c, '#000000');

    // The color c, or c moved to white or to black (the one with more contrast
    // on bg), until its contrast on bg is `ratio` or more. The steps are
    // 1/steps (default 1/20). If no step gets the ratio, the result is white
    // or black.
    const readable = (bg, c, ratio, steps = 20) => {
      const target = isDark(bg) ? '#ffffff' : '#000000';
      for (let i = 0; i <= steps; i++) {
        const step = mix(c, target, i / steps);
        if (contrast(bg, step) >= ratio) return step;
      }
      return target;
    };

    return { normalize, channels, fromChannels, mix, linear, luminance, contrast, isDark, readable };
  })();

  // The default 16 ANSI colors of each variant. The generator keeps their
  // hue, and makes each one readable on the background of the theme.
  const palettes = {
    dark: [
      '#000000', '#ff3333', '#b8cc52', '#e7c547', '#36a3d9', '#f07178', '#95e6cb', '#f0f0f0',
      '#323232', '#ff6565', '#eafe84', '#fff779', '#68d5ff', '#ffa3aa', '#c7fffd', '#ffffff',
    ],
    // Brighter accents for the light variant; normal colors keep their values.
    light: [
      '#1a1a1a', '#cc1111', '#4a8a0a', '#9b7c00', '#1565a8', '#a8404a', '#1a7a5a', '#d0cdc8',
      '#4a4a4a', '#f04444', '#92bc64', '#c09e25', '#3697df', '#db7185', '#39a68b', '#fafaf5',
    ],
  };

  // The base colors of each variant. The input color goes into the background
  // by `tint`, and into the text by 0.1.
  const variants = {
    dark: {
      background: '#0f1419',
      foreground: '#e0e0e0',
      tint: 0.12,
      palette: palettes.dark,
      // Black has the role of the background, so it keeps its color.
      backgroundSlots: [0],
    },
    light: {
      background: '#fafaf5',
      foreground: '#1a1a1a',
      tint: 0.2,
      palette: palettes.light,
      // White and bright white have the role of the background.
      backgroundSlots: [7, 15],
    },
  };

  // The minimum contrast ratios (WCAG 2.1).
  const defaultContrast = {
    // The text on the background: 7 (AAA).
    text: 7,
    // The cursor on the background: 3 (a part of the interface).
    cursor: 3,
    // The text in the cursor and in a selection: 4.5 (AA).
    selection: 4.5,
    // The selection on the background: 1.5. A selection is a large area, so
    // less contrast than the cursor is sufficient. With a seed near the
    // background, the selection was not visible.
    selectionBackground: 1.5,
    // The ANSI colors on the background: 4.5 (AA), because programs write
    // text in them.
    palette: 4.5,
    // The bright colors red to cyan (9..14) on a light background: 3. On a
    // light background, a color with 4.5 is dark. If the bright colors also
    // have 4.5, all 12 colors are almost the same dark colors, and a bright
    // color is almost equal to its normal color.
    bright: 3,
    // Bright black (8) on the background: 1.4. Programs use it for dim text,
    // for example hints and suggestions. With 4.5, it was as bright as the
    // other colors; in the theme of nix-config before mz-term-colors it had
    // 1.44 (#323232 on #0f1419), and that color stays on that background.
    brightBlack: 1.4,
    // Faint text on the background: 3. Ghostty draws faint text with
    // `faint-opacity` (default 0.5).
    faint: 3,
    // Ghostty `minimum-contrast`: 1, off. Ghostty draws a glyph with less
    // contrast in opaque white or black, also faint text: with 3, faint black
    // (dark) was white, and text and faint text in white (light) were black,
    // darker than the text. Text in a color of the role of the background
    // (black in the dark variant, white in the light variant) is almost
    // invisible, as in most themes.
    minimum: 1,
  };

  // A bright color must be visibly lighter than its normal color: its
  // contrast on the background differs by this value or more.
  const brightStep = 0.25;

  // The first value of `values` that `ok` accepts, else `fallback`.
  const findFirst = (ok, fallback, values) => {
    for (const x of values) if (ok(x)) return x;
    return fallback;
  };
  const range = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => from + i);

  // The theme of one variant ("dark" or "light") for the input color. All
  // other fields are optional:
  //
  //   background, foreground  the base colors, before the tint
  //   tint                    0..1: how much of the color goes into the background
  //   palette                 16 ANSI colors
  //   contrast                minimum ratios: { text, cursor, selection, selectionBackground, palette,
  //                           bright, brightBlack, minimum, faint }
  const mkTheme = ({
    color: input,
    variant = 'dark',
    background = null,
    foreground = null,
    tint = null,
    palette = null,
    contrast = {},
  }) => {
    const v = variants[variant];
    if (!v) {
      throw new Error(`mz-term-colors: the variant "${variant}" does not exist. Use "dark" or "light".`);
    }
    const pick = (value, fallback) => (value == null ? fallback : value);
    const c = color.normalize(input);
    const ratios = { ...defaultContrast, ...contrast };
    const basePalette = pick(palette, v.palette).map(color.normalize);
    if (basePalette.length !== 16) {
      throw new Error(`mz-term-colors: a palette has 16 colors, not ${basePalette.length}.`);
    }

    // The background with the tint. A strong tint of a light color can make
    // the background so gray that no text gets the text ratio. Then the tint
    // is less, in steps of 1/20, until white text (dark variant) or black text
    // (light variant) gets that ratio.
    const baseBackground = color.normalize(pick(background, v.background));
    const extreme = variant === 'dark' ? '#ffffff' : '#000000';
    const bg = findFirst(
      (b) => color.contrast(b, extreme) >= ratios.text,
      baseBackground,
      range(0, 20).map((i) => color.mix(baseBackground, c, pick(tint, v.tint) * (1 - i / 20.0))),
    );
    const cursor = color.readable(bg, c, ratios.cursor);
    const selection = color.readable(bg, c, ratios.selectionBackground);

    // Each color that is not of the role of the background gets the palette
    // ratio. For red to cyan (1..6), the bright color (9..14) must stay
    // lighter than the normal color. On a dark background, a lighter color
    // has more contrast: the bright color gets more contrast than the normal
    // color. On a light background, a lighter color has less contrast: the
    // bright color gets the bright ratio.
    const readableAt = (i, ratio) => color.readable(bg, basePalette[i], ratio);
    const chromatic = (i) => (i >= 1 && i <= 6) || (i >= 9 && i <= 14);
    const dark = color.isDark(bg);
    const slot = (i) => {
      if (v.backgroundSlots.includes(i)) return basePalette[i];
      // Small steps: bright black is near the background, and a step of 1/20
      // can add much contrast.
      if (i === 8) return color.readable(bg, basePalette[8], ratios.brightBlack, 100);
      if (!chromatic(i) || i <= 6) return readableAt(i, ratios.palette);
      if (dark) {
        return readableAt(i, Math.max(ratios.palette, color.contrast(bg, slot(i - 8)) + brightStep));
      }
      return readableAt(i, ratios.bright);
    };

    const fg = color.readable(bg, color.mix(pick(foreground, v.foreground), c, 0.1), ratios.text);

    // The smallest opacity from 0.5 (the default of Ghostty) in steps of 0.05
    // that gives faint text the faint ratio.
    const faintOpacity = findFirst(
      (o) => color.contrast(bg, color.mix(bg, fg, o)) >= ratios.faint,
      1.0,
      range(10, 20).map((i) => i / 20.0),
    );

    return {
      variant,
      color: c,
      background: bg,
      foreground: fg,
      'cursor-color': cursor,
      'cursor-text': color.readable(cursor, bg, ratios.selection),
      'selection-background': selection,
      'selection-foreground': color.readable(selection, '#ffffff', ratios.selection),
      palette: range(0, 15).map(slot),
      'minimum-contrast': ratios.minimum,
      'faint-opacity': faintOpacity,
    };
  };

  // The dark and the light theme of one color: { dark, light }. `dark` and
  // `light` give extra fields of mkTheme for one variant.
  const mkThemes = ({ color: c, dark = {}, light = {} }) => ({
    dark: mkTheme({ color: c, ...dark, variant: 'dark' }),
    light: mkTheme({ color: c, ...light, variant: 'light' }),
  });

  // The color that Ghostty draws for text of color fg with an opacity on the
  // background of the theme. Ghostty multiplies the linear color by the
  // opacity, and then compares the contrast of that color with
  // `minimum-contrast` (when it is more than 1). If the contrast is less, the
  // glyph is opaque white or black, the one with more contrast. Else the glyph
  // is fg with the opacity over the background: with the default
  // `alpha-blending` of Linux (linear-corrected), text looks as a mix in sRGB.
  // Refer to src/renderer/shaders/glsl/cell_text.v.glsl and common.glsl of
  // Ghostty.
  const drawnText = (theme, fg, opacity = 1) => {
    const bg = theme.background;
    const lbg = color.luminance(bg);
    const lfg = color.luminance(fg) * opacity;
    const ratio = (Math.max(lfg, lbg) + 0.05) / (Math.min(lfg, lbg) + 0.05);
    if (theme['minimum-contrast'] > 1 && ratio < theme['minimum-contrast']) {
      return color.contrast(bg, '#ffffff') > color.contrast(bg, '#000000') ? '#ffffff' : '#000000';
    }
    return opacity === 1 ? fg : color.mix(bg, fg, opacity);
  };

  // The color that Ghostty draws for faint text of color fg.
  const faintText = (theme, fg) => drawnText(theme, fg, theme['faint-opacity']);

  // `faint-opacity` is a fraction: 1 is "1.0".
  const fraction = (x) => (Number.isInteger(x) ? x.toFixed(1) : String(x));

  // A theme as a Ghostty theme file.
  const toGhostty = (theme) =>
    [
      ...['background', 'foreground', 'cursor-color', 'cursor-text', 'selection-background', 'selection-foreground'].map(
        (key) => `${key} = ${theme[key]}`,
      ),
      `minimum-contrast = ${theme['minimum-contrast']}`,
      `faint-opacity = ${fraction(theme['faint-opacity'])}`,
      ...theme.palette.map((p, i) => `palette = ${i}=${p}`),
    ].join('\n') + '\n';

  // The values of Ghostty for the keys that a theme file does not give. Refer
  // to src/config/Config.zig and src/terminal/color.zig of Ghostty 1.3.
  const ghosttyDefaults = {
    background: '#282c34',
    foreground: '#ffffff',
    palette: [
      '#1d1f21', '#cc6666', '#b5bd68', '#f0c674', '#81a2be', '#b294bb', '#8abeb7', '#c5c8c6',
      '#666666', '#d54e53', '#b9ca4a', '#e7c547', '#7aa6da', '#c397d8', '#70c0b1', '#eaeaea',
    ],
    'minimum-contrast': 1,
    'faint-opacity': 0.5,
  };

  const ghosttyColorKeys = [
    'background', 'foreground', 'cursor-color', 'cursor-text', 'selection-background', 'selection-foreground',
  ];

  // A theme from the text of a Ghostty theme file: the opposite of toGhostty.
  // A key that the file does not give takes the value of Ghostty. Without
  // colors, the cursor and the selection take the foreground and the
  // background, as in Ghostty. Keys that are not colors are ignored.
  //
  //   variant      "dark" or "light"; the default comes from the background
  //   resolveName  a function that gives "#rrggbb" for a named X11 color, or
  //                null. Without it, only hex colors are accepted.
  //
  // An incorrect line throws an error with the line number.
  const fromGhostty = (text, { variant = null, resolveName = null } = {}) => {
    const given = {};
    const palette = [...ghosttyDefaults.palette];
    const errors = [];
    String(text).split(/\r?\n/).forEach((raw, n) => {
      const line = raw.trim();
      if (line === '' || line.startsWith('#')) return;
      const at = `line ${n + 1}`;
      const m = /^([a-z0-9-]+)\s*=\s*(.*)$/.exec(line);
      if (!m) {
        errors.push(`${at}: "${line}" is not "key = value"`);
        return;
      }
      const key = m[1];
      const value = m[2].trim().replace(/^"(.*)"$/, '$1');
      const parseColor = (v) => {
        if (/^#?[0-9a-fA-F]{6}$/.test(v)) return color.normalize(v);
        const resolved = resolveName ? resolveName(v) : null;
        if (resolved) return color.normalize(resolved);
        errors.push(`${at}: "${v}" is not a color`);
        return null;
      };
      if (key === 'palette') {
        const pm = /^(\d+)\s*=\s*(.+)$/.exec(value);
        if (!pm) errors.push(`${at}: "${value}" is not "N=color"`);
        else if (Number(pm[1]) < 16) {
          const c = parseColor(pm[2].trim());
          if (c) palette[Number(pm[1])] = c;
        }
      } else if (ghosttyColorKeys.includes(key)) {
        if (value === 'cell-foreground' || value === 'cell-background') given[key] = value;
        else {
          const c = parseColor(value);
          if (c) given[key] = c;
        }
      } else if (key === 'minimum-contrast' || key === 'faint-opacity') {
        const x = Number(value);
        if (value === '' || !Number.isFinite(x)) errors.push(`${at}: "${value}" is not a number`);
        else given[key] = x;
      }
    });
    if (errors.length > 0) throw new Error(errors.join('\n'));

    const background = given.background || ghosttyDefaults.background;
    const foreground = given.foreground || ghosttyDefaults.foreground;
    // cell-foreground and cell-background: the colors of a cell with no
    // attributes.
    const pick = (key, fallback) =>
      ({ 'cell-foreground': foreground, 'cell-background': background })[given[key]] || given[key] || fallback;
    return {
      variant: variant || (color.isDark(background) ? 'dark' : 'light'),
      color: null,
      background,
      foreground,
      'cursor-color': pick('cursor-color', foreground),
      'cursor-text': pick('cursor-text', background),
      'selection-background': pick('selection-background', foreground),
      'selection-foreground': pick('selection-foreground', background),
      palette,
      'minimum-contrast': given['minimum-contrast'] ?? ghosttyDefaults['minimum-contrast'],
      'faint-opacity': given['faint-opacity'] ?? ghosttyDefaults['faint-opacity'],
    };
  };

  // The value of the Ghostty `theme` key for the themes NAME-light and
  // NAME-dark: Ghostty follows the color scheme of the desktop.
  const themeSetting = (name) => `light:${name}-light,dark:${name}-dark`;

  return {
    color, palettes, variants, defaultContrast, brightStep,
    mkTheme, mkThemes, toGhostty, fromGhostty, ghosttyDefaults, themeSetting, drawnText, faintText,
  };
});
