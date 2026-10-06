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

  checkTheme =
    color: variant:
    let
      t = gc.mkTheme { inherit color variant; };
      bg = t.background;
      at = what: "${color} ${variant}: ${what}";
      slots =
        if variant == "dark" then
          [ 0 ]
        else
          [
            7
            15
          ];
    in
    check (at "the background is ${variant}") ((variant == "dark") == c.isDark bg)
    && check (at "text contrast") (c.contrast bg t.foreground >= 7)
    && check (at "cursor contrast") (c.contrast bg t.cursor-color >= 3)
    && check (at "cursor text contrast") (c.contrast t.cursor-color t.cursor-text >= 4.5)
    && check (at "selection text contrast") (
      c.contrast t.selection-background t.selection-foreground >= 4.5
    )
    && lib.all (x: x) (
      lib.imap0 (
        i: p: builtins.elem i slots || check (at "palette ${toString i} contrast") (c.contrast bg p >= 3)
      ) t.palette
    )
    # Bright chromatic colors must remain lighter after contrast correction.
    && (
      variant != "light"
      || lib.all (
        i:
        let
          normal = builtins.elemAt t.palette i;
          bright = builtins.elemAt t.palette (i + 8);
        in
        check (at "palette ${toString i}: bright is lighter") (c.luminance bright > c.luminance normal)
      ) (lib.range 1 6)
    );

  themeChecks = lib.all (x: x) (
    lib.concatMap (color: [
      (checkTheme color "dark")
      (checkTheme color "light")
    ]) samples
  );

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
  echo "${toString (builtins.length samples * 2)} themes checked" > $out
''
