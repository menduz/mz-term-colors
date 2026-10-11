# mz-term-colors in Nix. lib/theme.js makes the themes: a build runs it with
# Node, so a theme is a file in the store. The web generator uses the same
# theme.js.
#
#   let gc = import ./lib { inherit pkgs; }; in
#   gc.ghosttyTheme { color = "#008080"; variant = "light"; }
{ pkgs }:
let
  inherit (pkgs) lib;

  # theme.js and the CLI that prints a theme.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./theme.js
      ./cli.js
    ];
  };
in
rec {
  # The Ghostty theme file of one variant. The arguments are the fields of
  # mkTheme in theme.js: color, variant ("dark" or "light"), background,
  # foreground, tint, palette, contrast.
  ghosttyTheme =
    args:
    pkgs.runCommand "ghostty-theme-${lib.toLower (lib.removePrefix "#" args.color)}-${args.variant or "dark"}"
      {
        nativeBuildInputs = [ pkgs.nodejs-slim ];
        themeArgs = builtins.toJSON args;
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        node ${src}/cli.js --json "$themeArgs" > $out
      '';

  # The dark and the light theme file of one color: { dark; light; }. `dark`
  # and `light` give extra arguments of ghosttyTheme for one variant.
  ghosttyThemes =
    {
      color,
      dark ? { },
      light ? { },
    }:
    {
      dark = ghosttyTheme ({ inherit color; } // dark // { variant = "dark"; });
      light = ghosttyTheme ({ inherit color; } // light // { variant = "light"; });
    };

  # The value of the Ghostty `theme` key for the themes NAME-light and
  # NAME-dark: Ghostty follows the color scheme of the desktop.
  themeSetting = name: "light:${name}-light,dark:${name}-dark";
}
