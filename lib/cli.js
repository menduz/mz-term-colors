#!/usr/bin/env node
// ghostty-colors: print a Ghostty theme for one color.
//
//   ghostty-colors COLOR [dark|light] [-o DIR -n NAME]
//   ghostty-colors --json ARGS
//
// With -o, write DIR/NAME-dark and DIR/NAME-light, and print the value of the
// Ghostty `theme` key. With --json, ARGS are the arguments of mkTheme as JSON
// (lib/default.nix builds the theme files so).
'use strict';
const fs = require('fs');
const path = require('path');
const gc = require('./theme.js');

const usage = () => {
  console.error('usage: ghostty-colors COLOR [dark|light] [-o DIR -n NAME]');
  process.exit(2);
};
const fail = (message) => {
  console.error(`ghostty-colors: ${message}`);
  process.exit(2);
};

const args = process.argv.slice(2);
if (args[0] === '--json') {
  if (args.length !== 2) usage();
  try {
    process.stdout.write(gc.toGhostty(gc.mkTheme(JSON.parse(args[1]))));
  } catch (e) {
    fail(e.message);
  }
  process.exit(0);
}

let color = '';
let variant = 'dark';
let out = '';
let name = '';
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '-o' || a === '-n') {
    if (i + 1 >= args.length) usage();
    if (a === '-o') out = args[++i];
    else name = args[++i];
  } else if (a === '-h' || a === '--help') usage();
  else if (a === 'dark' || a === 'light') variant = a;
  else if (color === '') color = a;
  else usage();
}
if (color === '') usage();
if (!/^#?[0-9a-fA-F]{6}$/.test(color)) fail(`"${color}" is not a color. Give "#rrggbb".`);

if (out === '') {
  process.stdout.write(gc.toGhostty(gc.mkTheme({ color, variant })));
  process.exit(0);
}
if (name === '') usage();
fs.mkdirSync(out, { recursive: true });
const themes = gc.mkThemes({ color });
fs.writeFileSync(path.join(out, `${name}-dark`), gc.toGhostty(themes.dark));
fs.writeFileSync(path.join(out, `${name}-light`), gc.toGhostty(themes.light));
console.log(`theme = ${gc.themeSetting(name)}`);
