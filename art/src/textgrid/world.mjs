// Reads the Altstadt district from the game's data and paints its ground.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Img, hash2, rng } from './lib.mjs';
import * as G from './ground.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const T = G.T;

export function loadDistrict(id = 'altstadt') {
  const terrains = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/terrain.json'), 'utf8')).terrains;
  const byGlyph = Object.fromEntries(terrains.map((t) => [t.glyph, t.id]));
  const dir = path.join(ROOT, 'data/world/districts', id);
  const district = JSON.parse(fs.readFileSync(path.join(dir, 'district.json'), 'utf8'));
  const lines = fs.readFileSync(path.join(dir, district.levels['0']), 'utf8').replace(/\r/g, '').split('\n').filter((l) => l.length);
  const h = lines.length;
  const w = Math.max(...lines.map((l) => l.length));
  const cells = lines.map((l) => [...l.padEnd(w, ' ')].map((g) => byGlyph[g] ?? 'void'));
  const at = (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? 'void' : cells[y][x]);
  return { w, h, cells, at, district, root: ROOT };
}

const ROADLIKE = new Set(['road', 'tram_track', 'crossing']);
const BUILDING = new Set(['wall', 'window', 'door', 'floor_wood', 'floor_tile', 'floor_stone']);
export const isRoadlike = (t) => ROADLIKE.has(t);
export const isBuilding = (t) => BUILDING.has(t);

/** A few variants per terrain, picked per cell by a stable hash so nothing visibly repeats. */
function makeTiles() {
  const n = 6;
  const v = (f, seed) => Array.from({ length: n }, (_, i) => f(seed + i * 101));
  return {
    arc: v((s) => G.arcCobbles(s), 13),
    road: v((s) => G.asphalt(s), 17),
    sidewalk: v((s) => G.slabs(s), 19),
    grass: v((s) => G.grass(s), 23),
    water: v((s) => G.water(s), 29),
    tram_track: v((s) => G.track(s), 31),
  };
}

export function paintGround(world) {
  const tiles = makeTiles();
  const img = new Img(world.w * T, world.h * T, '#101014');
  const pick = (list, x, y) => list[Math.floor(hash2(x, y, 5) * list.length)];
  for (let y = 0; y < world.h; y++) {
    for (let x = 0; x < world.w; x++) {
      const t = world.at(x, y);
      const px = x * T;
      const py = y * T;
      switch (t) {
        case 'cobblestone':
        case 'fountain':
        case 'tree':
        case 'bridge':
          img.blit(pick(tiles.arc, x, y), px, py);
          break;
        case 'road':
          img.blit(pick(tiles.road, x, y), px, py);
          break;
        case 'tram_track':
          img.blit(pick(tiles.tram_track, x, y), px, py);
          break;
        case 'crossing':
          crossing(img, world, x, y, pick(tiles.road, x, y));
          break;
        case 'sidewalk':
          img.blit(pick(tiles.sidewalk, x, y), px, py);
          break;
        case 'grass':
        case 'hedge':
          img.blit(pick(tiles.grass, x, y), px, py);
          break;
        case 'water':
          img.blit(pick(tiles.water, x, y), px, py);
          break;
        default:
          if (isBuilding(t)) img.rect(px, py, T, T, 'slab1');
      }
    }
  }
  // Trees stand in the square's paving or in grass, whichever surrounds them.
  for (let y = 0; y < world.h; y++) {
    for (let x = 0; x < world.w; x++) {
      const grassy = [world.at(x, y - 1), world.at(x - 1, y), world.at(x + 1, y), world.at(x, y + 1)].filter((t) => t === 'grass').length >= 2;
      if (world.at(x, y) === 'tree' && grassy) img.blit(pick(tiles.grass, x, y), x * T, y * T);
    }
  }
  squareBands(img, world);
  edges(img, world);
  litter(img, world);
  return img;
}

function crossing(img, world, x, y, road) {
  const px = x * T;
  const py = y * T;
  img.blit(road, px, py);
  const left = world.at(x - 1, y) === 'crossing' ? 0 : 2;
  const right = world.at(x + 1, y) === 'crossing' ? T : T - 2;
  const r = rng(x * 131 + y * 17);
  for (let j = 0; j < T; j++) {
    if (j % 8 >= 4) continue; // 4 px bars, 4 px gaps, parallel to the traffic
    for (let i = left; i < right; i++) {
      const v = r();
      if (v < 0.03) continue; // worn through
      img.px(px + i, py + j + 1, v < 0.12 ? 'paintWorn' : 'paint');
    }
  }
  const trackRow = world.at(x - 1, y) === 'tram_track' || world.at(x + 1, y) === 'tram_track' || world.at(x - 2, y) === 'tram_track' || world.at(x + 2, y) === 'tram_track';
  if (trackRow) {
    const tmp = G.track(x * 7 + y);
    img.blit(tmp, px, py + 2, 0, 2, T, 3);
    img.blit(tmp, px, py + 11, 0, 11, T, 3);
  }
}

/** The Altmarkt's paving is divided into fields by bands of pale granite. */
function squareBands(img, world) {
  const sq = world.district.places.find((p) => p.id === 'altmarkt');
  if (!sq) return;
  const [x0, y0, w, h] = sq.rect;
  const paved = (x, y) => ['cobblestone', 'tree', 'fountain'].includes(world.at(x, y));
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      if (!paved(x, y)) continue;
      if ((x - x0) % 7 === 0) G.band(img, x * T + 6, y * T, 3, T, x * 31 + y);
      if ((y - y0) % 6 === 3) G.band(img, x * T, y * T + 6, T, 3, x * 17 + y * 3);
    }
  }
}

/** Curbs, gutters and stone borders where surfaces meet. */
function edges(img, world) {
  for (let y = 0; y < world.h; y++) {
    for (let x = 0; x < world.w; x++) {
      const t = world.at(x, y);
      const px = x * T;
      const py = y * T;
      const s = world.at(x, y + 1);
      const n = world.at(x, y - 1);
      if (t === 'sidewalk') {
        if (isRoadlike(s)) {
          // Curb facing the camera: top, highlight, then its face.
          img.hline(px, px + T - 1, py + 12, 'curb3');
          img.hline(px, px + T - 1, py + 13, 'curb2');
          img.hline(px, px + T - 1, py + 14, 'curb1');
          img.hline(px, px + T - 1, py + 15, 'curb0');
          for (let i = 0; i < T; i += 8) img.vline(px + ((i + x * 5) % T), py + 12, py + 13, 'curb1');
        }
        if (isRoadlike(n)) {
          img.hline(px, px + T - 1, py, 'curb1');
          img.hline(px, px + T - 1, py + 1, 'curb3');
          img.hline(px, px + T - 1, py + 2, 'curb2');
          img.hline(px, px + T - 1, py + 3, 'slab0');
          for (let i = 0; i < T; i += 8) img.vline(px + ((i + x * 5) % T), py + 1, py + 2, 'curb1');
        }
        if (s === 'cobblestone' || s === 'tree' || s === 'grass') {
          img.hline(px, px + T - 1, py + 14, 'curb2');
          img.hline(px, px + T - 1, py + 15, 'curb1');
        }
      }
      if (isRoadlike(t) && n === 'sidewalk') {
        img.hline(px, px + T - 1, py, 'asph0');
      }
      if (t === 'road' && s === 'sidewalk') {
        img.hline(px, px + T - 1, py + 15, 'asph0');
      }
      if (t === 'grass') {
        const hard = (u) => u === 'cobblestone' || u === 'sidewalk' || u === 'fountain';
        if (hard(n)) {
          img.hline(px, px + T - 1, py, 'curb3');
          img.hline(px, px + T - 1, py + 1, 'curb1');
        }
        if (hard(s)) {
          img.hline(px, px + T - 1, py + 14, 'curb2');
          img.hline(px, px + T - 1, py + 15, 'curb1');
        }
        if (hard(world.at(x - 1, y))) img.vline(px, py, py + T - 1, 'curb2');
        if (hard(world.at(x + 1, y))) img.vline(px + T - 1, py, py + T - 1, 'curb1');
      }
    }
  }
}

/** Manholes, drains, tar-filled cracks, gum and cigarette butts. */
function litter(img, world) {
  for (let y = 0; y < world.h; y++) {
    for (let x = 0; x < world.w; x++) {
      const t = world.at(x, y);
      const px = x * T;
      const py = y * T;
      const h = hash2(x, y, 77);
      if (t === 'road') {
        if (h < 0.02) img.grid(G.MANHOLE, px + 2, py + 2);
        else if (h < 0.12) crack(img, px, py, hash2(x, y, 3));
        if (world.at(x, y + 1) === 'sidewalk' && x % 9 === 4) img.grid(G.DRAIN, px + 3, py + 12);
        if (world.at(x, y - 1) === 'sidewalk' && x % 9 === 0) img.grid(G.DRAIN, px + 3, py + 1);
      }
      if (t === 'sidewalk' || t === 'cobblestone') {
        const r = rng(Math.floor(h * 1e9));
        const n = t === 'sidewalk' ? 2 : 1;
        for (let k = 0; k < n; k++) {
          const v = r();
          const lx = px + 1 + Math.floor(r() * 13);
          const ly = py + 4 + Math.floor(r() * 9);
          if (v < 0.22) img.grid(G.GUM, lx, ly);
          else if (v < 0.3) img.grid(G.BUTT, lx, ly);
          else if (v < 0.32) img.grid(G.CAP, lx, ly);
        }
      }
    }
  }
}

function crack(img, px, py, seed) {
  const r = rng(Math.floor(seed * 1e9));
  let x = px + Math.floor(r() * T);
  let y = py + Math.floor(r() * 4);
  const len = 6 + Math.floor(r() * 10);
  for (let i = 0; i < len; i++) {
    img.px(x, y, 'tar');
    y += 1;
    x += r() < 0.3 ? -1 : r() < 0.6 ? 1 : 0;
    if (y >= py + T) break;
  }
}
