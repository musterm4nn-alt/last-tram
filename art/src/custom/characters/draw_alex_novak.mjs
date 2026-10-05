// Original Last Tram pixel art. Run with Node from any directory to produce the
// Aseprite MCP edit plan in out/ and a nearest-neighbour review sheet.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const paletteSource = readFileSync(resolve(ROOT, 'art/src/custom/draw_custom.lua'), 'utf8');
const P = Object.fromEntries([...paletteSource.matchAll(/(\w+)\s*=\s*hex\("(#[0-9a-f]{6})"\)/g)].map(m => [m[1], m[2]]));
const C = { o: P.ink, d: P.shadow, s: P.wd3, k: P.wd4, l: P.oc4, m: P.wd1,
  h: P.cb0, b: P.wd0, u: P.wd1, t: P.shadow, f: P.asph2,
  q: P.steel0, g: P.steel1, G: P.steel2, n: P.wa0, N: P.wa1,
  v: P.tl1, w: P.white, W: P.white2 };
const LAYERS = ['body_skin', 'feet_trainers', 'bottom_jeans', 'top_t_shirt', 'outer_hoodie', 'hair_short'];
const W = 16, H = 32;
const blank = () => Array(W * H).fill(null);

function pixel(grid, x, y, colour) {
  if (x < 0 || y < 0 || x >= W || y >= H) throw Error(`Pixel outside canvas: ${x},${y}`);
  grid[y * W + x] = C[colour];
  if (!C[colour]) throw Error(`Unknown colour ${colour}`);
}
function stamp(grid, x, y, rows) {
  rows.forEach((row, dy) => [...row].forEach((c, dx) => {
    if (c !== '.') pixel(grid, x + dx, y + dy, c);
  }));
}
function rect(grid, x, y, width, height, colour) {
  for (let yy = y; yy < y + height; yy++) for (let xx = x; xx < x + width; xx++) pixel(grid, xx, yy, colour);
}
function ribbon(grid, points, colour, width = 4) {
  for (let i = 1; i < points.length; i++) {
    const [ax, ay] = points[i - 1], [bx, by] = points[i];
    const steps = Math.max(Math.abs(bx - ax), Math.abs(by - ay), 1);
    for (let j = 0; j <= steps; j++) {
      const x = Math.round(ax + (bx - ax) * j / steps), y = Math.round(ay + (by - ay) * j / steps);
      rect(grid, x - 1, y, width, 1, colour);
    }
  }
}
function leg(grid, hipX, kneeX, footX, footY, bob, far) {
  const points = [[hipX, 21 + bob], [kneeX, 24], [footX, footY]];
  ribbon(grid, points, 'o');
  ribbon(grid, points.map(([x, y]) => [x + 1, y]), 'n', 2);
  if (!far) ribbon(grid, points, 'N', 1);
}
function shoe(grid, x, y, side, far) {
  stamp(grid, x - 1, y, side ? ['.ooo.', 'ovwWo', 'ovvvo'] : ['.oo.', 'ovWo', 'ovvo']);
  if (far) pixel(grid, x + 1, y + 1, 'v');
}
function sleeve(skin, hoodie, x, y, far, side = false) {
  // Hands share the skin layer; cuff, sleeve and their outlines stay with the hoodie.
  stamp(skin, x, y + 6, ['.os', 'okl', '.os']);
  stamp(hoodie, x, y, side ? ['.oq', 'ogq', 'ogq', 'ogq', 'ogq', 'oqo', '.o.'] :
    ['.oq', 'ogq', 'oGq', 'ogq', 'ogq', 'oqo', '.o.']);
  if (far) for (let yy = y + 1; yy < y + 5; yy++) pixel(hoodie, x + 1, yy, 'q');
}

const FRONT_SKIN = ['..sssss.', '.slllls.', 'skkkkks.', 'skkllkks', 'skokkoks', '.skklks.', '..skms..', '...ss...'];
const FRONT_HAIR = ['..oooo..', '.obuuho.', 'obbuubho', 'obbbbhho', 'ohbbhoo.', 'oh....o.'];
const BACK_HAIR = ['..oooo..', '.obuuho.', 'obbuubho', 'obbbbhho', 'ohbbbbho', 'ohbbbbho', '.ohhhho.', '..ohho..'];
const SIDE_SKIN = ['.ssss..', 'slllls.', 'skkkkls', 'skkkoks', '.skkkl.', '.skkms.', '..sks..', '...s...'];
const SIDE_HAIR = ['..oooo..', '.obuuho.', 'obbuubho', 'obbbbhoo', 'ohbbbho.', 'ohh.....', '.oo.....'];
const FRONT_HOODIE = ['.oqttqo.', 'oqGttgqo', 'ogGttgqo', 'oggttgqo', 'oggttgqo', 'ogqttgqo', 'oggttgqo', 'ogqttgqo', 'oqgttgqo', 'ooqqqqoo'];
const BACK_HOODIE = ['.ogggqo.', 'ogGgggqo', 'ogqgggqo', 'oggqqgqo', 'ogggggqo', 'ogggggqo', 'oggqggqo', 'oggggqqo', 'oqggggqo', 'ooqqqqoo'];
const SIDE_HOODIE = ['.ogttqo', 'oqGGtqo', 'ogGgtqo', 'ogGgtqo', 'ogggtqo', 'ogggtqo', 'ogqgtqo', 'ogqgtqo', 'oqggtqo', 'ooqqqoo'];

function pose(direction, phase = -1, idleVariant = 0) {
  const layers = Object.fromEntries(LAYERS.map(name => [name, blank()]));
  const [skin, shoes, jeans, tee, hoodie, hair] = LAYERS.map(name => layers[name]);
  const walking = phase >= 0, bob = walking && phase % 2 === 1 ? 1 : 0;
  const side = direction === 'right' || direction === 'left', back = direction === 'up';
  const swing = walking ? [1, 0, -1, 0][phase] : 0;
  // One sole stays on row 30 in every pose; the passing leg lifts independently.
  const ankleL = walking ? [27, 27, 25, 26][phase] : 27;
  const ankleR = walking ? [25, 26, 27, 27][phase] : 27;
  if (side) {
    const footL = walking ? [4, 7, 11, 8][phase] : 7;
    const footR = walking ? [11, 8, 4, 7][phase] : 9;
    leg(jeans, 7, 7 + Math.sign(footL - 7), footL, ankleL, bob, true);
    shoe(shoes, footL, ankleL + 1, true, true);
    leg(jeans, 8, 8 + Math.sign(footR - 8), footR, ankleR, bob, false);
    shoe(shoes, footR, ankleR + 1, true, false);
    stamp(jeans, 5, 19 + bob, ['.onnno.', 'onnNnno', 'onNnnno', '.onnno.']);
    stamp(skin, 5, 3 + bob, SIDE_SKIN);
    pixel(skin, 12, 6 + bob, 'k');
    sleeve(skin, hoodie, 5 + swing, 11 + bob, true, true);
    rect(tee, 6, 10 + bob, 5, 10, 't');
    stamp(hoodie, 5, 10 + bob, SIDE_HOODIE);
    sleeve(skin, hoodie, 7 - swing, 11 + bob - swing, false, true);
    stamp(hair, 4, 1 + bob, SIDE_HAIR);
    if (idleVariant) pixel(skin, 9, 6, 's');
  } else {
    const footL = walking ? [4, 5, 6, 5][phase] : 5;
    const footR = walking ? [9, 9, 10, 9][phase] : 9;
    leg(jeans, 5, 5, footL, ankleL, bob, back);
    leg(jeans, 9, 9, footR, ankleR, bob, false);
    stamp(jeans, 4, 19 + bob, ['onnnnnno', 'onNnnNno', 'onNnonNo', 'onNoonNo']);
    shoe(shoes, footL, ankleL + 1, false, back);
    shoe(shoes, footR, ankleR + 1, false, false);
    stamp(skin, 4, 3 + bob, FRONT_SKIN);
    sleeve(skin, hoodie, 2, 11 + bob + swing, false);
    sleeve(skin, hoodie, 11, 11 + bob - swing, true);
    rect(tee, 4, 11 + bob, 8, 9, 't');
    stamp(hoodie, 4, 10 + bob, back ? BACK_HOODIE : FRONT_HOODIE);
    if (back) {
      stamp(hoodie, 5, 9 + bob, ['.oqqqo', 'oqGggq', '.qqqq.']);
    } else {
      pixel(hoodie, 6, 12 + bob, 'G'); pixel(hoodie, 9, 12 + bob, 'v');
      pixel(hoodie, 6, 13 + bob, 'v'); pixel(hoodie, 9, 13 + bob, 'q');
      if (idleVariant) { pixel(skin, 6, 7, 's'); pixel(skin, 9, 7, 's'); }
    }
    stamp(hair, 4, 1 + bob, back ? BACK_HAIR : FRONT_HAIR);
    if (back && idleVariant) { pixel(hoodie, 6, 13, 'g'); pixel(hoodie, 8, 14, 'q'); }
  }
  if (direction === 'left') for (const name of LAYERS) {
    layers[name] = layers[name].map((_, i) => layers[name][Math.floor(i / W) * W + W - 1 - i % W]);
  }
  return layers;
}

const frames = [], tags = [], operations = [];
for (const direction of ['down', 'up', 'left', 'right']) {
  for (const action of ['idle', 'walk']) {
    const start = frames.length + 1, count = action === 'idle' ? 2 : 4;
    for (let i = 0; i < count; i++) frames.push({ direction, action,
      duration: action === 'idle' ? [1850, 150][i] : 120,
      layers: pose(direction, action === 'walk' ? i : -1, action === 'idle' ? i : 0) });
    tags.push({ name: `${action}_${direction}`, from_frame: start, to_frame: frames.length });
  }
}
for (const name of LAYERS) operations.push({ op: 'add_layer', args: { name } });
for (let i = 1; i < frames.length; i++) operations.push({ op: 'add_frame', args: { duration_ms: frames[i].duration } });
frames.forEach((frame, i) => {
  operations.push({ op: 'set_frame_duration', args: { frame: i + 1, duration_ms: frame.duration } });
  for (const layer of LAYERS) {
    const pixels = frame.layers[layer];
    for (let y = 0; y < H; y++) for (let x = 0; x < W;) {
      const colour = pixels[y * W + x], start = x++;
      while (x < W && pixels[y * W + x] === colour) x++;
      if (colour) operations.push({ op: 'draw_line', args: { layer, frame: i + 1,
        x1: start, x2: x - 1, y1: y, y2: y, color: colour } });
    }
  }
});
// Batch operations name the tag bounds `from`/`to`; standalone MCP calls use
// `from_frame`/`to_frame`. Batches must contain at most 500 operations.
for (const tag of tags) operations.push({ op: 'add_tag', args: {
  name: tag.name, from: tag.from_frame, to: tag.to_frame, direction: 'forward' } });
// Use the standalone add_slice tool: the batch variant does not preserve pivots.
const slice = { name: 'feet_origin', x: 0, y: 0, width: W, height: H,
  pivot_x: 8, pivot_y: 31, data: 'Feet at (8,31); transparent bottom row; no shadow baked into sprite.' };

function flatten(frame) {
  return Array.from({ length: W * H }, (_, i) => LAYERS.reduce((c, name) => frame.layers[name][i] || c, null));
}
function crc(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) {
    value ^= byte;
    for (let i = 0; i < 8; i++) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0);
  }
  return (value ^ 0xffffffff) >>> 0;
}
function png(width, height, colours) {
  const rgba = Buffer.alloc(height * (width * 4 + 1));
  colours.forEach((c, i) => {
    if (!c) return;
    const at = Math.floor(i / width) * (width * 4 + 1) + 1 + i % width * 4;
    rgba.writeUInt32BE((parseInt(c.slice(1), 16) * 256 + 255) >>> 0, at);
  });
  const chunk = (type, data) => {
    const payload = Buffer.concat([Buffer.from(type), data]), size = Buffer.alloc(4), check = Buffer.alloc(4);
    size.writeUInt32BE(data.length); check.writeUInt32BE(crc(payload));
    return Buffer.concat([size, payload, check]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', deflateSync(rgba)), chunk('IEND', Buffer.alloc(0))]);
}
const OUT = resolve(ROOT, 'out/alex_novak'), EXPORT = resolve(ROOT, 'art/export/custom/characters');
mkdirSync(OUT, { recursive: true }); mkdirSync(EXPORT, { recursive: true });
writeFileSync(resolve(OUT, 'edit_plan.json'), JSON.stringify({ palette: [...new Set(Object.values(C))], layers: LAYERS, frames: frames.map(({ layers, ...f }) => f), tags, slice, operations }));
// All poses, photographed at 6x with generous gutters; rows are down/up/left/right.
const width = 6 * 22, height = 4 * 38, board = Array(width * height).fill(P.shadow);
frames.forEach((frame, i) => {
  const pixels = flatten(frame), ox = i % 6 * 22 + 3, oy = Math.floor(i / 6) * 38 + 3;
  pixels.forEach((c, j) => { if (c) board[(oy + Math.floor(j / W)) * width + ox + j % W] = c; });
});
const scale = 6, enlarged = Array.from({ length: width * height * scale * scale }, (_, i) =>
  board[Math.floor(Math.floor(i / (width * scale)) / scale) * width + Math.floor(i % (width * scale) / scale)]);
writeFileSync(resolve(EXPORT, 'alex_novak_review.png'), png(width * scale, height * scale, enlarged));
writeFileSync(resolve(OUT, 'idle_down.png'), png(W, H, flatten(frames[0])));
console.log(`Prepared ${frames.length} frames, ${LAYERS.length} editable layers, ${tags.length} tags, ${operations.length} Aseprite operations.`);
