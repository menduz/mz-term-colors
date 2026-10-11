#!/usr/bin/env node
// Write the preview of the presets of presets.json as an SVG file:
//
//   ./render.js [-o FILE]     (default: preview.svg beside this script)
'use strict';
const fs = require('fs');
const path = require('path');
const gc = require('./lib/theme.js');
const { presetsSvg } = require('./lib/preview.js');

const args = process.argv.slice(2);
let output = path.join(__dirname, 'preview.svg');
if (args[0] === '-o' && args[1]) output = args[1];
else if (args.length > 0) {
  console.error('usage: render.js [-o FILE]');
  process.exit(2);
}

const presets = require('./presets.json').map((p) => ({ ...p, themes: gc.mkThemes({ color: p.color }) }));
fs.writeFileSync(output, presetsSvg(presets));
console.log(`Wrote ${output}`);
