#!/usr/bin/env bash
# Write web/win-classic-colors.js: the color schemes of win-classic-theme, for
# the swatches of the web generator.
#
#   web/update-win-classic-colors.sh [PRESETS]
#
# PRESETS is the presets.nix of a win-classic-theme checkout. The default is
# the file of github:menduz/win-classic-theme.

set -euo pipefail

presets=${1:-}
if [ -z "$presets" ]; then
  src=$(nix --extra-experimental-features 'nix-command flakes' flake prefetch --json \
    github:menduz/win-classic-theme | sed -n 's/.*"storePath":"\([^"]*\)".*/\1/p')
  presets=$src/presets.nix
fi

out=$(dirname "$0")/win-classic-colors.js
json=$(nix --extra-experimental-features nix-command eval --json --file "$presets")
{
  echo "// The color schemes of win-classic-theme (presets.nix). Written by"
  echo "// update-win-classic-colors.sh; do not edit."
  echo "var WIN_CLASSIC_PRESETS = $json;"
} >"$out"
echo "Wrote $out"
