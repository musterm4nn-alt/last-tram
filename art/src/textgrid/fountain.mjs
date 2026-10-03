// The Altmarkt fountain: a stone basin with two bowls, lit from under the water at night.
import { Img, hash2 } from './lib.mjs';

/** A tiered market fountain: stone basin, a stem with two bowls, water spilling down. */
export function fountain() {
  const w = 36;
  const h = 70;
  const img = new Img(w, h);
  const cx = 17.5;
  const rimH = 8;
  const base = h - 1;
  const top = base - 26; // centre of the basin's top face
  const rx = 17;
  const ry = 11;
  const ell = (x, y, ex, ey, cy) => ((x - cx) / ex) ** 2 + ((y - cy) / ey) ** 2;
  // Front face of the basin wall, lit from the left.
  for (let x = 0; x < w; x++) {
    for (let y = top; y <= base; y++) {
      const inTopFace = ell(x, y, rx, ry, top) <= 1;
      const inBottom = ell(x, y, rx, ry, top + rimH) <= 1;
      if (!inTopFace && inBottom) {
        const u = (x - cx) / rx;
        let c = u < -0.55 ? 'ss3' : u < 0.3 ? 'ss2' : 'ss1';
        if ((y - top) % 4 === 3) c = u < 0 ? 'ss2' : 'ss0';
        if (ell(x, y + 1, rx, ry, top + rimH) > 1) c = 'ss0';
        img.px(x, y, c);
      }
    }
  }
  // Top face: a wide stone rim around the water.
  for (let x = 0; x < w; x++) {
    for (let y = 0; y <= base; y++) {
      const e = ell(x, y, rx, ry, top);
      if (e > 1) continue;
      if (ell(x, y, rx - 3, ry - 2.5, top) <= 1) {
        const ring = Math.floor(Math.sqrt(ell(x, y, rx, ry, top + 1)) * 7);
        let c = ring % 2 ? 'wat2' : 'wat1';
        if (ell(x, y - 1, rx - 3, ry - 2.5, top) > 1) c = 'wat0';
        if (hash2(x, y, 11) < 0.05) c = 'wat4';
        img.px(x, y, c);
      } else {
        img.px(x, y, y < top ? 'ss3' : e > 0.8 ? 'ss4' : 'ss3');
      }
    }
  }
  // Stem, a lower bowl, a smaller upper bowl and a stone ball on top.
  const stem = (y0, y1, half) => {
    for (let y = y0; y <= y1; y++) {
      for (let x = -half; x <= half; x++) img.px(Math.round(cx + x), y, x < -half / 2 ? 'ss3' : x <= half / 3 ? 'ss2' : 'ss1');
    }
  };
  const bowl = (cy, bx, by, depth) => {
    for (let y = cy - by; y <= cy + by + depth; y++) {
      for (let x = -bx; x <= bx; x++) {
        const onTop = (x / bx) ** 2 + ((y - cy) / by) ** 2 <= 1;
        const below = y > cy && (x / bx) ** 2 + ((y - cy) / (by + depth)) ** 2 <= 1;
        if (onTop) img.px(Math.round(cx + x), y, (x / bx) ** 2 + ((y - cy) / by) ** 2 > 0.55 ? 'ss4' : 'wat3');
        else if (below) img.px(Math.round(cx + x), y, x < -bx / 3 ? 'ss3' : x < bx / 3 ? 'ss2' : 'ss1');
      }
    }
  };
  stem(top - 22, top + 1, 2);
  bowl(top - 20, 9, 3, 4);
  stem(top - 34, top - 22, 1);
  bowl(top - 33, 5, 2, 3);
  for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++) if (x * x + y * y <= 5) img.px(Math.round(cx + x), top - 40 + y, x + y < 0 ? 'ss4' : 'ss2');
  // Water falling from both bowls, and splashes where it lands.
  const fall = (x, y0, y1) => {
    for (let y = y0; y <= y1; y++) if (hash2(x, y, 5) < 0.8) img.px(x, y, y % 3 === 0 ? 'wat4' : 'wat3');
  };
  fall(Math.round(cx - 10), top - 18, top + 2);
  fall(Math.round(cx + 10), top - 18, top + 2);
  fall(Math.round(cx - 6), top - 31, top - 23);
  fall(Math.round(cx + 6), top - 31, top - 23);
  for (const sx of [-10, 10]) {
    img.px(Math.round(cx + sx - 1), top + 2, 'wat4');
    img.px(Math.round(cx + sx + 1), top + 3, 'wat4');
    img.px(Math.round(cx + sx), top + 4, 'wat3');
  }
  // At night the basin is lit from under the water.
  const emit = new Img(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = img.get(x, y);
      if (p[3] === 0) continue;
      const blueish = p[2] > p[0] + 25 && p[2] > 90;
      if (blueish) emit.px(x, y, [Math.min(255, p[0] * 0.8 + 20), Math.min(255, p[1] * 1.05 + 25), Math.min(255, p[2] * 1.1 + 25), 255]);
    }
  }
  return { img, emit, lights: [{ x: cx, y: top, r: 30, color: [0.45, 0.8, 0.9], power: 0.8 }] };
}
