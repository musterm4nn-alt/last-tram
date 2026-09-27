// Small pixel-art toolkit: colours, text-grid sprites, an RGBA image and a PNG writer.
// No dependencies beyond Node itself.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { PAL } from './palette.mjs';

// ---------------------------------------------------------------- colours

/** '#rrggbb' or '#rrggbb@NN' (NN = opacity in percent) or a palette name → [r, g, b, a]. */
export function rgba(c) {
  if (Array.isArray(c)) return c;
  let alpha = 255;
  const at = c.indexOf('@');
  if (at >= 0) {
    alpha = Math.round((Number(c.slice(at + 1)) / 100) * 255);
    c = c.slice(0, at);
  }
  if (!c.startsWith('#')) {
    const named = PAL[c];
    if (!named) throw new Error(`unknown colour "${c}"`);
    const base = rgba(named);
    return [base[0], base[1], base[2], Math.round((base[3] * alpha) / 255)];
  }
  const n = parseInt(c.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255, alpha];
}

export function hex([r, g, b]) {
  return '#' + [r, g, b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
}

// OKLab lets ramps change lightness without muddying the hue.
const toLin = (v) => ((v /= 255) <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
const toSrgb = (v) => 255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055);

export function toOklab([r, g, b]) {
  const [lr, lg, lb] = [toLin(r), toLin(g), toLin(b)];
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

export function fromOklab([L, A, B]) {
  const l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s = (L - 0.0894841775 * A - 1.291485548 * B) ** 3;
  const clamp = (v) => Math.max(0, Math.min(255, v));
  return [
    clamp(toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)),
    clamp(toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)),
    clamp(toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)),
  ];
}

/**
 * Five-step ramp from one base colour: [deep shadow, shadow, base, light, highlight].
 * Shadows drift cool and lights drift warm, the usual pixel-art hue shift. Very dark and
 * very light bases are stretched so that every step stays visible.
 */
export function ramp(base) {
  const [L, A, B] = toOklab(rgba(base));
  const steps = [-0.2, -0.1, 0, 0.085, 0.16];
  const lo = Math.max(0, 0.2 - L); // lift the ramp for near-black bases
  const hi = Math.max(0, L - 0.86); // and push it down for near-white ones
  return steps.map((d, i) => {
    let dl = d;
    if (d > 0) dl = d + lo * 0.9 - hi * 0.8;
    if (d < 0) dl = d * (1 - lo * 1.5) - hi * 0.3;
    const shift = i < 2 ? -0.012 * (2 - i) : i > 2 ? 0.006 * (i - 2) : 0;
    const chroma = i === 0 ? 0.9 : i === 4 ? 0.9 : 1;
    return hex(fromOklab([L + dl, A * chroma + shift * 0.3, B * chroma + shift]));
  });
}

export function mix(a, b, t) {
  const x = rgba(a);
  const y = rgba(b);
  return hex([0, 1, 2].map((i) => x[i] + (y[i] - x[i]) * t));
}

// ---------------------------------------------------------------- randomness

export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Stable pseudo-random number in [0, 1) for a grid position. */
export function hash2(x, y, seed = 0) {
  let h = Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(seed | 0, 2246822519);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

const BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
/** Ordered-dither threshold in (0, 1) for a pixel. */
export const bayer = (x, y) => (BAYER4[(y & 3) * 4 + (x & 3)] + 0.5) / 16;

// ---------------------------------------------------------------- sprites

/**
 * A sprite written as a text grid. Every character is one pixel; '.' is transparent.
 * The legend maps characters to colours: palette names, '#rrggbb', '#rrggbb@NN', or a
 * ramp slot such as 'skin.2' that is filled in when the sprite is drawn (layered people).
 */
export function grid(text, legend = {}) {
  const rows = text
    .split('\n')
    .map((r) => r.trim())
    .filter((r) => r.length > 0);
  const w = Math.max(...rows.map((r) => r.length));
  for (const r of rows) {
    for (const ch of r) {
      if (ch !== '.' && !(ch in legend)) throw new Error(`grid uses "${ch}" without a legend entry:\n${r}`);
    }
  }
  return { w, h: rows.length, rows, legend };
}

// ---------------------------------------------------------------- images

export class Img {
  constructor(w, h, fill) {
    this.w = w;
    this.h = h;
    this.d = new Float32Array(w * h * 4);
    if (fill) this.fill(fill);
  }

  fill(c) {
    this.rect(0, 0, this.w, this.h, c);
    return this;
  }

  get(x, y) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return [0, 0, 0, 0];
    const i = (y * this.w + x) * 4;
    return [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]];
  }

  /** Paints one pixel with source-over blending. */
  px(x, y, c) {
    x |= 0;
    y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const [r, g, b, a] = rgba(c);
    if (a <= 0) return;
    const i = (y * this.w + x) * 4;
    const t = a / 255;
    const da = this.d[i + 3] / 255;
    const oa = t + da * (1 - t);
    if (oa <= 0) return;
    this.d[i] = (r * t + this.d[i] * da * (1 - t)) / oa;
    this.d[i + 1] = (g * t + this.d[i + 1] * da * (1 - t)) / oa;
    this.d[i + 2] = (b * t + this.d[i + 2] * da * (1 - t)) / oa;
    this.d[i + 3] = oa * 255;
  }

  /** Multiplies the RGB of one pixel (for shadows and light maps). */
  mul(x, y, f) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    this.d[i] *= f[0];
    this.d[i + 1] *= f[1];
    this.d[i + 2] *= f[2];
  }

  rect(x, y, w, h, c) {
    for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.px(i, j, c);
  }

  hline(x0, x1, y, c) {
    for (let x = x0; x <= x1; x++) this.px(x, y, c);
  }

  vline(x, y0, y1, c) {
    for (let y = y0; y <= y1; y++) this.px(x, y, c);
  }

  /** Draws a text-grid sprite with its top-left corner at (x, y). */
  grid(g, x, y, { ramps = {}, flip = false, only = null } = {}) {
    for (let j = 0; j < g.h; j++) {
      const row = g.rows[j];
      for (let i = 0; i < row.length; i++) {
        const ch = row[i];
        if (ch === '.') continue;
        if (only && !only.includes(ch)) continue;
        let c = g.legend[ch];
        const dot = typeof c === 'string' ? c.match(/^([a-z_]+)\.(\d)$/) : null;
        if (dot) {
          const r = ramps[dot[1]];
          if (!r) throw new Error(`no ramp "${dot[1]}" passed for sprite`);
          c = r[Number(dot[2])];
        }
        this.px(flip ? x + g.w - 1 - i : x + i, y + j, c);
      }
    }
  }

  /** Draws another image onto this one (source-over). */
  blit(src, x, y, sx = 0, sy = 0, w = src.w, h = src.h) {
    for (let j = 0; j < h; j++) {
      for (let i = 0; i < w; i++) {
        const p = src.get(sx + i, sy + j);
        if (p[3] > 0) this.px(x + i, y + j, p);
      }
    }
  }

  crop(x, y, w, h) {
    const out = new Img(w, h);
    out.blit(this, 0, 0, x, y, w, h);
    return out;
  }

  /** Nearest-neighbour upscale, as the game does at integer zoom. */
  scale(n) {
    const out = new Img(this.w * n, this.h * n);
    for (let y = 0; y < out.h; y++) {
      for (let x = 0; x < out.w; x++) {
        const si = (((y / n) | 0) * this.w + ((x / n) | 0)) * 4;
        const di = (y * out.w + x) * 4;
        for (let k = 0; k < 4; k++) out.d[di + k] = this.d[si + k];
      }
    }
    return out;
  }

  clone() {
    const out = new Img(this.w, this.h);
    out.d.set(this.d);
    return out;
  }

  save(file) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, encodePng(this));
  }
}

// ---------------------------------------------------------------- PNG

const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

export function encodePng(img) {
  const stride = img.w * 4 + 1;
  const raw = Buffer.alloc(stride * img.h);
  for (let y = 0; y < img.h; y++) {
    raw[y * stride] = 0;
    for (let x = 0; x < img.w * 4; x++) {
      raw[y * stride + 1 + x] = Math.max(0, Math.min(255, Math.round(img.d[y * img.w * 4 + x])));
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0);
  ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
