// The yellow tram: a 14 m two-bogie car in the style of the old Tatra trams, seen from its
// right-hand side (doors facing the camera), with its roof and pantograph.
// Windows and doors are text grids; the body is assembled around them.
import { Img, grid, rng } from './lib.mjs';
import { text } from './font.mjs';

export const TRAM = { length: 224, side: 48, roof: 32, panto: 40 };

const WINDOW = grid(
  `
  .kkkkkkkkkkk.
  koooooooooook
  kbbbbbbbbbbck
  kkkkkkkkkkkkk
  kaaaaaaaabcek
  kaaaaaaabceak
  kaaaaaabceaak
  kaaaaaaceaaak
  kaaaaaaaaaaak
  kaaaaaaaaaaak
  kaaaaaaaaaaak
  kaaaaaaaaaaak
  kaaaaaaaaaaak
  kbaaaaaaaaaak
  kbbaaaaaaaaak
  .kkkkkkkkkkk.
  `,
  { k: 'tr0', o: 'gl0', a: 'gl1', b: 'gl2', c: 'gl3', e: 'gl4' },
);
const WINDOW_LIT = { ...WINDOW, legend: { ...WINDOW.legend, o: 'lw3', b: 'lw3', a: 'lw2', c: 'lw3', e: 'cream1' } };

const DOOR = grid(
  `
  kkkkkkkkkkkkkkkkkk
  kYyyyYyyyYyyyYyyyk
  kYooyYooyYooyYooyk
  kYaayYaayYaayYbayk
  kYaayYaayYaayYcbyk
  kYaayYaayYabyYeayk
  kYaayYaayYbcyYaayk
  kYaayYaayYceyYaayk
  kYaayYabyYaayYaayk
  kYaayYbcyYaayYaayk
  kYaayYceyYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYaayYaayYaayYaayk
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kY111Y111Y111Y111k
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kYyyyYyyyYyyyYyyyk
  kY111Y111Y111Y111k
  kkkkkkkkkkkkkkkkkk
  `,
  { k: 'tr0', Y: 'ty3', y: 'ty2', 1: 'ty1', o: 'gl0', a: 'gl1', b: 'gl2', c: 'gl3', e: 'gl4' },
);
const DOOR_LIT = { ...DOOR, legend: { ...DOOR.legend, o: 'lw1', a: 'lw1', b: 'lw2', c: 'lw2', e: 'lw3' } };

/**
 * Draws the tram. The image's bottom edge is the south edge of its footprint; the roof
 * is above the side, and the pantograph reaches up to the contact wire.
 */
export function tram({ seed = 4, passengers = [] } = {}) {
  const { length: L, side: S, roof: R, panto: P } = TRAM;
  const H = S + R + P + 4;
  const img = new Img(L, H);
  const emit = new Img(L, H);
  const base = H - 1; // ground line
  const up = (v) => base - v;
  const r = rng(seed);

  // Rounded ends: the cab (right) is rounder than the rear.
  const inBody = (x, v) => {
    const corner = (cx, cy, rad) => Math.hypot(x - cx, v - cy) <= rad;
    if (x < 10 && v > S - 10) return corner(10, S - 10, 10);
    if (x > L - 15 && v > S - 15) return corner(L - 15, S - 15, 15);
    if (x < 3 && v < 10) return corner(3, 10, 3);
    if (x > L - 6 && v < 12) return corner(L - 6, 12, 6);
    return v >= 7 && v < S;
  };

  // Underside and bogies.
  for (let x = 6; x < L - 6; x++) for (let v = 3; v < 7; v++) img.px(x, up(v), 'tr0');
  for (const bx of [48, L - 48]) {
    img.rect(bx - 18, up(8), 36, 7, 'tr0');
    for (const wx of [bx - 10, bx + 10]) {
      for (let a = 0; a < 40; a++) {
        const t = (a / 40) * Math.PI * 2;
        img.px(Math.round(wx + Math.cos(t) * 4), Math.round(up(4) + Math.sin(t) * 4), 'mt1');
      }
      img.px(wx, up(4), 'mt3');
    }
    img.hline(bx - 18, bx + 17, up(8), 'mt1');
  }

  // Body side.
  for (let x = 0; x < L; x++) {
    for (let v = 7; v < S; v++) {
      if (!inBody(x, v)) continue;
      let c = 'ty2';
      if (v <= 8) c = 'ty0';
      else if (v <= 10) c = 'ty1';
      else if (v >= 19 && v <= 21) c = v === 21 ? 'tc2' : 'tc1';
      else if (v >= S - 3) c = v === S - 1 ? 'tc1' : v === S - 2 ? 'tc2' : 'ty3';
      else if (v === 18) c = 'ty1';
      img.px(x, up(v), c);
    }
  }
  // Panel seams.
  for (let x = 40; x < L - 20; x += 46) for (let v = 9; v < 19; v++) img.px(x, up(v), 'ty1');

  // Windows, doors and the cab.
  const doors = [22, 102, 180];
  const windows = [];
  for (let x = 6; x < L - 28; ) {
    const door = doors.find((d) => x + 13 > d - 2 && x < d + 20);
    if (door !== undefined) {
      x = door + 20;
      continue;
    }
    windows.push(x);
    x += 16;
  }
  for (const wx of windows) {
    img.grid(WINDOW, wx, up(39));
    emit.grid(WINDOW_LIT, wx, up(39));
  }
  // Passengers inside, softened by the glass.
  for (const wx of windows) {
    if (r() > 0.45) continue;
    const px = wx + 3 + Math.floor(r() * 5);
    const skin = ['#e3b494', '#c9945f', '#8b5734', '#f1cfb8', '#653c24'][Math.floor(r() * 5)];
    const hair = ['#1d1a18', '#3b2b20', '#a0824e', '#9a9a98', '#8c4a2b'][Math.floor(r() * 5)];
    const coat = ['#3a3d42', '#6b2433', '#2f5a3a', '#1f2a4a', '#6b6b3a'][Math.floor(r() * 5)];
    const person = (target, shade) => {
      const s = (c) => (shade ? shade : `${c}@70`);
      target.rect(px + 1, up(32), 4, 4, s(skin));
      target.rect(px + 1, up(33), 4, 1, s(hair));
      target.px(px, up(31), s(hair));
      target.rect(px - 1, up(28), 7, 4, s(coat));
    };
    person(img, null);
    person(emit, '#2a2230');
  }
  for (const d of doors) {
    img.grid(DOOR, d, up(40));
    emit.grid(DOOR_LIT, d, up(40), { only: 'oabce' });
    img.rect(d + 1, up(7), 16, 3, 'tr0'); // step
  }
  // Cab: side window, windscreen edge, headlight, line number.
  for (let v = 24; v < 40; v++) {
    for (let x = L - 26; x < L - 2; x++) {
      if (!inBody(x, v)) continue;
      const slope = x > L - 12 && v - 24 > (L - x) * 1.4;
      if (slope) continue;
      const edge = x === L - 26 || v === 24 || v === 39;
      img.px(x, up(v), edge ? 'tr0' : (x + v) % 9 === 0 ? 'gl3' : 'gl1');
      emit.px(x, up(v), edge ? '#00000000' : 'lw2');
    }
  }
  img.rect(L - 7, up(14), 4, 3, 'cream1');
  img.px(L - 6, up(13), 'white');
  emit.rect(L - 7, up(14), 4, 3, 'white');
  img.rect(2, up(14), 2, 3, 'red2');
  emit.rect(2, up(14), 2, 3, 'red3');
  img.rect(L - 44, up(36), 7, 9, 'white');
  text(img, '4', L - 42, up(34), 'ink2');

  // Roof: a long rounded top, lighter where it curves towards us.
  const roofTop = up(S) - R;
  for (let j = 0; j < R; j++) {
    for (let x = 0; x < L; x++) {
      const rad = 12;
      const cy = j < rad ? rad : j > R - rad ? R - rad : j;
      if (x < rad && Math.hypot(x - rad, j - cy) > rad) continue;
      if (x > L - rad && Math.hypot(x - (L - rad), j - cy) > rad) continue;
      let c = 'tg2';
      if (j < 3) c = j === 0 ? 'tg0' : 'tg1';
      else if (j > R - 4) c = j === R - 1 ? 'tc1' : 'tg3';
      else if (j === 8 || j === 23) c = 'tg1';
      else if (j < 8) c = 'tg1';
      img.px(x, roofTop + j, c);
    }
  }
  // Roof equipment: resistor boxes, vents, the pantograph's frame.
  const box = (x, y, w, h) => {
    img.rect(x, y, w, h, 'mt2');
    img.hline(x, x + w - 1, y, 'mt3');
    img.hline(x, x + w - 1, y + h - 1, 'mt0');
    for (let i = x + 3; i < x + w - 2; i += 4) img.vline(i, y + 2, y + h - 3, 'mt1');
  };
  box(26, roofTop + 9, 44, 9);
  box(L - 62, roofTop + 10, 30, 8);
  for (let x = 84; x < L - 70; x += 14) {
    img.rect(x, roofTop + 21, 5, 3, 'mt3');
    img.hline(x, x + 4, roofTop + 24, 'mt1');
  }
  const pc = Math.floor(L / 2) + 6;
  const pb = roofTop + R / 2; // pantograph base, on the roof's centre line
  img.rect(pc - 12, pb - 2, 24, 4, 'mt1');
  for (const ix of [pc - 11, pc + 10]) img.rect(ix, pb - 4, 2, 2, 'cream1');
  const line = (x0, y0, x1, y1, c, w = 1) => {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    for (let i = 0; i <= n; i++) {
      const x = Math.round(x0 + ((x1 - x0) * i) / n);
      const y = Math.round(y0 + ((y1 - y0) * i) / n);
      img.px(x, y, c);
      if (w > 1) img.px(x + 1, y, c === 'mt1' ? 'mt2' : c);
    }
  };
  const knee = [pc + 12, pb - 20];
  const head = [pc - 2, pb - P + 1];
  line(pc - 8, pb - 2, knee[0], knee[1], 'mt1', 2);
  line(knee[0], knee[1], head[0], head[1], 'mt2');
  line(pc - 6, pb - 3, pc + 2, pb - 12, 'mt3');
  line(head[0] - 9, head[1], head[0] + 9, head[1], 'mt2');
  line(head[0] - 7, head[1] - 1, head[0] + 7, head[1] - 1, 'ink');
  img.px(head[0] - 10, head[1] + 1, 'mt2');
  img.px(head[0] + 10, head[1] + 1, 'mt2');

  const lights = [];
  for (const wx of windows) lights.push({ x: wx + 6, y: up(30), r: 26, color: [1.0, 0.86, 0.6], power: 0.45, ground: H });
  lights.push({ x: L + 10, y: up(10), r: 56, color: [1.0, 0.95, 0.8], power: 0.9, ground: H });
  return { img, emit, lights, H, head: { x: head[0], y: head[1] } };
}
