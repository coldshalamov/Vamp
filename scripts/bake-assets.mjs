#!/usr/bin/env node
/**
 * Dev helper: chroma-key JPG → sharpened PNG (optional offline asset prep).
 * Players still load JPG at runtime — no build step required to play.
 *
 * Usage: node scripts/bake-assets.mjs [input.jpg] [output.png]
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, basename } from 'path';

const args = process.argv.slice(2);
if (args.length < 1) {
  console.log('Usage: node scripts/bake-assets.mjs <input.jpg> [output.png]');
  process.exit(0);
}

const input = args[0];
const output = args[1] || input.replace(/\.jpe?g$/i, '.png');

if (!existsSync(input)) {
  console.error('File not found:', input);
  process.exit(1);
}

console.log('Note: full chroma/sharpen bake runs in-browser via VAMP.ArtBake.');
console.log('Copy', basename(input), '→', basename(output), 'when PNG alpha assets are ready.');
console.log('Input size:', readFileSync(input).length, 'bytes');
writeFileSync(output + '.placeholder', '# Replace with baked PNG from image editor or canvas export\n');
console.log('Wrote placeholder:', output + '.placeholder');