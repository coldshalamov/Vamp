#!/usr/bin/env node
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const calls = { ground: 0, buildings: 0, lut: 0, panel: 0, ui: 0, menus: 0 };
const gradient = { addColorStop() {} };
const ctx = new Proxy({
  canvas: { width: 1280, height: 720 },
  createRadialGradient: () => gradient,
  createLinearGradient: () => gradient,
  measureText: (s) => ({ width: String(s).length * 8 }),
}, { get(target, key) { return key in target ? target[key] : (() => {}); }, set(target, key, value) { target[key] = value; return true; } });

globalThis.window = globalThis;
globalThis.document = { createElement() { return { width: 0, height: 0, getContext: () => ctx }; } };
globalThis.VAMP = {
  Util: { clamp: (v, a, b) => Math.max(a, Math.min(b, v)) },
  ArtFlags: {},
  World: { T: { ROAD: 1, SIDEWALK: 2 } },
  WorldRender: {
    renderGround() { calls.ground++; },
    renderBuildings() { calls.buildings++; },
  },
  PostFX: { districtLUT() { calls.lut++; } },
  Theme: {
    panel() { calls.panel++; }, drawPanel() {}, drawSlot() {},
  },
  UI: { render() { calls.ui++; } },
  Menus: { render() { calls.menus++; } },
  Game: { quality: 'high', reducedMotion: false },
};

vm.runInThisContext(fs.readFileSync(path.join(root, 'js/render/nocturne.js'), 'utf8'), { filename: 'nocturne.js' });
assert.ok(VAMP.Nocturne, 'Nocturne public API must exist');
assert.equal(VAMP.ArtFlags.useNocturne, true);

const world = {
  TILE: 32, cols: 4, rows: 4, w: 128, h: 128,
  tile: new Array(16).fill(1), idx(c, r) { return r * 4 + c; },
  buildings: [{ x: 10, y: 10, w: 50, h: 40, height: 30, d: 0, seed: 2 }],
};
const cam = {
  zoom: 1,
  viewRect() { return { x: 0, y: 0, w: 128, h: 128 }; },
  worldToScreen(x, y) { return { x, y }; },
};
VAMP.WorldRender.renderGround(ctx, cam, world, 1000);
VAMP.WorldRender.renderBuildings(ctx, cam, world, 1000);
VAMP.PostFX.districtLUT(ctx, { mode: 'play' }, 1280, 720);
VAMP.Theme.panel(ctx, 10, 10, 200, 100, {});
VAMP.UI.render(ctx, { mode: 'play', time: 1, player: { x: 20, y: 20 }, cam }, 1280, 720);
VAMP.Menus.render(ctx, {}, 1280, 720);
assert.deepEqual(calls, { ground: 1, buildings: 1, lut: 1, panel: 1, ui: 1, menus: 1 });
VAMP.Nocturne.setEnabled(false);
assert.equal(VAMP.Nocturne.enabled, false);
console.log('Nocturne smoke test passed');
