{
  description = "mz-term-colors: terminal themes from one color: dark and light, with WCAG contrast";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # The generator, in pure Nix: mkTheme, mkThemes, toGhostty, themeSetting,
      # and the color functions in `color`.
      lib = import ./lib { inherit (nixpkgs) lib; };

      # Shared source for the SVG preview and installable example themes.
      previewData = map (
        preset:
        preset
        // {
          themes = self.lib.mkThemes { inherit (preset) color; };
        }
      ) (import ./presets.nix);

      homeManagerModules.ghostty = ./hm-module.nix;
      homeManagerModules.default = self.homeManagerModules.ghostty;

      packages = forSystems (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.ghostty-colors;

        # `ghostty-colors COLOR [dark|light]` prints a theme. It uses the nix
        # command of the system.
        ghostty-colors = pkgs.writeShellApplication {
          name = "ghostty-colors";
          text = ''
            export GC_LIB=${./lib} NIXPKGS_LIB=${nixpkgs}/lib
          ''
          + builtins.readFile ./cli.sh;
        };

        # The dark and the light theme of some colors, to look at.
        examples = pkgs.linkFarm "ghostty-colors-examples" (
          nixpkgs.lib.concatMap (
            color:
            let
              t = self.lib.mkThemes { inherit color; };
              name = nixpkgs.lib.removePrefix "#" color;
            in
            [
              {
                name = "${name}-dark";
                path = pkgs.writeText "${name}-dark" (self.lib.toGhostty t.dark);
              }
              {
                name = "${name}-light";
                path = pkgs.writeText "${name}-light" (self.lib.toGhostty t.light);
              }
            ]
          ) (map (preset: preset.color) (import ./presets.nix))
        );
      });

      checks = forSystems (pkgs: {
        default = import ./tests.nix {
          inherit pkgs;
          gc = self.lib;
        };
      });

      formatter = forSystems (pkgs: pkgs.nixfmt);
    };
}
