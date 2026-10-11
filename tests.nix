# Checks of the Nix library and of the Home Manager module. tests.js checks
# the generator (lib/theme.js); the build of this check runs it.
{ pkgs, gc }:
let
  inherit (pkgs) lib;

  check = what: ok: if ok then true else throw "mz-term-colors check failed: ${what}";

  # The Home Manager module, with small stubs of the options of Home Manager.
  hm = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      ./hm-module.nix
      {
        options = {
          assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; };
          xdg.configFile = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule { options.source = lib.mkOption { type = lib.types.package; }; }
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

  teal = gc.ghosttyThemes { color = "#008080"; };

  moduleChecks =
    check "module writes both files" (
      hm.config.xdg.configFile ? "ghostty/themes/teal-dark"
      && hm.config.xdg.configFile ? "ghostty/themes/teal-light"
    )
    && check "module sets the theme key" (
      hm.config.programs.ghostty.settings.theme == "light:teal-light,dark:teal-dark"
    )
    && check "module file is the theme" (
      hm.config.xdg.configFile."ghostty/themes/teal-dark".source.outPath == teal.dark.outPath
    );

  # A theme with arguments for one variant: the build gives them to theme.js.
  custom = gc.ghosttyThemes {
    color = "#F29718";
    light.contrast.faint = 21;
  };
in
assert moduleChecks;
pkgs.runCommand "mz-term-colors-checks" { nativeBuildInputs = [ pkgs.nodejs-slim ]; } ''
  cp ${./tests.js} tests.js
  cp -r ${./lib} lib
  node tests.js > $out
  # The files of the Nix library are the output of theme.js.
  node lib/cli.js '#008080' dark | cmp - ${teal.dark}
  node lib/cli.js '#008080' light | cmp - ${teal.light}
  grep -qx 'faint-opacity = 1.0' ${custom.light}
  grep -qx 'faint-opacity = 0.5' ${custom.dark}
  grep -qx 'selection-background = #f29718' ${custom.dark}
''
