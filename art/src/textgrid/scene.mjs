// Composes the Altmarkt mock-up from the real district data: ground, buildings, props,
// the tram and people, sorted back to front, then lit for day or night.
import fs from 'node:fs';
import path from 'node:path';
import { Img, bayer } from './lib.mjs';
import { loadDistrict, paintGround } from './world.mjs';
import { building } from './buildings.mjs';
import * as P from './props.mjs';
import { tram, TRAM } from './tram.mjs';
import { personRamps, drawPerson } from './people.mjs';

const T = 16;
const BUILDING_KINDS = new Set(['church', 'cafe', 'shop', 'bar', 'home', 'restaurant', 'police']);

export function compose() {
  const world = loadDistrict();
  const scene = paintGround(world);
  const emit = new Img(scene.w, scene.h);
  const lights = [];
  const items = [];
  const data = (f) => JSON.parse(fs.readFileSync(path.join(world.root, 'data', f), 'utf8'));
  const appearance = data('appearance/appearance.json');
  const colours = data('clothing/colours.json').colours;

  /** Adds an object whose image bottom edge stands on scene row `baseY`. */
  const put = (obj, x, baseY, extra = {}) => {
    const y = baseY - obj.img.h;
    items.push({ ...extra, img: obj.img, emit: obj.emit, x: Math.round(x), y: Math.round(y), baseY });
    for (const l of obj.lights ?? []) lights.push({ ...l, x: l.x + x, y: l.y + y });
    return { x, y };
  };
  const shadow = (cx, cy, rx, ry, alpha = 0.34) => {
    for (let y = Math.floor(cy - ry); y <= cy + ry; y++) {
      for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
        const d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2;
        if (d <= 1) scene.px(x, y, [27, 24, 48, Math.round(255 * alpha * (d < 0.55 ? 1 : 0.6))]);
      }
    }
  };

  // Buildings, with a soft contact shadow along each facade.
  for (const place of world.district.places) {
    if (!BUILDING_KINDS.has(place.kind)) continue;
    const b = building(world, place);
    put(b, b.x, b.baseY);
    for (let x = b.x; x < b.x + b.img.w; x++) {
      scene.px(x, b.baseY, [27, 24, 48, 80]);
      scene.px(x, b.baseY + 1, [27, 24, 48, 40]);
    }
  }

  // The tram, stopped at Altmarkt on the eastbound track, and its contact wires.
  const tr = tram({ seed: 4 });
  const tramX = 19 * T;
  const tramBase = 21.5 * T;
  put(tr, tramX, tramBase);
  for (let y = tramBase - 10; y < tramBase + 3; y++) {
    const a = y < tramBase - 2 ? 0.5 : 0.32;
    for (let x = tramX + 4 + Math.max(0, y - tramBase + 3); x < tramX + TRAM.length + 5; x++) scene.px(x, y, [27, 24, 48, Math.round(255 * a)]);
  }
  for (const trackRow of [18, 20]) {
    const wy = (trackRow + 0.5) * T - 88;
    items.push({
      baseY: (trackRow + 0.5) * T,
      draw: (img) => {
        for (let x = 0; x < scene.w; x++) {
          const span = (x % (12 * T)) / (12 * T);
          const sag = Math.round(Math.sin(span * Math.PI) * 2);
          img.px(x, wy + sag, '#17161c@80');
        }
      },
    });
  }

  // Street lanterns along both pavements.
  const lanternAt = (cx, baseY) => {
    const l = P.lamp();
    const at = put({ img: l.img, emit: l.emit }, cx - 4, baseY);
    shadow(cx + 2, baseY - 1, 4, 1.5, 0.3);
    lights.push({ x: cx, y: baseY - 12, r: 60, color: [1.0, 0.6, 0.26], power: 1.15 });
    lights.push({ x: cx, y: at.y + 7, r: 14, color: [1.0, 0.75, 0.4], power: 1.1 });
  };
  for (const cx of [19.5, 31, 42.5]) lanternAt(cx * T, 16 * T + 11);
  for (const cx of [21.5, 36, 45]) lanternAt(cx * T, 22 * T + 8);

  // Tram stop Altmarkt: shelter, sign, bin.
  const sh = P.shelter();
  put(sh, 22.4 * T, 23 * T - 1);
  shadow(22.4 * T + 28, 23 * T - 2, 26, 2.5, 0.28);
  const sign = P.stopSign('ALTMARKT');
  put(sign, 32.3 * T - sign.img.w / 2, 22 * T + 11);
  shadow(32.3 * T + 3, 22 * T + 10, 4, 1.5, 0.3);
  put({ img: gridImg(P.BIN) }, 26.2 * T, 22 * T + 13);

  // The square: trees, an advertising column, benches, the fountain, pigeons.
  for (let cy = 0; cy < world.h; cy++) {
    for (let cx = 0; cx < world.w; cx++) {
      if (world.at(cx, cy) === 'hedge') {
        const front = world.at(cx, cy + 1) !== 'hedge';
        const hg = P.hedge(cx, cy, front);
        put(hg, cx * T, (cy + 1) * T);
        items[items.length - 1].y = cy * T - 12; // the top of the hedge is 12 px above the ground
        if (front) shadow(cx * T + 9, (cy + 1) * T, 9, 2, 0.25);
      }
      if (world.at(cx, cy) !== 'tree') continue;
      const inSquare = world.at(cx, cy - 1) !== 'grass' && world.at(cx - 1, cy) !== 'grass';
      if (inSquare) treeGrate(scene, cx * T + 8, cy * T + 10);
      const t = P.tree(cx * 7 + cy);
      shadow(cx * T + 16, cy * T + 12, 27, 8, 0.26);
      put(t, cx * T + 8 - t.img.w / 2, cy * T + 12);
    }
  }
  const lf = P.litfass(7);
  shadow(38.6 * T + 12, 26 * T + 13, 11, 3, 0.3);
  put(lf, 38.6 * T, 26 * T + 14);
  const f = P.fountain();
  shadow(31 * T + 20, 30 * T - 3, 18, 4, 0.25);
  put(f, 31 * T - 2, 30 * T);
  for (const cx of [26.4, 38.1]) lanternAt(cx * T, 28 * T + 2);
  for (const bx of [27.2, 35.1]) {
    shadow(bx * T + 16, 27 * T + 13, 15, 2, 0.28);
    put({ img: gridImg(P.BENCH) }, bx * T, 27 * T + 14);
  }
  put({ img: gridImg(P.PIGEONS[0]) }, 28.4 * T, 29.4 * T);
  put({ img: gridImg(P.PIGEONS[1]) }, 29.3 * T, 29.9 * T);
  put({ img: gridImg(P.PIGEONS[0]) }, 35.6 * T, 30.6 * T);
  put({ img: gridImg(P.PIGEONS[1]) }, 23.2 * T, 27.5 * T);

  // Pavement life on the north side: the café's board, bikes at the laundry.
  put({ img: P.bike('red2') }, 37.2 * T, 16 * T + 10);
  put({ img: P.bike('teal2') }, 38.3 * T, 16 * T + 11);

  // People: Alex (the default player) waits for the tram; residents go about their day.
  const alex = data('appearance/default_player.json');
  const people = [
    { who: alex, hair: alex.appearance.hair_style, x: 30.7, feet: 22 * T + 13 },
    {
      who: { appearance: { skin_tone: 'skin_02', hair_colour: 'ginger', eye_colour: 'green' }, outfit: { top: { colour: 'white' }, outer: { colour: 'denim' }, bottom: { colour: 'black' }, feet: { colour: 'white' } } },
      hair: 'long', x: 28.9, feet: 25.6 * T,
    },
    {
      who: { appearance: { skin_tone: 'skin_07', hair_colour: 'black', eye_colour: 'dark_brown' }, outfit: { top: { colour: 'mustard' }, bottom: { colour: 'charcoal' }, feet: { colour: 'black' } } },
      hair: 'bun', x: 35.3, feet: 16 * T + 13,
    },
    {
      who: { appearance: { skin_tone: 'skin_05', hair_colour: 'grey', eye_colour: 'brown' }, outfit: { top: { colour: 'navy' }, outer: { colour: 'olive' }, bottom: { colour: 'beige' }, feet: { colour: 'brown' } } },
      hair: 'short', x: 34.2, feet: 30.5 * T,
    },
  ];
  for (const p of people) {
    const img = new Img(16, 34);
    drawPerson(img, 0, 0, personRamps(appearance, colours, p.who), p.hair, { outer: Boolean(p.who.outfit.outer) });
    put({ img }, p.x * T, p.feet + 3);
  }

  // Back to front. Glowing pixels are hidden by whatever is drawn in front of them.
  items.sort((a, b) => a.baseY - b.baseY);
  for (const it of items) {
    if (it.draw) {
      it.draw(scene);
      continue;
    }
    for (let j = 0; j < it.img.h; j++) {
      for (let i = 0; i < it.img.w; i++) {
        const p = it.img.get(i, j);
        if (p[3] <= 0) continue;
        const x = it.x + i;
        const y = it.y + j;
        scene.px(x, y, p);
        if (p[3] > 127 && x >= 0 && y >= 0 && x < emit.w && y < emit.h) {
          const q = it.emit ? it.emit.get(i, j) : [0, 0, 0, 0];
          emit.d.set(q, (y * emit.w + x) * 4);
        }
      }
    }
  }
  return { world, scene, emit, lights };
}

function gridImg(g) {
  const img = new Img(g.w, g.h);
  img.grid(g, 0, 0);
  return img;
}

function treeGrate(img, cx, cy) {
  for (let y = -4; y <= 4; y++) {
    for (let x = -8; x <= 8; x++) {
      const edge = Math.abs(y) === 4 || Math.abs(x) === 8;
      img.px(cx + x, cy + y, edge ? 'mt1' : (x + 8) % 3 === 0 ? 'mt0' : 'mt2');
    }
  }
  for (let y = -2; y <= 2; y++) for (let x = -3; x <= 3; x++) if (x * x + y * y * 3 < 11) img.px(cx + x, cy + y, 'soil0');
}

/** Night: a dark blue ambient, pools of light in a few dithered steps, glowing windows. */
export function nightLight({ scene, emit, lights }, { ambient = [0.23, 0.26, 0.44] } = {}) {
  const { w, h } = scene;
  const L = new Float32Array(w * h * 3);
  for (let i = 0; i < w * h; i++) L.set(ambient, i * 3);
  for (const l of lights) {
    const r = l.r;
    for (let y = Math.floor(l.y - r); y <= l.y + r; y++) {
      if (y < 0 || y >= h) continue;
      for (let x = Math.floor(l.x - r); x <= l.x + r; x++) {
        if (x < 0 || x >= w) continue;
        const d = Math.hypot(x - l.x, (y - l.y) * 1.3);
        let f = 1 - d / r;
        if (f <= 0) continue;
        f = Math.floor(f ** 1.35 * 6 + bayer(x, y)) / 6;
        if (f <= 0) continue;
        const i = (y * w + x) * 3;
        for (let k = 0; k < 3; k++) L[i + k] += l.color[k] * f * l.power;
      }
    }
  }
  const out = scene.clone();
  for (let i = 0; i < w * h; i++) {
    for (let k = 0; k < 3; k++) out.d[i * 4 + k] = Math.min(255, out.d[i * 4 + k] * Math.min(1.5, L[i * 3 + k]));
  }
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = emit.get(x, y);
      if (p[3] > 0) out.px(x, y, p);
    }
  }
  return out;
}
