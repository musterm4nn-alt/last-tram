// Buildings in top-down 3/4 view: the south facade faces the camera and the pitched roof
// covers the footprint. Windows, doors and dormers are text grids; walls, roof tiles and
// signs are assembled around them from the openings in the district map.
import { Img, rng, mix, hash2 } from './lib.mjs';
import { WINDOW, WINDOW_CURTAINS, litGrid, DOOR, SAT_DISH, TAGS } from './facade-parts.mjs';
import { shopWindow, shopDoor, cafeFront, laundryFront, fasciaSign, churchFront } from './shopfronts.mjs';
import { roof, ROOFS } from './roofs.mjs';

const T = 16;
const ramp = (p) => [0, 1, 2, 3, 4].map((i) => `${p}${i}`);

export const WALLS = { och: ramp('och'), sag: ramp('sag'), sal: ramp('sal'), pbl: ramp('pbl'), ss: ramp('ss') };
const TRIM = ramp('ss');

/** How each building looks, by place id from district.json (view-only data). */
export const STYLES = {
  church_st_nikolai: { wall: 'ss', roof: 'copper', storeys: 3, kind: 'church' },
  cafe_wolke: { wall: 'och', roof: 'tile', storeys: 2, kind: 'cafe', sign: 'CAFE WOLKE' },
  waschsalon_blitz: { wall: 'sag', roof: 'slate', storeys: 3, kind: 'laundry', sign: 'WASCHSALON' },
  kneipe_anker: { wall: 'sal', roof: 'tile', storeys: 2, kind: 'bar', sign: 'ZUM ANKER' },
  haus_3: { wall: 'pbl', roof: 'slate', storeys: 3, kind: 'home' },
  spaeti_kaya: { wall: 'pbl', roof: 'slate', storeys: 3, kind: 'spaeti', sign: 'SPATI KAYA' },
  imbiss_anadolu: { wall: 'och', roof: 'tile', storeys: 2, kind: 'imbiss', sign: 'IMBISS' },
  home_player: { wall: 'sal', roof: 'tile', storeys: 3, kind: 'home' },
  polizeiposten: { wall: 'pbl', roof: 'slate', storeys: 2, kind: 'police', sign: 'POLIZEI' },
};

// Facade heights in pixels (16 px ≈ 1 m, compressed a little so streets stay readable).
const PLINTH = 8;
const GROUND = 56; // plinth included
const BELT = 5;
const STOREY = 40;
const CORNICE = 8;
export const facadeHeight = (storeys) => GROUND + BELT + STOREY * (storeys - 1) + CORNICE;

// ---------------------------------------------------------------- assembly

/**
 * Renders one building from its footprint in the district map.
 * Returns an image whose bottom edge sits on the facade's ground line.
 */
export function building(world, place) {
  const style = STYLES[place.id] ?? { wall: 'pbl', roof: 'slate', storeys: 2, kind: 'home' };
  const [x0, y0, w, h] = place.rect;
  const W = w * T;
  const D = h * T;
  const FH = facadeHeight(style.storeys);
  const img = new Img(W, D + FH);
  const emit = new Img(W, D + FH);
  const lights = [];
  const ramps = { wall: WALLS[style.wall], trim: TRIM, roof: ROOFS[style.roof].ramp };
  const seed = x0 * 97 + y0 * 13;
  const southRow = y0 + h - 1;
  const openings = [];
  for (let x = x0; x < x0 + w; x++) {
    const t = world.at(x, southRow);
    if (t === 'window' || t === 'door') openings.push({ col: x - x0, kind: t });
  }
  roof(img, W, D, style, ramps, seed, openings);
  facade(img, D, W, FH, style, ramps, seed, openings, emit, lights);
  return { img, emit, lights, x: x0 * T, baseY: (y0 + h) * T, style, openings, FH, D };
}

function facade(img, top, W, FH, style, ramps, seed, openings, emit, lights) {
  const r = rng(seed);
  const wall = ramps.wall;
  const base = top + FH; // ground line inside the image
  const up = (v) => base - v; // image y for a height above the ground
  // Stucco with a faint texture; the ground floor gets horizontal rustication.
  for (let y = top; y < base; y++) {
    for (let x = 0; x < W; x++) {
      let c = wall[2];
      const v = r();
      if (v < 0.018) c = wall[1];
      else if (v < 0.04) c = wall[3];
      img.px(x, y, c);
    }
  }
  for (let v = PLINTH + 5; v < GROUND; v += 6) img.hline(0, W - 1, up(v), mix(wall[1], wall[2], 0.5));
  // Dirt creeps up from the pavement.
  for (let x = 0; x < W; x++) {
    const hgt = 3 + Math.floor(hash2(x, seed, 3) * 3);
    for (let v = PLINTH; v < PLINTH + hgt; v++) if (hash2(x, v, seed) < 0.55) img.px(x, up(v), mix(wall[1], '#3b3530', 0.35));
  }
  // Plinth of sandstone blocks.
  for (let v = 0; v < PLINTH; v++) img.hline(0, W - 1, up(v), v === PLINTH - 1 ? TRIM[3] : v === PLINTH - 2 ? TRIM[2] : TRIM[1]);
  for (let x = 3; x < W; x += 9) img.vline(x, up(PLINTH - 2), up(1), TRIM[0]);
  img.hline(0, W - 1, up(0), TRIM[0]);
  // Belt course between the ground floor and the first floor.
  const belt = GROUND;
  img.hline(0, W - 1, up(belt + BELT - 1), TRIM[4]);
  for (let v = belt + 1; v < belt + BELT - 1; v++) img.hline(0, W - 1, up(v), TRIM[2]);
  img.hline(0, W - 1, up(belt), TRIM[1]);
  img.hline(0, W - 1, up(belt - 1), wall[1]);
  // Cornice under the eaves: steps, dentils, then the gutter's shadow.
  const c0 = FH - CORNICE;
  img.hline(0, W - 1, up(c0), wall[1]);
  img.hline(0, W - 1, up(c0 + 1), TRIM[1]);
  img.hline(0, W - 1, up(c0 + 2), TRIM[3]);
  for (let x = 0; x < W; x++) {
    img.px(x, up(c0 + 3), x % 3 === 0 ? TRIM[1] : TRIM[2]);
    img.px(x, up(c0 + 4), x % 3 === 0 ? TRIM[1] : TRIM[2]);
  }
  img.hline(0, W - 1, up(c0 + 5), TRIM[3]);
  img.hline(0, W - 1, up(c0 + 6), TRIM[4]);
  img.hline(0, W - 1, up(c0 + 7), 'ink2');
  // Corner pilasters with quoins.
  for (const side of [0, 1]) {
    const x = side === 0 ? 0 : W - 6;
    for (let v = PLINTH; v < c0; v++) {
      const band = Math.floor((v - PLINTH) / 6);
      const wide = band % 2 === 0;
      const joint = (v - PLINTH) % 6 === 5;
      for (let i = 0; i < 6; i++) {
        const inside = side === 0 ? i < (wide ? 6 : 4) : i >= (wide ? 0 : 2);
        if (!inside) continue;
        let c = joint ? TRIM[1] : TRIM[2];
        if (!joint && (side === 0 ? i === 0 : i === 5)) c = side === 0 ? TRIM[3] : TRIM[1];
        img.px(x + i, up(v), c);
      }
    }
  }

  const kind = style.kind;
  const shop = ['cafe', 'laundry', 'bar', 'spaeti', 'imbiss', 'police'].includes(kind);
  // Upper floors: a window above every opening of the ground floor.
  for (let s = 1; s < style.storeys; s++) {
    const floor = GROUND + BELT + (s - 1) * STOREY;
    for (const o of openings) {
      const cx = o.col * T + T / 2;
      const variant = hash2(o.col, s, seed);
      const g = variant < 0.35 ? WINDOW_CURTAINS : WINDOW;
      const wy = up(floor + 36);
      img.grid(g, cx - 7, wy, { ramps });
      if (hash2(o.col, s, seed + 99) < 0.45) emit.grid(litGrid(g), cx - 7, wy, { ramps, only: 'oabceKk' });
      if (variant > 0.85) flowerBox(img, cx - 6, wy + 22, seed + s);
      if (variant > 0.6 && variant < 0.66) img.grid(SAT_DISH, cx + 7, wy + 4);
    }
  }
  // Ground floor.
  for (const o of openings) {
    const cx = o.col * T + T / 2;
    if (o.kind === 'door') {
      if (shop) shopDoor(img, cx, base, kind, emit);
      else {
        img.grid(DOOR, cx - 7, base - DOOR.h + 1, { ramps });
        houseNumber(img, cx + 8, up(34));
      }
    } else if (shop) {
      shopWindow(img, cx, base, kind, seed + o.col, emit);
      const cool = kind === 'laundry' || kind === 'police';
      lights.push({ x: cx, y: base - 14, r: 44, color: cool ? [0.75, 0.95, 0.9] : [1.0, 0.75, 0.42], power: 0.8 });
    } else {
      const g = o.col % 2 ? WINDOW_CURTAINS : WINDOW;
      img.grid(g, cx - 7, up(50), { ramps });
      if (hash2(o.col, 0, seed + 7) < 0.5) emit.grid(litGrid(g), cx - 7, up(50), { ramps, only: 'oabceKk' });
    }
  }
  if (kind === 'cafe') cafeFront(img, W, base, openings, style);
  if (kind === 'laundry') laundryFront(img, W, base, style, emit);
  if (style.sign && kind !== 'cafe' && kind !== 'laundry') fasciaSign(img, W, base, style.sign, kind, emit);
  if (kind === 'church') churchFront(img, W, base, FH, ramps);
  // Grit: tags on the lower wall of shops.
  if (shop || kind === 'home') {
    const rr = rng(seed + 5);
    for (let k = 0; k < 2; k++) {
      const x = 8 + Math.floor(rr() * (W - 24));
      const clear = openings.every((o) => Math.abs(o.col * T + T / 2 - (x + 4)) > 12);
      if (clear) img.grid(TAGS[Math.floor(rr() * TAGS.length)], x, up(PLINTH + 10 + Math.floor(rr() * 6)));
    }
  }
  // A downpipe at each end of the facade.
  downpipe(img, W - 3, up(FH - CORNICE + 6), base);
}

function downpipe(img, x, y0, y1) {
  for (let y = y0; y <= y1 - 2; y++) {
    img.px(x, y, 'mt3');
    img.px(x + 1, y, 'mt1');
  }
  for (let y = y0 + 12; y < y1 - 4; y += 16) img.hline(x - 1, x + 2, y, 'mt0');
  img.hline(x - 1, x + 2, y1 - 1, 'mt2');
}

function flowerBox(img, x, y, seed) {
  const r = rng(seed);
  img.hline(x + 1, x + 10, y + 1, 'wd2');
  img.hline(x + 1, x + 10, y + 2, 'wd1');
  for (let i = 1; i < 11; i++) {
    img.px(x + i, y, r() < 0.6 ? 'lf3' : 'lf2');
    if (r() < 0.35) img.px(x + i, y - 1, r() < 0.5 ? 'red3' : 'pinkG');
  }
}

function houseNumber(img, x, y) {
  img.rect(x, y, 5, 4, '#2f4f8a');
  img.px(x + 2, y + 1, 'white');
  img.px(x + 2, y + 2, 'white');
}
