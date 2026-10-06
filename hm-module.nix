# Home Manager module: Ghostty themes from one color. Each theme NAME gives
# the files ~/.config/ghostty/themes/NAME-dark and NAME-light. Ghostty finds a
# theme there by its name.
{ config, lib, ... }:
let
  cfg = config.programs.mz-term-colors;
  gc = import ./lib { inherit lib; };

  themeType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        color = lib.mkOption {
          type = lib.types.strMatching "#?[0-9a-fA-F]{6}";
          example = "#008080";
          description = "The color of the theme.";
        };
        dark = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          example = {
            tint = 0.2;
            contrast.text = 4.5;
          };
          description = ''
            Arguments of `mkTheme` for the dark theme: `background`,
            `foreground`, `tint`, `palette`, `contrast`.
          '';
        };
        light = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Arguments of `mkTheme` for the light theme.";
        };
        themes = lib.mkOption {
          type = lib.types.attrs;
          readOnly = true;
          default = gc.mkThemes { inherit (config) color dark light; };
          description = "The two themes: { dark; light; }.";
        };
        setting = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = gc.themeSetting name;
          description = ''
            The value of the Ghostty `theme` key for this theme. Ghostty then
            follows the color scheme of the desktop.
          '';
        };
      };
    }
  );
in
{
  options.programs.mz-term-colors = {
    themes = lib.mkOption {
      type = lib.types.attrsOf themeType;
      default = { };
      example = {
        teal.color = "#008080";
      };
      description = "Ghostty themes, each one from one color.";
    };

    default = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "teal";
      description = ''
        A theme of `themes` for `programs.ghostty.settings.theme`. It has an
        effect only with `programs.ghostty`.
      '';
    };
  };

  config = lib.mkIf (cfg.themes != { }) {
    assertions = [
      {
        assertion = cfg.default == null || cfg.themes ? ${cfg.default};
        message = "programs.mz-term-colors.default: no theme has the name \"${toString cfg.default}\".";
      }
    ];

    xdg.configFile = lib.concatMapAttrs (name: t: {
      "ghostty/themes/${name}-dark".text = gc.toGhostty t.themes.dark;
      "ghostty/themes/${name}-light".text = gc.toGhostty t.themes.light;
    }) cfg.themes;

    programs.ghostty.settings = lib.mkIf (cfg.default != null) {
      theme = cfg.themes.${cfg.default}.setting;
    };
  };
}
