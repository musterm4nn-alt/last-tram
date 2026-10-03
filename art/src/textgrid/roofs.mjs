// Pitched roofs seen from the south: beaver-tail tiles, slate or copper, with dormers,
// chimneys and a gutter along the eaves.
import { rng, hash2 } from './lib.mjs';
import { DORMER, CHIMNEY } from './facade-parts.mjs';

const T = 16;
const ramp = (p) => [0, 1, 2, 3, 4].map((i) => `${p}${i}`);

export const ROOFS = {
  tile: { ramp: ramp('ter'), rise: 44 },
  slate: { ramp: ramp('sl'), rise: 38 },
  copper: { ramp: ramp('cu'), rise: 54 },
};

export function roof(img, W, D, style, ramps, seed, openings) {
  const kind = style.roof;
  const R = Math.min(ROOFS[kind].rise, D / 2 - 6);
  const rr = ramps.roof;
  const ridge = D / 2 - R; // image y of the ridge
  const r = rng(seed + 1);
  // South slope, facing the camera and the sun.
  for (let y = ridge; y < D; y++) {
    for (let x = 0; x < W; x++) img.px(x, y, roofPixel(kind, x, y - ridge, rr, seed, false));
  }
  // North slope: seen steeply from above and in shade.
  for (let y = 0; y < ridge; y++) {
    for (let x = 0; x < W; x++) img.px(x, y, roofPixel(kind, x, y, rr, seed, true));
  }
  // Moss and patched tiles on old roofs.
  if (kind !== 'copper') {
    for (let k = 0; k < W / 6; k++) {
      const x = Math.floor(r() * W);
      const y = ridge + 8 + Math.floor(r() * (D - ridge - 10));
      img.px(x, y, 'moss');
      if (r() < 0.5) img.px(x + 1, y, 'moss');
    }
  }
  // Ridge cap and the verges at both ends.
  img.hline(0, W - 1, ridge - 1, rr[1]);
  img.hline(0, W - 1, ridge, rr[3]);
  img.hline(0, W - 1, ridge + 1, rr[2]);
  img.hline(0, W - 1, ridge + 2, rr[0]);
  for (let x = 0; x < W; x += 4) img.px(x, ridge, rr[1]);
  img.vline(0, 0, D - 1, rr[3]);
  img.vline(1, 0, D - 1, rr[1]);
  img.vline(W - 1, 0, D - 1, rr[0]);
  img.hline(0, W - 1, 0, rr[0]);
  // Gutter along the eaves.
  img.hline(0, W - 1, D - 2, 'mt3');
  img.hline(0, W - 1, D - 1, 'mt1');
  // Dormers over some of the windows, chimneys on the ridge.
  if (kind !== 'copper') {
    const eligible = openings.filter((o, i) => i % 2 === 0);
    for (const o of eligible) {
      const cx = o.col * T + T / 2;
      img.grid(DORMER, cx - 8, D - DORMER.h - 12, { ramps });
    }
    const chimneys = Math.max(1, Math.round(W / 96));
    for (let k = 0; k < chimneys; k++) {
      const x = Math.round(((k + 0.5) * W) / chimneys + (r() - 0.5) * 20);
      img.grid(CHIMNEY, x - 4, ridge - 8, { ramps });
    }
  } else {
    // A small copper ridge turret for the church.
    const cx = W / 2;
    for (let y = ridge - 30; y < ridge + 6; y++) {
      const half = y < ridge - 20 ? Math.max(0, Math.floor((y - (ridge - 30)) / 3)) : 4;
      for (let x = -half; x <= half; x++) img.px(cx + x, y, x < 0 ? 'cu3' : x === 0 ? 'cu2' : 'cu1');
    }
    img.vline(cx, ridge - 36, ridge - 31, 'hyellow');
    img.hline(cx - 1, cx + 1, ridge - 34, 'hyellow');
  }
}

function roofPixel(kind, x, y, rr, seed, north) {
  const dark = north ? 1 : 0;
  const pick = (i) => rr[Math.max(0, Math.min(4, i - dark))];
  if (kind === 'tile') {
    // Beaver-tail tiles: rows of rounded tongues, offset by half a tile each row.
    const rowH = north ? 2 : 3;
    const row = Math.floor(y / rowH);
    const j = y % rowH;
    const i = (x + (row % 2) * 2) % 4;
    const tile = Math.floor((x + (row % 2) * 2) / 4);
    const tone = hash2(tile, row, seed);
    const shift = tone < 0.12 ? -1 : tone > 0.9 ? 1 : 0;
    if (j === rowH - 1 && (i === 0 || i === 3)) return pick(1 + shift);
    if (i === 0) return pick(2 + shift);
    if (j === 0) return pick(3 + shift);
    return pick(2 + shift);
  }
  if (kind === 'slate') {
    const rowH = north ? 2 : 3;
    const row = Math.floor(y / rowH);
    const j = y % rowH;
    const i = (x + (row % 2) * 3) % 6;
    const tone = hash2(Math.floor((x + (row % 2) * 3) / 6), row, seed);
    const shift = tone < 0.15 ? -1 : tone > 0.88 ? 1 : 0;
    if (j === rowH - 1) return pick(1);
    if (i === 0) return pick(1 + shift);
    if (j === 0) return pick(3 + shift);
    return pick(2 + shift);
  }
  // copper: standing seams and streaks of verdigris
  const i = x % 5;
  const streak = hash2(x, Math.floor(y / 9), seed) < 0.15 ? 1 : 0;
  if (i === 0) return pick(3);
  if (i === 1) return pick(1);
  if (y % 14 === 0) return pick(1);
  return pick(2 + streak);
}
