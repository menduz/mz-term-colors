# ghostty-colors: print a Ghostty theme for one color.
#
#   ghostty-colors COLOR [dark|light] [-o DIR -n NAME]
#
# With -o, write DIR/NAME-dark and DIR/NAME-light, and print the value of the
# Ghostty `theme` key. GC_LIB and NIXPKGS_LIB come from the package.

set -euo pipefail

usage() {
  echo "usage: ghostty-colors COLOR [dark|light] [-o DIR -n NAME]" >&2
  exit 2
}

color="" variant=dark out="" name=""
while [ $# -gt 0 ]; do
  case $1 in
    -o) out=${2:?}; shift 2 ;;
    -n) name=${2:?}; shift 2 ;;
    -h | --help) usage ;;
    dark | light) variant=$1; shift ;;
    *)
      [ -z "$color" ] || usage
      color=$1
      shift
      ;;
  esac
done
[ -n "$color" ] || usage
[[ $color =~ ^#?[0-9a-fA-F]{6}$ ]] || {
  echo "ghostty-colors: \"$color\" is not a color. Give \"#rrggbb\"." >&2
  exit 2
}

theme() { # theme VARIANT
  nix --extra-experimental-features nix-command eval --impure --raw --expr "
    let gc = import $GC_LIB { lib = import $NIXPKGS_LIB; };
    in gc.toGhostty (gc.mkTheme { color = \"$color\"; variant = \"$1\"; })"
}

if [ -z "$out" ]; then
  theme "$variant"
  exit
fi
[ -n "$name" ] || usage
mkdir -p "$out"
theme dark >"$out/$name-dark"
theme light >"$out/$name-light"
echo "theme = light:$name-light,dark:$name-dark"
