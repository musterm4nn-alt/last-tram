// Shopfronts and signs: shop windows with what is inside, glass doors, the café's
// awning, fascia signs and the church front.
import { grid, bayer } from './lib.mjs';
import { text, textWidth } from './font.mjs';
import { WASHER } from './facade-parts.mjs';

const T = 16;
const TRIM = [0, 1, 2, 3, 4].map((i) => `ss${i}`);

/** Big shop window: dark frame, glass with a reflection streak, and what's inside. */
export function shopWindow(img, cx, base, kind, seed, emit) {
  const w = 22;
  const x = cx - w / 2;
  const top = base - 46;
  const bottom = base - 12;
  const frame = kind === 'cafe' ? 'wd1' : 'mt1';
  img.rect(x - 1, top - 2, w + 2, 2, TRIM[3]);
  img.rect(x, top, w, bottom - top, frame);
  for (let y = top + 1; y < bottom - 1; y++) {
    for (let i = 1; i < w - 1; i++) {
      const d = i + (y - top) * 0.6;
      let c = y < top + 3 ? 'gl0' : 'gl1';
      if (d % 22 > 14 && d % 22 < 17) c = 'gl3';
      else if (d % 22 >= 17 && d % 22 < 18) c = 'gl4';
      else if ((y - top) % 5 === 0 && i % 7 === 3) c = 'gl2';
      img.px(x + i, y, c);
      const cool = kind === 'laundry' || kind === 'police';
      const depth = (y - top) / (bottom - top); // brighter near the ceiling lights
      const warm = depth < 0.15 ? 'lw3' : depth < 0.5 ? (bayer(i, y) < 0.5 ? 'lw3' : 'lw2') : depth < 0.85 ? 'lw2' : 'lw1';
      const cold = depth < 0.2 ? 'fl2' : 'fl1';
      emit.px(x + i, y, cool ? cold : warm);
    }
  }
  if (kind === 'laundry') {
    for (const [mx, my] of [[1, 8], [8, 8], [15, 8], [1, 15], [8, 15], [15, 15]]) {
      img.grid(WASHER, x + mx, bottom - my);
      emit.grid(WASHER, x + mx, bottom - my);
    }
    img.hline(x + 2, x + w - 3, top + 3, 'fl1');
  }
  if (kind === 'cafe') {
    // counter with a cake stand and a pendant lamp
    for (const t of [img, emit]) {
      t.hline(x + 1, x + w - 2, bottom - 7, 'wd3');
      t.rect(x + 1, bottom - 6, w - 2, 5, 'wd1');
      t.rect(x + 4, bottom - 10, 5, 2, 'cream1');
      t.px(x + 6, bottom - 11, 'red2');
      t.rect(x + 12, bottom - 10, 4, 2, 'cream1');
      t.px(x + 13, bottom - 11, 'hyellow');
      for (const lx of [x + 7, x + 16]) {
        t.vline(lx, top + 1, top + 6, 'mt0');
        t.hline(lx - 1, lx + 1, top + 7, t === img ? 'lw1' : 'white');
      }
    }
  }
  if (kind === 'spaeti' || kind === 'imbiss') {
    for (let s = 0; s < 3; s++) {
      const yy = bottom - 6 - s * 7;
      img.hline(x + 1, x + w - 2, yy, 'mt2');
      for (let i = 1; i < w - 1; i += 2) img.rect(x + i, yy - 3, 1, 3, ['red2', 'hyellow', 'teal2', 'cream1', 'hgreen'][(i + s + seed) % 5]);
    }
  }
  img.rect(x - 1, bottom, w + 2, 1, TRIM[4]);
  img.rect(x - 1, bottom + 1, w + 2, 2, TRIM[2]);
}

export function shopDoor(img, cx, base, kind, emit) {
  const w = 12;
  const x = cx - w / 2;
  const top = base - 46;
  img.rect(x - 1, top - 2, w + 2, 2, TRIM[3]);
  img.rect(x, top, w, 44, kind === 'cafe' || kind === 'bar' ? 'wd1' : 'mt1');
  for (let y = top + 1; y < base - 3; y++) {
    for (let i = 1; i < w - 1; i++) {
      const d = i + (y - top) * 0.6;
      let c = 'gl1';
      if (y < top + 3) c = 'gl0';
      if (d % 22 > 14 && d % 22 < 17) c = 'gl3';
      img.px(x + i, y, c);
      emit.px(x + i, y, kind === 'laundry' || kind === 'police' ? 'fl1' : 'lw2');
    }
  }
  img.vline(x + w - 3, base - 26, base - 16, 'mt4');
  emit.vline(x + w - 3, base - 26, base - 16, 'mt2');
  img.rect(x + 2, base - 30, 4, 3, 'hyellow');
  img.px(x + 3, base - 29, 'ink2');
  img.hline(x - 1, x + w, base - 2, TRIM[4]);
  img.hline(x - 1, x + w, base - 1, TRIM[1]);
}

export function cafeFront(img, W, base, openings, style) {
  // Striped awning over the windows and door, with a scalloped edge.
  const cols = openings.map((o) => o.col * T + T / 2);
  const x0 = Math.min(...cols) - 10;
  const x1 = Math.max(...cols) + 10;
  const top = base - 55;
  for (let y = top; y < top + 12; y++) {
    for (let x = x0; x <= x1; x++) {
      const stripe = Math.floor((x - x0) / 3) % 2 === 0;
      let c = stripe ? 'teal1' : 'cream1';
      if (y === top) c = stripe ? 'teal2' : 'white';
      if (y >= top + 9) c = stripe ? 'teal0' : 'cream0';
      img.px(x, y, c);
    }
  }
  for (let x = x0; x <= x1; x++) {
    if ((x - x0) % 3 === 1) img.px(x, top + 12, Math.floor((x - x0) / 3) % 2 === 0 ? 'teal0' : 'cream0');
    img.px(x, top + 13, 'shadow');
  }
  // A hanging sign on a bracket: a little cloud for "Wolke".
  const sx = W - 30;
  img.hline(sx, sx + 10, top - 16, 'mt0');
  img.vline(sx + 1, top - 15, top - 14, 'mt0');
  img.vline(sx + 9, top - 15, top - 14, 'mt0');
  const CLOUD = grid(
    `
    ....wwww....
    ..wwWWWWww..
    .wWWWWWWWWw.
    wWWWWWWWWWWw
    wWWWWWWWWWWs
    .sssssssss..
    `,
    { w: 'white', W: 'cream1', s: 'cream0' },
  );
  img.grid(CLOUD, sx - 1, top - 13);
  const label = style.sign;
  const lw = textWidth(label);
  const lx = Math.round((W - lw) / 2);
  img.rect(lx - 3, top - 10, lw + 6, 9, 'wd1');
  img.rect(lx - 2, top - 9, lw + 4, 7, 'wd2');
  text(img, label, lx, top - 8, 'cream1');
}

export function laundryFront(img, W, base, style, emit) {
  // A fascia board across the whole shopfront, with a lightning bolt.
  const top = base - 55;
  img.rect(6, top, W - 12, 8, 'teal0');
  img.hline(6, W - 7, top, 'teal1');
  img.hline(6, W - 7, top + 8, 'shadow');
  const label = style.sign;
  const lw = textWidth(label);
  const lx = Math.round((W - lw) / 2) + 4;
  text(img, label, lx, top + 2, 'cream1');
  text(emit, label, lx, top + 2, 'fl2');
  const BOLT = grid(
    `
    ..yy
    .yy.
    yyyy
    .yy.
    yy..
    y...
    `,
    { y: 'hyellow' },
  );
  img.grid(BOLT, lx - 7, top + 1);
  emit.grid(BOLT, lx - 7, top + 1);
}

export function fasciaSign(img, W, base, label, kind, emit) {
  const top = base - 55;
  const colours = { bar: ['red1', 'cream1'], spaeti: ['ink2', 'hyellow'], imbiss: ['red1', 'hyellow'], police: ['#2f4f8a', 'white'] };
  const [bg, fg] = colours[kind] ?? ['ink2', 'cream1'];
  const lw = textWidth(label);
  const lx = Math.round((W - lw) / 2);
  img.rect(lx - 4, top, lw + 8, 9, bg);
  img.hline(lx - 4, lx + lw + 3, top + 9, 'shadow');
  text(img, label, lx, top + 2, fg);
  if (kind === 'spaeti' || kind === 'bar') text(emit, label, lx, top + 2, fg);
}

export function churchFront(img, W, base, FH, ramps) {
  // Tall arched windows between buttresses, and a rose window over the door.
  for (let x = 24; x < W - 24; x += 32) {
    if (Math.abs(x + 4 - W / 2) < 24) continue;
    const top = base - FH + 22;
    const bottom = base - 20;
    for (let y = top; y < bottom; y++) {
      for (let i = 0; i < 8; i++) {
        const arch = y - top < 4 && Math.abs(i - 3.5) > 1 + (y - top);
        if (arch) continue;
        img.px(x + i, y, i === 0 || i === 7 ? 'ss1' : (y + i) % 7 === 0 ? 'gl3' : 'gl1');
      }
    }
  }
  const cx = W / 2;
  const cy = base - FH + 40;
  for (let y = -8; y <= 8; y++) {
    for (let x = -8; x <= 8; x++) {
      const d = Math.hypot(x, y);
      if (d > 8.5) continue;
      img.px(cx + x, cy + y, d > 7 ? 'ss1' : (Math.round(Math.atan2(y, x) * 4) + 8) % 2 ? 'gl2' : 'red1');
    }
  }
}
