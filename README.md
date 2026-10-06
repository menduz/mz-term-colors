# mz-term-colors

Make dark and light terminal themes from one color. Requires Nix with flakes.
The library is `mz-term-colors`. Its first and only output is `ghostty-colors`
for Ghostty.

Plays well with the preset themes of
[win-classic-theme](https://github.com/menduz/win-classic-theme).

```sh
# Print one theme.
nix run .#ghostty-colors -- '#008080' dark

# Install both themes.
nix run .#ghostty-colors -- '#008080' -o ~/.config/ghostty/themes -n teal
```

Add the output line to the Ghostty configuration:

```ini
theme = light:teal-light,dark:teal-dark
```

To use the published source, replace `.` with `github:menduz/mz-term-colors`.
The default package also runs `ghostty-colors`.

## Preview

Requires Python 3 and Nix. Run from this directory:

```sh
./render.py
# Optional: select an output file.
./render.py -o /tmp/themes.svg
```

Edit `presets.nix` to change the seed colors. The first preset uses the default mz palette
and signature orange (`#f29718`). Teal (`#008080`) and navy
(`#000080`) follow. After each theme change, run
`./render.py`. Commit `preview.svg` with the change.

The script reads the current Nix generator. It shows both variants, all 16
ANSI colors, selected text, and a cursor. The fetch display uses fixed sample
data. It does not read system data. The first run can require network access.

![Dark and light mz-colors, teal, and navy themes](preview.svg)

## Home Manager

```nix
{
  imports = [ inputs.mz-term-colors.homeManagerModules.ghostty ];
  programs.mz-term-colors = {
    themes.teal.color = "#008080";
    default = "teal";
  };
}
```

## Library

```nix
let gc = inputs.mz-term-colors.lib;
in gc.toGhostty (gc.mkTheme { color = "#008080"; variant = "light"; })
```

Use `mkThemes { color = "#008080"; }` for both variants. Use `mkTheme` to
set `background`, `foreground`, `tint`, `palette`, or `contrast`.

Minimum contrast ratios: text 7; cursor 3; selection text 4.5; ANSI colors 3.
Background palette slots keep their source colors.

## Check

```sh
nix flake check
```

Checks cover 24 themes, contrast ratios, and Home Manager output.

## License

[Apache-2.0](LICENSE).
