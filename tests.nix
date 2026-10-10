# Checks of the theme generator and of the Home Manager module. The checks run
# at evaluation time: a failed check stops the evaluation with a message.
{ pkgs, gc }:
let
  inherit (pkgs) lib;
  c = gc.color;

  samples = [
    "#008080"
    "#800080"
    "#800000"
    "#599764"
    "#f29718"
    "#ffff00"
    "#00ff00"
    "#0000ff"
    "#ff0000"
    "#000000"
    "#ffffff"
    "#808080"
  ];

  check = what: ok: if ok then true else throw "mz-term-colors check failed: ${what}";
  all = lib.all (x: x);

  # The required ratios, fixed here: a change of the defaults of the library
  # must not make the checks weaker.
  ratios = {
    text = 7;
    cursor = 3;
    selection = 4.5;
    palette = 4.5;
    minimum = 3;
    faint = 3;
  };

  # The color that Ghostty draws for a glyph of color fg on a cell of color
  # bg: black or white when the contrast is less than `minimum-contrast`.
  # Refer to contrasted_color in src/renderer/shaders/glsl/common.glsl of
  # Ghostty.
  drawn =
    minimum: bg: fg:
    if c.contrast bg fg >= minimum then
      fg
    else if c.contrast bg "#ffffff" > c.contrast bg "#000000" then
      "#ffffff"
    else
      "#000000";

  # Faint text: the text color over the background with `faint-opacity`.
  faint =
    opacity: bg: fg:
    c.mix bg fg opacity;

  # The checks of one theme. `args` are the arguments of mkTheme.
  checkTheme =
    args:
    let
      t = gc.mkTheme args;
      variant = args.variant or "dark";
      bg = t.background;
      at = what: "${builtins.toJSON args}: ${what}";
      slot = builtins.elemAt t.palette;
      slots =
        if variant == "dark" then
          [ 0 ]
        else
          [
            7
            15
          ];
      file = gc.toGhostty t;
      has = line: lib.elem line (lib.splitString "\n" file);
    in
    check (at "the background is ${variant}") ((variant == "dark") == c.isDark bg)
    && check (at "text contrast") (c.contrast bg t.foreground >= ratios.text)
    && check (at "cursor contrast") (c.contrast bg t.cursor-color >= ratios.cursor)
    && check (at "cursor text contrast") (c.contrast t.cursor-color t.cursor-text >= ratios.selection)
    && check (at "selection text contrast") (
      c.contrast t.selection-background t.selection-foreground >= ratios.selection
    )
    && check (at "16 colors") (builtins.length t.palette == 16)
    # Programs write text in the ANSI colors: each color that is not of the
    # role of the background has the contrast of text (AA).
    && all (
      lib.imap0 (
        i: p:
        builtins.elem i slots
        || check (at "palette ${toString i} (${p}) contrast ${toString (c.contrast bg p)}") (
          c.contrast bg p >= ratios.palette
        )
      ) t.palette
    )
    # The colors of the role of the background keep the source colors.
    && all (
      map (
        i:
        check (at "palette ${toString i} keeps its color") (
          slot i == c.normalize (builtins.elemAt (args.palette or gc.palettes.${variant}) i)
        )
      ) slots
    )
    # Text in all 16 colors and in the foreground does not disappear in
    # Ghostty: `minimum-contrast` is set, and the drawn color has that
    # contrast, also for the colors of the role of the background.
    && check (at "minimum-contrast") (t.minimum-contrast >= ratios.minimum)
    && all (
      map (
        fg:
        check (at "drawn ${fg} contrast") (c.contrast bg (drawn t.minimum-contrast bg fg) >= ratios.minimum)
      ) (t.palette ++ [ t.foreground ])
    )
    # Faint text has the faint ratio, with the `faint-opacity` of the theme.
    && check (at "faint-opacity ${toString t.faint-opacity}") (
      t.faint-opacity >= 0.5 && t.faint-opacity <= 1
    )
    && check (at "faint text contrast") (
      c.contrast bg (faint t.faint-opacity bg t.foreground) >= ratios.faint
    )
    # A bright color (9..14) is lighter than its normal color (1..6), in
    # both variants.
    && all (
      map (
        i:
        check (at "palette ${toString i}: bright is lighter") (
          c.luminance (slot (i + 8)) > c.luminance (slot i)
        )
      ) (lib.range 1 6)
    )
    # The Ghostty file holds each value.
    && check (at "file: minimum-contrast") (
      has "minimum-contrast = ${builtins.toJSON t.minimum-contrast}"
    )
    && check (at "file: faint-opacity") (has "faint-opacity = ${builtins.toJSON t.faint-opacity}")
    && all (
      lib.imap0 (
        i: p: check (at "file: palette ${toString i}") (has "palette = ${toString i}=${p}")
      ) t.palette
    );

  # Each sample in both variants, and more difficult cases: a strong tint,
  # no tint, and the palette of the other variant (light colors on a light
  # background, dark colors on a dark background).
  cases = lib.concatMap (color: [
    {
      inherit color;
      variant = "dark";
    }
    {
      inherit color;
      variant = "light";
    }
    {
      inherit color;
      variant = "dark";
      tint = 0.3;
    }
    {
      inherit color;
      variant = "light";
      tint = 0.25;
    }
    {
      inherit color;
      variant = "dark";
      tint = 0;
    }
    {
      inherit color;
      variant = "light";
      tint = 0;
    }
    {
      inherit color;
      variant = "light";
      palette = gc.palettes.dark;
    }
    {
      inherit color;
      variant = "dark";
      palette = gc.palettes.light;
    }
  ]) samples;

  themeChecks = all (map checkTheme cases);

  # Known values: the WCAG contrast of black and white is 21, and the dark
  # theme of #008080 is the theme of the sandboxes of nix-config.
  valueChecks =
    check "contrast of black and white" (
      let
        d = c.contrast "#000000" "#ffffff" - 21;
      in
      d < 1.0e-3 && d > -1.0e-3
    )
    && check "normalize" (c.normalize "008080" == "#008080" && c.normalize "#00AAff" == "#00aaff")
    && check "dark #008080" (
      let
        t = gc.mkTheme { color = "#008080"; };
      in
      t.background == "#0d2125" && t.foreground == "#cad6d6" && t.cursor-color == "#008080"
    )
    # The light theme of #f29718, the host theme of nix-config: all text
    # colors reach 4.5, and each bright color is lighter than its normal
    # color. White (7) and bright white (15) keep the colors of the
    # background role, and Ghostty draws text in them in black.
    && check "light #f29718" (
      let
        t = gc.mkTheme {
          color = "#f29718";
          variant = "light";
        };
      in
      t.background == "#f9f2e3"
      && t.foreground == "#30271a"
      &&
        t.palette == [
          "#1a1a1a"
          "#c21010"
          "#3b6e08"
          "#745d00"
          "#1565a8"
          "#a8404a"
          "#176e51"
          "#d0cdc8"
          "#4a4a4a"
          "#c03636"
          "#58713c"
          "#7d6718"
          "#2971a7"
          "#a45564"
          "#287461"
          "#fafaf5"
        ]
      && t.minimum-contrast == 3
      && t.faint-opacity == 0.55
      && drawn t.minimum-contrast t.background "#d0cdc8" == "#000000"
      && drawn t.minimum-contrast t.background "#fafaf5" == "#000000"
    )
    # The dark theme of #f29718: bright black (8) was 3.1 before, now 4.5.
    && check "dark #f29718" (
      let
        t = gc.mkTheme { color = "#f29718"; };
      in
      builtins.elemAt t.palette 8 == "#8e8e8e"
      && t.faint-opacity == 0.5
      && drawn t.minimum-contrast t.background "#000000" == "#ffffff"
    )
    # A strong tint of white makes a gray background. The tint is less, thus
    # the text keeps its contrast.
    && check "a strong tint is less" (
      let
        t = gc.mkTheme {
          color = "#ffffff";
          tint = 0.3;
        };
      in
      c.isDark t.background
      && t.background != c.mix gc.variants.dark.background "#ffffff" 0.3
      && c.contrast t.background t.foreground >= ratios.text
    )
    && check "a bad color stops the evaluation" (
      !(builtins.tryEval (gc.mkTheme { color = "teal"; }).background).success
    );

  # The Home Manager module, with small stubs of the options of Home Manager.
  hm = lib.evalModules {
    modules = [
      ./hm-module.nix
      {
        options = {
          assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; };
          xdg.configFile = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule { options.text = lib.mkOption { type = lib.types.str; }; }
            );
          };
          programs.ghostty.settings = lib.mkOption { type = lib.types.attrs; };
        };
        config.programs.mz-term-colors = {
          themes.teal.color = "#008080";
          default = "teal";
        };
      }
    ];
  };

  moduleChecks =
    check "module writes both files" (
      hm.config.xdg.configFile ? "ghostty/themes/teal-dark"
      && hm.config.xdg.configFile ? "ghostty/themes/teal-light"
    )
    && check "module sets the theme key" (
      hm.config.programs.ghostty.settings.theme == "light:teal-light,dark:teal-dark"
    )
    && check "module file is the theme" (
      hm.config.xdg.configFile."ghostty/themes/teal-dark".text
      == gc.toGhostty (gc.mkTheme { color = "#008080"; })
    );
in
assert themeChecks && valueChecks && moduleChecks;
pkgs.runCommand "mz-term-colors-checks" { } ''
  echo "${toString (builtins.length cases)} themes checked" > $out
''
