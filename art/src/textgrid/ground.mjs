// Ground tiles (16 × 16). Surfaces are generated from a few rules so each terrain gets
// several seamless variants; small details (manholes, drains, litter) are text grids.
import { Img, grid, rng, mix } from './lib.mjs';

export const T = 16;

// ---------------------------------------------------------------- stones

/** One cobblestone: a light top edge, a dark bottom edge, rounded corners. */
function stone(img, x, y, w, h, base, r) {
  const light = mix(base, '#e8dcc4', 0.14);
  const dark = mix(base, '#1b1830', 0.2);
  for (let j = 0; j < h; j++) {
    for (let i = 0; i < w; i++) {
      const corner = (i === 0 || i === w - 1) && (j === 0 || j === h - 1);
      if (corner && w > 2 && h > 2) continue;
      let c = base;
      if (j === 0 || (i === 0 && j < h - 1)) c = light;
      if (j === h - 1 || (i === w - 1 && j > 0)) c = dark;
      if (r() < 0.03) c = mix(c, '#1b1830', 0.1);
      img.px(x + i, y + j, c);
    }
  }
}

function stoneTone(r) {
  const v = r();
  if (v < 0.5) return 'cob2';
  if (v < 0.78) return mix('cob2', 'cob3', 0.6);
  if (v < 0.86) return mix('cob2', 'cobR', 0.6);
  if (v < 0.94) return mix('cob2', 'cobB', 0.6);
  return mix('cob2', 'cob1', 0.6);
}

/** Rows of granite setts, wrapping at the tile edges so tiles join seamlessly. */
export function cobbles(seed, { rowH = 5, minW = 5, maxW = 6, x0 = 0, y0 = 0, w = T, h = T, img } = {}) {
  const out = img ?? new Img(T, T, 'cobJ');
  if (img) out.rect(x0, y0, w, h, 'cobJ');
  const r = rng(seed);
  for (let row = 0; row * rowH < h; row++) {
    const widths = [];
    let sum = 0;
    while (sum < w) {
      let sw = minW + Math.floor(r() * (maxW - minW + 1));
      if (w - sum - sw > 0 && w - sum - sw < minW) sw = w - sum; // no slivers at the end
      if (sum + sw > w) sw = w - sum;
      widths.push(sw);
      sum += sw;
    }
    let x = Math.floor(r() * w);
    for (const sw of widths) {
      const tile = new Img(sw, rowH - 1);
      stone(tile, 0, 0, sw - 1, rowH - 1, stoneTone(r), r);
      for (let i = 0; i < sw - 1; i++) {
        for (let j = 0; j < rowH - 1; j++) {
          const p = tile.get(i, j);
          if (p[3] > 0) out.px(x0 + ((x + i) % w), y0 + row * rowH + j, p);
        }
      }
      x += sw;
    }
  }
  return out;
}

/** Segmental-arc paving (Bogenpflaster), the pattern of old German squares. */
export function arcCobbles(seed) {
  const out = new Img(T, T, 'cobJ');
  const r = rng(seed);
  const rowH = 4;
  const tones = [];
  for (let k = 0; k < 64; k++) tones.push(stoneTone(r));
  for (let y = 0; y < T; y++) {
    for (let x = 0; x < T; x++) {
      const u = (x + 0.5 - T / 2) / (T / 2);
      const lift = Math.round(3 * (1 - u * u));
      const v = (y + lift) % T;
      const row = Math.floor(v / rowH);
      const inRow = v % rowH;
      if (inRow === rowH - 1) continue; // joint between arcs
      // joints across the arc lean outwards, like the real thing
      const along = x + row * 2;
      const seg = Math.floor((along + 16) / 4);
      if ((along + 16) % 4 === 3) continue;
      const base = tones[(row * 7 + seg) % tones.length];
      let c = base;
      if (inRow === 0) c = mix(base, '#e8dcc4', 0.13);
      if (inRow === rowH - 2) c = mix(base, '#1b1830', 0.18);
      if (r() < 0.03) c = mix(c, '#1b1830', 0.1);
      out.px(x, y, c);
    }
  }
  return out;
}

/** A flush band of granite slabs, the kind that divides a square into fields. */
export function band(img, x, y, w, h, seed) {
  const r = rng(seed);
  img.rect(x, y, w, h, 'curb2');
  const vertical = h > w;
  const len = vertical ? h : w;
  let p = Math.floor(r() * 6);
  while (p < len) {
    if (vertical) img.hline(x, x + w - 1, y + p, 'curb1');
    else img.vline(x + p, y, y + h - 1, 'curb1');
    p += 5 + Math.floor(r() * 5);
  }
  for (let k = 0; k < len / 3; k++) {
    const i = Math.floor(r() * w);
    const j = Math.floor(r() * h);
    img.px(x + i, y + j, r() < 0.5 ? 'curb3' : mix('curb2', 'curb1', 0.5));
  }
  if (vertical) img.vline(x + w, y, y + h - 1, 'cobJ');
  else img.hline(x, x + w - 1, y + h, 'cobJ');
}

// ---------------------------------------------------------------- surfaces

export function asphalt(seed) {
  const out = new Img(T, T, 'asph2');
  const r = rng(seed);
  for (let y = 0; y < T; y++) {
    for (let x = 0; x < T; x++) {
      const v = r();
      if (v < 0.015) out.px(x, y, 'asph0');
      else if (v < 0.07) out.px(x, y, 'asph1');
      else if (v < 0.13) out.px(x, y, 'asph3');
      else if (v < 0.14) out.px(x, y, 'asph4');
    }
  }
  return out;
}

export function slabs(seed) {
  const out = new Img(T, T);
  const r = rng(seed);
  for (let sy = 0; sy < 2; sy++) {
    for (let sx = 0; sx < 2; sx++) {
      const v = r();
      const base = v < 0.5 ? 'slab2' : v < 0.8 ? 'slab3' : v < 0.93 ? 'slab1' : 'slab4';
      for (let j = 0; j < 8; j++) {
        for (let i = 0; i < 8; i++) {
          let c = base;
          if (i === 7 || j === 7) c = 'slab0';
          else if (j === 0 || i === 0) c = mix(base, '#e8e2d4', 0.12);
          else if (r() < 0.1) c = mix(base, '#1b1830', 0.1);
          else if (r() < 0.04) c = mix(base, '#e8e2d4', 0.1);
          out.px(sx * 8 + i, sy * 8 + j, c);
        }
      }
    }
  }
  return out;
}

export function grass(seed) {
  const out = new Img(T, T, 'gr2');
  const r = rng(seed);
  for (let k = 0; k < 26; k++) {
    const x = Math.floor(r() * T);
    const y = Math.floor(r() * T);
    const v = r();
    if (v < 0.35) {
      out.px(x, y, 'gr3');
      out.px(x, y - 1, 'gr4');
    } else if (v < 0.7) {
      out.px(x, y, 'gr1');
    } else if (v < 0.85) {
      out.px(x, y, 'gr3');
      out.px(x + 1, y - 1, 'gr4');
      out.px(x - 1, y - 1, 'gr3');
    } else if (v < 0.97) {
      out.px(x, y, 'gr4');
      out.px(x, y - 1, 'gr5');
    } else {
      out.px(x, y, 'cream1');
    }
  }
  return out;
}

export function water(seed) {
  const out = new Img(T, T, 'wat1');
  const r = rng(seed);
  for (let k = 0; k < 6; k++) {
    const x = Math.floor(r() * T);
    const y = Math.floor(r() * T);
    const len = 2 + Math.floor(r() * 4);
    for (let i = 0; i < len; i++) out.px((x + i) % T, y, i === 0 || i === len - 1 ? 'wat2' : 'wat3');
  }
  for (let k = 0; k < 5; k++) out.px(Math.floor(r() * T), Math.floor(r() * T), 'wat0');
  return out;
}

// ---------------------------------------------------------------- tram tracks

/** Two grooved rails with a strip of setts between them. */
export function track(seed) {
  const out = asphalt(seed);
  cobbles(seed + 7, { img: out, x0: 0, y0: 5, w: T, h: 6, rowH: 3, minW: 3, maxW: 5 });
  railRow(out, 2, false);
  railRow(out, 11, true);
  return out;
}

/** A grooved rail seen from above: outer edge, polished head, then the groove. */
export function railRow(img, y, grooveAbove) {
  const rows = grooveAbove ? ['rail0', 'rail2', 'rail1'] : ['rail1', 'rail2', 'rail0'];
  rows.forEach((c, j) => img.hline(0, T - 1, y + j, c));
  for (let x = 0; x < T; x += 5) img.px(x, grooveAbove ? y + 1 : y + 1, 'rail3');
}

// ---------------------------------------------------------------- details

export const MANHOLE = grid(
  `
  ...iiiiii...
  ..iMmmmmMi..
  .iMmMmMmmMi.
  iMmMmmmmMmMi
  iMmmMmMmmmMi
  iMmMmmmmMmMi
  iMmmMmMmmmMi
  iMmMmmmmMmMi
  .iMmmMmMmMi.
  ..iMmmmmMi..
  ...iiiiii...
  `,
  { i: 'asph0', M: 'mt1', m: 'mt2' },
);

export const DRAIN = grid(
  `
  iiiiiiiiii
  iMmMmMmMmi
  iMmMmMmMmi
  iiiiiiiiii
  `,
  { i: 'rail0', M: 'mt0', m: 'mt2' },
);

export const BUTT = grid(`ow`, { o: '#b87a3c', w: '#e6e2d6' });
export const GUM = grid(`g`, { g: '#4a4a4c' });
export const CAP = grid(`c`, { c: '#b8b04a' });
