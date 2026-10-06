# Colors "#rrggbb" in sRGB, in pure Nix. The luminance and the contrast ratio
# are the values of WCAG 2.1.
{ lib }:
rec {
  # Make a color "#rrggbb" from "rrggbb", "#rrggbb" or "#RRGGBB". Another
  # value stops the evaluation.
  normalize =
    c:
    let
      hex = lib.toLower (lib.removePrefix "#" c);
    in
    if builtins.match "[0-9a-f]{6}" hex != null then
      "#" + hex
    else
      throw "mz-term-colors: \"${c}\" is not a color. Give \"#rrggbb\".";

  # The three channels of a color, 0 to 255.
  channels =
    c:
    let
      hex = lib.removePrefix "#" (normalize c);
    in
    map (i: lib.fromHexString (builtins.substring (2 * i) 2 hex)) [
      0
      1
      2
    ];

  hex2 =
    n:
    let
      s = lib.toLower (lib.toHexString n);
    in
    if builtins.stringLength s == 1 then "0" + s else s;

  # Make a color from three channels. A channel is rounded and kept in 0..255.
  fromChannels =
    cs: "#" + lib.concatMapStrings (n: hex2 (lib.max 0 (lib.min 255 (builtins.floor (n + 0.5))))) cs;

  # Mix the color b into the color a. t = 0 gives a, t = 1 gives b.
  mix =
    a: b: t:
    fromChannels (lib.zipListsWith (x: y: x * (1 - t) + y * t) (channels a) (channels b));

  # The fifth root of x, for 0 < x <= 1. Nix has no power function, so Newton
  # iterations calculate the root.
  root5 =
    x:
    if x <= 0 then 0.0 else lib.foldl' (y: _: (4 * y + x / (y * y * y * y)) / 5) 1.0 (lib.range 1 30);

  # A channel (0 to 255) as linear light. x^2.4 = x^2 * (x^2)^(1/5).
  linear =
    n:
    let
      c = n / 255.0;
      x = (c + 5.5e-2) / 1.055;
    in
    if c <= 4.045e-2 then c / 12.92 else x * x * root5 (x * x);

  luminance =
    c:
    let
      l = map linear (channels c);
    in
    0.2126 * builtins.elemAt l 0 + 0.7152 * builtins.elemAt l 1 + 7.22e-2 * builtins.elemAt l 2;

  # The contrast ratio of two colors, 1 to 21.
  contrast =
    a: b:
    let
      la = luminance a;
      lb = luminance b;
    in
    (lib.max la lb + 5.0e-2) / (lib.min la lb + 5.0e-2);

  # True if white text has more contrast on the color than black text.
  isDark = c: contrast c "#ffffff" >= contrast c "#000000";

  # The color c, or c moved to white or to black (the one with more contrast
  # on bg), until its contrast on bg is `ratio` or more. The steps are 1/20.
  # If no step gets the ratio, the result is white or black.
  readable =
    bg: c: ratio:
    let
      target = if isDark bg then "#ffffff" else "#000000";
    in
    lib.findFirst (step: contrast bg step >= ratio) target (
      map (i: mix c target (i / 20.0)) (lib.range 0 20)
    );
}
