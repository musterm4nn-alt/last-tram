// Street furniture and plants. Each prop returns its day image, what glows at night
// (`emit`) and its light sources, with the image's bottom edge on the ground.
import { Img, grid, rng, mix } from './lib.mjs';
import { text, textWidth } from './font.mjs';

export { tree, hedge } from './plants.mjs';
export { fountain } from './fountain.mjs';

const lit = (g, legend, only) => ({ g: { ...g, legend: { ...g.legend, ...legend } }, only });

// ---------------------------------------------------------------- lantern

const LAMP = grid(
  `
  ....a....
  ...aac...
  ..abbbc..
  .abbbbbc.
  ddddddddd
  .dGGGGGd.
  .dGLLLGd.
  .dGLWLGd.
  .dGLLLGd.
  .dGGGGGd.
  ..ddddd..
  ...dbd...
  ..abbbc..
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...ayc...
  ...abc...
  ...apc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ..abbbc..
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ...abc...
  ..abbbc..
  ..abbbc..
  .abbbbbc.
  .ddddddd.
  `,
  { a: 'dg3', b: 'dg2', c: 'dg1', d: 'dg0', G: '#b9b9a4', L: 'cream0', W: 'cream1', y: 'hyellow', p: 'pinkG' },
);
const LAMP_LIT = lit(LAMP, { G: 'sod2', L: 'sod3', W: 'sod4' }, ['G', 'L', 'W']);

export function lamp() {
  const img = new Img(LAMP.w, LAMP.h);
  img.grid(LAMP, 0, 0);
  const emit = new Img(LAMP.w, LAMP.h);
  emit.grid(LAMP_LIT.g, 0, 0, { only: LAMP_LIT.only });
  return { img, emit, lights: [{ x: 4, y: 7, r: 70, color: [1.0, 0.62, 0.28], power: 1.25, ground: LAMP.h }] };
}

// ---------------------------------------------------------------- tram stop

const H_SIGN = grid(
  `
  ...ggggg...
  ..gyyyyyg..
  .gyHyyyHyg.
  .gyHyyyHyg.
  .gyHHHHHyg.
  .gyHyyyHyg.
  .gyHyyyHyg.
  ..gyyyyyg..
  ...ggggg...
  `,
  { g: 'hgreen', y: 'hyellow', H: 'hgreen' },
);

export function stopSign(name) {
  const plateW = textWidth(name) + 6;
  const w = Math.max(plateW, 11);
  const h = 48;
  const img = new Img(w, h);
  const cx = Math.floor(w / 2);
  img.vline(cx, 8, h - 1, 'mt3');
  img.vline(cx + 1, 8, h - 1, 'mt1');
  img.grid(H_SIGN, cx - 5, 0);
  img.rect(cx - Math.floor(plateW / 2), 10, plateW, 8, 'white');
  img.hline(cx - Math.floor(plateW / 2), cx - Math.floor(plateW / 2) + plateW - 1, 17, 'wf0');
  text(img, name, cx - Math.floor(plateW / 2) + 3, 11, 'ink2');
  // line numbers and the timetable case
  img.rect(cx - 7, 20, 6, 7, 'red1');
  text(img, '4', cx - 6, 21, 'white');
  img.rect(cx + 2, 20, 6, 7, '#2f4f8a');
  text(img, '9', cx + 3, 21, 'white');
  img.rect(cx - 3, 29, 7, 9, 'wf2');
  img.rect(cx - 2, 30, 5, 7, 'wf3');
  for (let y = 31; y < 36; y += 2) img.hline(cx - 1, cx + 1, y, 'mt3');
  img.hline(cx - 1, cx + 2, h - 1, 'mt0');
  return { img };
}

/** Glass shelter seen from behind (from the square), with a back-lit poster. */
export function shelter() {
  const w = 56;
  const roofDepth = 14;
  const wallH = 36;
  const h = roofDepth + 3 + wallH;
  const img = new Img(w, h);
  const emit = new Img(w, h);
  const top = roofDepth + 3;
  // what is seen through the glass: the bench inside
  img.rect(4, top + wallH - 14, 28, 2, 'wd3');
  img.rect(4, top + wallH - 12, 28, 1, 'wd1');
  img.vline(6, top + wallH - 11, top + wallH - 1, 'mt1');
  img.vline(29, top + wallH - 11, top + wallH - 1, 'mt1');
  // glass panes
  for (let y = top; y < top + wallH; y++) {
    for (let x = 1; x < 35; x++) {
      const d = (x + y * 0.7) % 26;
      img.px(x, y, d > 18 && d < 21 ? '#c6d9e0@45' : '#88a6b8@22');
    }
  }
  // back-lit poster in its own frame: an open-air cinema night
  const px = 36;
  img.rect(px, top, 19, wallH, 'mt1');
  const poster = new Img(17, wallH - 4);
  poster.fill('#d9cbb0');
  poster.rect(0, 0, 17, 14, 'teal1');
  for (let y = 2; y < 13; y++) for (let x = 2; x < 15; x++) if (Math.hypot(x - 8, y - 9) < 5) poster.px(x, y, 'hyellow');
  poster.rect(0, 11, 17, 3, 'teal0');
  poster.rect(0, 14, 17, 2, 'red2');
  text(poster, 'KINO', 1, 18, 'ink2');
  text(poster, '8.7.', 1, 25, 'red1');
  img.blit(poster, px + 1, top + 2);
  emit.blit(poster, px + 1, top + 2);
  // posts, roof slab and its edge
  for (const x of [0, 17, 35, 55]) {
    img.vline(x, top, top + wallH - 1, 'mt2');
    if (x < 55) img.vline(x + 1, top, top + wallH - 1, 'mt1');
  }
  img.rect(0, 0, w, roofDepth, 'mt2');
  img.hline(0, w - 1, 0, 'mt1');
  for (let x = 2; x < w - 2; x += 6) img.vline(x, 2, roofDepth - 2, 'mt3');
  img.rect(0, roofDepth, w, 3, 'mt1');
  img.hline(0, w - 1, roofDepth, 'mt4');
  img.hline(0, w - 1, h - 1, 'mt0');
  // strip light under the roof
  emit.hline(2, 31, roofDepth + 3, 'fl2');
  return { img, emit, lights: [{ x: 25, y: top + 4, r: 34, color: [0.8, 0.95, 0.95], power: 0.7, ground: h }] };
}

// ---------------------------------------------------------------- advertising column

export function litfass(seed) {
  const w = 18;
  const h = 60;
  const img = new Img(w, h);
  const r = rng(seed);
  const cx = (w - 1) / 2;
  const shade = (x) => {
    const u = (x - cx) / (w / 2); // -1 .. 1 across the cylinder
    return 1.12 - 0.42 * (u + 1) * 0.5 - 0.25 * u * u;
  };
  // posters, pasted over each other
  const body = new Img(w, 42);
  body.fill('cream0');
  const colours = ['red2', 'teal2', 'hyellow', 'pinkG', 'violetG', 'cream1', 'white', 'hgreen', '#2f4f8a'];
  for (let k = 0; k < 9; k++) {
    const pw = 5 + Math.floor(r() * 8);
    const ph = 8 + Math.floor(r() * 12);
    const x = Math.floor(r() * (w - 3)) - 2;
    const y = Math.floor(r() * (42 - ph));
    const c = colours[Math.floor(r() * colours.length)];
    body.rect(x, y, pw, ph, c);
    for (let j = 2; j < ph - 2; j += 3) body.hline(x + 1, x + pw - 3, y + j, mix(c, '#17161c', 0.45));
    if (r() < 0.5) for (let i = 0; i < pw; i += 2) body.px(x + i, y + ph - 1, 'cream0'); // torn edge
  }
  for (let y = 0; y < 42; y++) {
    for (let x = 0; x < w; x++) {
      const p = body.get(x, y);
      const f = shade(x);
      img.px(x, 12 + y, [p[0] * f, p[1] * f, p[2] * f, 255]);
    }
  }
  // dome cap with a ball on top, and the base ring
  for (let y = 0; y < 12; y++) {
    const half = y < 3 ? y + 1 : Math.min(9, 3 + y);
    for (let x = -half; x < half; x++) {
      const c = x < -half / 2 ? 'dg3' : x < half / 3 ? 'dg2' : 'dg1';
      img.px(Math.round(cx + x + 0.5), y, y === 11 ? 'dg0' : c);
    }
  }
  img.hline(0, w - 1, 10, 'dg3');
  img.hline(0, w - 1, 11, 'dg1');
  for (let y = 54; y < h; y++) for (let x = 0; x < w; x++) img.px(x, y, x < 6 ? 'dg3' : x < 12 ? 'dg2' : 'dg1');
  img.hline(0, w - 1, h - 1, 'dg0');
  return { img };
}

// ---------------------------------------------------------------- small things

export const BENCH = grid(
  `
  k..........................k
  kWWWWWWWWWWWWWWWWWWWWWWWWWWk
  kwwwwwwwwwwwwwwwwwwwwwwwwwwk
  k..........................k
  kWWWWWWWWWWWWWWWWWWWWWWWWWWk
  kwwwwwwwwwwwwwwwwwwwwwwwwwwk
  k..........................k
  KSSSSSSSSSSSSSSSSSSSSSSSSSSK
  KssssssssssssssssssssssssssK
  KSSSSSSSSSSSSSSSSSSSSSSSSSSK
  KxxxxxxxxxxxxxxxxxxxxxxxxxxK
  kk........................kk
  .k........................k.
  kk........................kk
  `,
  { k: 'dg1', K: 'dg0', W: 'wd4', w: 'wd2', S: 'wd4', s: 'wd3', x: 'wd1' },
);

export const BIN = grid(
  `
  .KKKKKK.
  KooooooK
  KMMMMmmK
  KGGggggK
  KGgggghK
  KGgyyghK
  KGgggghK
  KGgggghK
  KGgggghK
  KGgggghK
  .KKKKKK.
  `,
  { K: 'ink2', o: 'ink', M: 'mt3', m: 'mt2', G: 'dg3', g: 'dg2', h: 'dg1', y: 'hyellow' },
);

export const A_BOARD = grid(
  `
  .kwwwwk.
  kwbbbbwk
  kwbccbwk
  kwbbbbwk
  kwbcbcwk
  kwbccbwk
  kwbbbbwk
  kwbcbbwk
  kwwwwwwk
  .k....k.
  k......k
  `,
  { k: 'wd1', w: 'wd3', b: '#2a2f2c', c: 'cream1' },
);

export const PIGEONS = [
  grid(
    `
    .hh...
    heggg.
    .gGGGg
    ..y.y.
    `,
    { h: 'mt3', e: 'ink', g: 'mt4', G: 'mt2', y: 'red3' },
  ),
  grid(
    `
    ......
    .ggg..
    hgGGg.
    y.y...
    `,
    { h: 'mt3', g: 'mt4', G: 'mt2', y: 'red3' },
  ),
];

/** A bicycle from the side; `colour` is its frame. */
export function bike(colour) {
  const img = new Img(19, 12);
  const wheel = (cx, cy) => {
    for (let a = 0; a < 64; a++) {
      const t = (a / 64) * Math.PI * 2;
      img.px(Math.round(cx + Math.cos(t) * 4), Math.round(cy + Math.sin(t) * 4), 'ink2');
    }
    img.px(cx, cy, 'mt3');
  };
  wheel(4, 7);
  wheel(14, 7);
  const line = (x0, y0, x1, y1, c) => {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    for (let i = 0; i <= n; i++) img.px(Math.round(x0 + ((x1 - x0) * i) / n), Math.round(y0 + ((y1 - y0) * i) / n), c);
  };
  line(4, 7, 8, 7, colour);
  line(8, 7, 7, 3, colour);
  line(7, 3, 13, 3, colour);
  line(8, 7, 13, 3, colour);
  line(13, 3, 14, 7, colour);
  line(4, 7, 7, 3, colour);
  line(13, 3, 13, 1, 'mt2');
  line(12, 1, 15, 1, 'mt1');
  line(6, 2, 8, 2, 'ink2');
  img.px(8, 8, 'mt2');
  return img;
}
