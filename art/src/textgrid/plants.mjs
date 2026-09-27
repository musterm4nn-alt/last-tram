// Plants: linden trees and clipped hedges.
import { Img, rng, bayer, hash2 } from './lib.mjs';

// ---------------------------------------------------------------- trees

/** A linden: a trunk that forks into branches, under a clumpy canopy lit from the upper left. */
export function tree(seed) {
  const w = 76;
  const h = 92;
  const img = new Img(w, h);
  const r = rng(seed);
  const cx = w / 2;
  const line = (x0, y0, x1, y1, width) => {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1);
    for (let i = 0; i <= n; i++) {
      const x = x0 + ((x1 - x0) * i) / n;
      const y = y0 + ((y1 - y0) * i) / n;
      const wd = width + (1 - i / n) * 0.8;
      for (let k = -Math.floor(wd / 2); k < Math.ceil(wd / 2); k++) {
        const c = k < -wd / 2 + 1 ? 'bark2' : k >= Math.ceil(wd / 2) - 1 ? 'bark0' : 'bark1';
        img.px(Math.round(x + k), Math.round(y), c);
      }
    }
  };
  // Trunk with a flared foot, then three main branches.
  const foot = h - 1;
  const fork = h - 30;
  line(cx, foot, cx, fork, 6);
  img.hline(cx - 4, cx + 3, foot, 'bark0');
  img.px(cx - 4, foot - 1, 'bark2');
  img.px(cx + 3, foot - 1, 'bark0');
  const branches = [
    [cx - 16, fork - 22],
    [cx + 3, fork - 30],
    [cx + 18, fork - 18],
  ];
  for (const [bx, by] of branches) line(cx, fork, bx, by, 3);
  // Canopy clumps, back to front.
  const clumps = [{ x: cx, y: 36, r: 20 }];
  for (let k = 0; k < 22; k++) {
    const a = r() * Math.PI * 2;
    const d = Math.sqrt(r());
    clumps.push({ x: cx + Math.cos(a) * d * 26, y: 34 + Math.sin(a) * d * 20, r: 7 + r() * 6 });
  }
  clumps.sort((p, q) => p.y - q.y);
  const L = [-0.5, -0.75, 0.45];
  const greens = ['lf0', 'lf1', 'lf2', 'lf3', 'lf4', 'lf5'];
  const canopy = new Img(w, h);
  for (let y = 0; y < h - 20; y++) {
    for (let x = 0; x < w; x++) {
      let top = null;
      for (const p of clumps) if (Math.hypot(x - p.x, y - p.y) < p.r) top = p;
      if (!top) continue;
      const dx = (x - top.x) / top.r;
      const dy = (y - top.y) / top.r;
      const dz = Math.sqrt(Math.max(0, 1 - dx * dx - dy * dy));
      let v = dx * L[0] + dy * L[1] + dz * L[2];
      v = 0.52 + v * 0.5 - ((y - 14) / 60) * 0.3; // the underside of the crown is in shade
      v += (hash2(Math.floor(x / 2), Math.floor(y / 2), seed) - 0.5) * 0.3; // leaf clusters
      const rim = Math.hypot(x - top.x, y - top.y) > top.r - 1.2;
      let i = Math.floor(v * 5 + bayer(x, y) - 0.25);
      if (rim && dy > 0.1) i = Math.min(i, 1);
      if (rim && dy < -0.3 && hash2(x, y, seed + 1) < 0.35) continue; // ragged upper edge
      canopy.px(x, y, greens[Math.max(0, Math.min(5, i))]);
    }
  }
  img.blit(canopy, 0, 0);
  // Branches show through the darkest gaps low in the crown.
  for (const [bx, by] of branches) {
    const n = 12;
    for (let i = 0; i < n; i++) {
      const x = Math.round(cx + ((bx - cx) * i) / n);
      const y = Math.round(fork + ((by - fork) * i) / n);
      const p = canopy.get(x, y);
      const dark = p[3] > 0 && p[1] < 75;
      if (dark || p[3] === 0) img.px(x, y, i < 4 ? 'bark1' : 'bark0');
    }
  }
  return { img };
}

// ---------------------------------------------------------------- hedges

/** One cell of clipped hedge: its leafy top and, when nothing is in front, its face. */
export function hedge(x, y, front) {
  const H = 12;
  const img = new Img(T16, T16 + (front ? H : 0));
  for (let j = 0; j < T16; j++) {
    for (let i = 0; i < T16; i++) {
      const v = hash2(x * T16 + i, y * T16 + j, 41);
      const c = v < 0.2 ? 'lf4' : v < 0.55 ? 'lf3' : v < 0.9 ? 'lf2' : 'lf1';
      img.px(i, j, c);
    }
  }
  if (front) {
    for (let j = 0; j < H; j++) {
      for (let i = 0; i < T16; i++) {
        const v = hash2(x * T16 + i, j, 43);
        const c = j === 0 ? 'lf3' : j > H - 3 ? 'lf0' : v < 0.25 ? 'lf2' : 'lf1';
        img.px(i, T16 + j, c);
      }
    }
  }
  return { img };
}
const T16 = 16;
