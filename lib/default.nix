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
    # The ANSI colors on the background: 3.
    palette = 3;
  };
in
rec {
  color = colorLib;
  inherit palettes defaultContrast;

  # The theme of one variant ("dark" or "light") for the input color. All
  # other arguments are optional:
  #
  #   background, foreground  the base colors, before the tint
  #   tint                    0..1: how much of the color goes into the background
  #   palette                 16 ANSI colors
  #   contrast                minimum ratios: { text; cursor; selection; palette; }
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

      bg = colorLib.mix (colorLib.normalize (pick background v.background)) c (pick tint v.tint);
      cursor = colorLib.readable bg c ratios.cursor;
    in
    assert lib.assertMsg (
      builtins.length basePalette == 16
    ) "mz-term-colors: a palette has 16 colors, not ${toString (builtins.length basePalette)}.";
    {
      inherit variant;
      color = c;
      background = bg;
      foreground = colorLib.readable bg (colorLib.mix (pick foreground v.foreground) c 0.1) ratios.text;
      cursor-color = cursor;
      cursor-text = colorLib.readable cursor bg ratios.selection;
      selection-background = c;
      selection-foreground = colorLib.readable c "#ffffff" ratios.selection;
      palette = lib.imap0 (
        i: p: if builtins.elem i v.backgroundSlots then p else colorLib.readable bg p ratios.palette
      ) basePalette;
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
      ++ lib.imap0 (i: p: "palette = ${toString i}=${p}") theme.palette
    )
    + "\n";

  # The value of the Ghostty `theme` key for the themes NAME-light and
  # NAME-dark: Ghostty follows the color scheme of the desktop.
  themeSetting = name: "light:${name}-light,dark:${name}-dark";
}
