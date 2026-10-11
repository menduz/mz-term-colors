// Ghostty themes for the "Ghostty theme" slots of the web generator.
// mztheme: the themes of the host in nix-config before mz-term-colors
// (conf.d/mztheme-dark and conf.d/mztheme-light); the default palettes of
// theme.js come from them.
var GHOSTTY_PRESETS = [
  {
    name: 'mztheme (before mz-term-colors)',
    dark: `background = 0f1419
foreground = e0e0e0
cursor-color = 00ff00
cursor-text = ffffff
selection-background = f29718
selection-foreground = 000000

palette = 0=000000
palette = 1=ff3333
palette = 2=b8cc52
palette = 3=e7c547
palette = 4=36a3d9
palette = 5=f07178
palette = 6=95e6cb
palette = 7=f0f0f0
palette = 8=323232
palette = 9=ff6565
palette = 10=eafe84
palette = 11=fff779
palette = 12=68d5ff
palette = 13=ffa3aa
palette = 14=c7fffd
palette = 15=ffffff
`,
    light: `background = fafaf5
foreground = 1a1a1a
cursor-color = f29718
cursor-text = ffffff
selection-background = f29718
selection-foreground = 000000

palette = 0=1a1a1a
palette = 1=cc1111
palette = 2=4a8a0a
palette = 3=9b7c00
palette = 4=1565a8
palette = 5=a8404a
palette = 6=1a7a5a
palette = 7=d0cdc8
palette = 8=4a4a4a
palette = 9=e02222
palette = 10=5a9a14
palette = 11=b8920a
palette = 12=1878c0
palette = 13=c05060
palette = 14=228870
palette = 15=fafaf5
`,
  },
];
