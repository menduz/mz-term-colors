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
      # The Nix library: `lib { inherit pkgs; }` gives ghosttyTheme,
      # ghosttyThemes and themeSetting. The generator is lib/theme.js.
      lib = import ./lib;

      homeManagerModules.ghostty = ./hm-module.nix;
      homeManagerModules.default = self.homeManagerModules.ghostty;

      packages = forSystems (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.ghostty-colors;

        # `ghostty-colors COLOR [dark|light]` prints a theme.
        ghostty-colors = pkgs.writeShellApplication {
          name = "ghostty-colors";
          runtimeInputs = [ pkgs.nodejs-slim ];
          text = ''
            exec node ${./lib}/cli.js "$@"
          '';
        };

        # The dark and the light theme of the colors of presets.json, to look
        # at.
        examples =
          let
            gc = self.lib { inherit pkgs; };
          in
          pkgs.linkFarm "ghostty-colors-examples" (
            nixpkgs.lib.concatMap (
              preset:
              let
                t = gc.ghosttyThemes { inherit (preset) color; };
                name = nixpkgs.lib.removePrefix "#" preset.color;
              in
              [
                {
                  name = "${name}-dark";
                  path = t.dark;
                }
                {
                  name = "${name}-light";
                  path = t.light;
                }
              ]
            ) (builtins.fromJSON (builtins.readFile ./presets.json))
          );
      });

      checks = forSystems (pkgs: {
        default = import ./tests.nix {
          inherit pkgs;
          gc = self.lib { inherit pkgs; };
        };
      });

      formatter = forSystems (pkgs: pkgs.nixfmt);
    };
}
