# mz-term-colors: terminal themes from one color. Pure Nix, no packages.
#
#   let gc = import ./lib { inherit lib; }; in
#   gc.toGhostty (gc.mkTheme { color = "#008080"; variant = "light"; })
{ lib }:
let
  colorLib = import ./color.nix { inherit lib; };
  palettes = import ./palettes.nix;

  # The base colors of each variant. The input color goes into the background
  # by `tint`, and into the text by 0.1.
  variants = {
    dark = {
      background = "#0f1419";
      foreground = "#e0e0e0";
      tint = 0.12;
      palette = palettes.dark;
      # Black has the role of the background, so it keeps its color.
      backgroundSlots = [ 0 ];
    };
    light = {
      background = "#fafaf5";
      foreground = "#1a1a1a";
      tint = 8.0e-2;
      palette = palettes.light;
      # White and bright white have the role of the background.
      backgroundSlots = [
        7
        15
      ];
    };
  };

  # The minimum contrast ratios (WCAG 2.1).
  defaultContrast = {
    # The text on the background: 7 (AAA).
    text = 7;
    # The cursor on the background: 3 (a part of the interface).
    cursor = 3;
    # The text in the cursor and in a selection: 4.5 (AA).
    selection = 4.5;
    # The ANSI colors on the background: 4.5 (AA), because programs write
    # text in them.
    palette = 4.5;
    # Ghostty `minimum-contrast`: Ghostty draws a glyph in black or white when
    # its contrast on the cell is less. Then text in a color of the role of the
    # background (white in the light variant, black in the dark variant) and
    # text in RGB colors does not disappear.
    minimum = 3;
    # Faint text on the background: 3. Ghostty draws faint text with
    # `faint-opacity` (default 0.5), and `minimum-contrast` does not see that
    # opacity.
    faint = 3;
  };

  # A bright color must be visibly lighter than its normal color: its
  # contrast on the background differs by this value or more.
  brightStep = 0.25;
in
rec {
  color = colorLib;
  inherit palettes variants defaultContrast;

  # The theme of one variant ("dark" or "light") for the input color. All
  # other arguments are optional:
  #
  #   background, foreground  the base colors, before the tint
  #   tint                    0..1: how much of the color goes into the background
  #   palette                 16 ANSI colors
  #   contrast                minimum ratios: { text; cursor; selection; palette; minimum; faint; }
  mkTheme =
    {
      color,
      variant ? "dark",
      background ? null,
      foreground ? null,
      tint ? null,
      palette ? null,
      contrast ? { },
    }:
    let
      v =
        variants.${variant}
          or (throw "mz-term-colors: the variant \"${variant}\" does not exist. Use \"dark\" or \"light\".");
      pick = value: default: if value == null then default else value;
      c = colorLib.normalize color;
      ratios = defaultContrast // contrast;
      basePalette = map colorLib.normalize (pick palette v.palette);

      # The background with the tint. A strong tint of a light color can make
      # the background so gray that no text gets the text ratio. Then the
      # tint is less, in steps of 1/20, until white text (dark variant) or
      # black text (light variant) gets that ratio.
      baseBackground = colorLib.normalize (pick background v.background);
      extreme = if variant == "dark" then "#ffffff" else "#000000";
      bg = lib.findFirst (b: colorLib.contrast b extreme >= ratios.text) baseBackground (
        map (i: colorLib.mix baseBackground c (pick tint v.tint * (1 - i / 20.0))) (lib.range 0 20)
      );
      cursor = colorLib.readable bg c ratios.cursor;

      # Each color that is not of the role of the background gets the palette
      # ratio. For red to cyan (1..6), the bright color (9..14) must stay
      # lighter than the normal color. On a light background, a lighter color
      # has less contrast: the normal color gets more contrast than the bright
      # color. On a dark background, the bright color gets more contrast than
      # the normal color.
      base = i: builtins.elemAt basePalette i;
      readableAt = i: ratio: colorLib.readable bg (base i) ratio;
      chromatic = i: (i >= 1 && i <= 6) || (i >= 9 && i <= 14);
      dark = colorLib.isDark bg;
      slot =
        i:
        if builtins.elem i v.backgroundSlots then
          base i
        else if !chromatic i then
          readableAt i ratios.palette
        else if i <= 6 then
          (
            if dark then
              readableAt i ratios.palette
            else
              readableAt i (lib.max ratios.palette (colorLib.contrast bg (slot (i + 8)) + brightStep))
          )
        else if dark then
          readableAt i (lib.max ratios.palette (colorLib.contrast bg (slot (i - 8)) + brightStep))
        else
          readableAt i ratios.palette;

      fg = colorLib.readable bg (colorLib.mix (pick foreground v.foreground) c 0.1) ratios.text;

      # The smallest opacity from 0.5 (the default of Ghostty) in steps of
      # 0.05 that gives faint text the faint ratio.
      faintOpacity = lib.findFirst (o: colorLib.contrast bg (colorLib.mix bg fg o) >= ratios.faint) 1.0 (
        map (i: i / 20.0) (lib.range 10 20)
      );
    in
    assert lib.assertMsg (
      builtins.length basePalette == 16
    ) "mz-term-colors: a palette has 16 colors, not ${toString (builtins.length basePalette)}.";
    {
      inherit variant;
      color = c;
      background = bg;
      foreground = fg;
      cursor-color = cursor;
      cursor-text = colorLib.readable cursor bg ratios.selection;
      selection-background = c;
      selection-foreground = colorLib.readable c "#ffffff" ratios.selection;
      palette = lib.genList slot 16;
      minimum-contrast = ratios.minimum;
      faint-opacity = faintOpacity;
    };

  # The dark and the light theme of one color: { dark = ...; light = ...; }.
  # `dark` and `light` give extra arguments of mkTheme for one variant.
  mkThemes =
    {
      color,
      dark ? { },
      light ? { },
    }:
    {
      dark = mkTheme ({ inherit color; } // dark // { variant = "dark"; });
      light = mkTheme ({ inherit color; } // light // { variant = "light"; });
    };

  # A theme as a Ghostty theme file.
  toGhostty =
    theme:
    lib.concatStringsSep "\n" (
      map (key: "${key} = ${theme.${key}}") [
        "background"
        "foreground"
        "cursor-color"
        "cursor-text"
        "selection-background"
        "selection-foreground"
      ]
      ++ [
        "minimum-contrast = ${builtins.toJSON theme.minimum-contrast}"
        "faint-opacity = ${builtins.toJSON theme.faint-opacity}"
      ]
      ++ lib.imap0 (i: p: "palette = ${toString i}=${p}") theme.palette
    )
    + "\n";

  # The value of the Ghostty `theme` key for the themes NAME-light and
  # NAME-dark: Ghostty follows the color scheme of the desktop.
  themeSetting = name: "light:${name}-light,dark:${name}-dark";
}
