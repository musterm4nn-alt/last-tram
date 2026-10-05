// Renders the art test: the Altmarkt by day and by night, at the game's zoom levels.
// Usage: node art/src/textgrid/build.mjs   (writes to out/art-test/)
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import { compose, nightLight } from './scene.mjs';
import { Img } from './lib.mjs';
import * as P from './props.mjs';
import { tram } from './tram.mjs';
import { personRamps, drawPerson } from './people.mjs';

const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../out/art-test');
const T = 16;
const day = compose();
const night = nightLight(day);

// Whole district at 1x, for comparing with the M0 screenshot.
day.scene.save(path.join(OUT, 'district_day.png'));
night.save(path.join(OUT, 'district_night.png'));

// What the game window (1280 x 720) shows at zoom 2 and zoom 3, centred on the tram stop.
const views = [
  { name: 'zoom2', zoom: 2, cx: 31 * T, cy: 20.5 * T },
  { name: 'zoom3', zoom: 3, cx: 31.5 * T, cy: 20.5 * T },
];
for (const v of views) {
  const w = Math.floor(1280 / v.zoom);
  const h = Math.floor(720 / v.zoom);
  const x = Math.round(v.cx - w / 2);
  const y = Math.round(v.cy - h / 2);
  day.scene.crop(x, y, w, h).scale(v.zoom).save(path.join(OUT, `altmarkt_day_${v.name}.png`));
  night.crop(x, y, w, h).scale(v.zoom).save(path.join(OUT, `altmarkt_night_${v.name}.png`));
}
// A sheet of the separate pieces, the way they would be exported for the game.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const data = (f) => JSON.parse(fs.readFileSync(path.join(root, 'data', f), 'utf8'));
const appearance = data('appearance/appearance.json');
const colours = data('clothing/colours.json').colours;
const sheet = new Img(356, 186, '#2b2a30');
const people = [
  [data('appearance/default_player.json'), 'short'],
  [{ appearance: { skin_tone: 'skin_07', hair_colour: 'black', eye_colour: 'dark_brown' }, outfit: { top: { colour: 'mustard' }, bottom: { colour: 'charcoal' }, feet: { colour: 'black' } } }, 'bun'],
  [{ appearance: { skin_tone: 'skin_02', hair_colour: 'ginger', eye_colour: 'green' }, outfit: { top: { colour: 'white' }, outer: { colour: 'denim' }, bottom: { colour: 'black' }, feet: { colour: 'white' } } }, 'long'],
  [{ appearance: { skin_tone: 'skin_05', hair_colour: 'grey', eye_colour: 'brown' }, outfit: { top: { colour: 'navy' }, outer: { colour: 'olive' }, bottom: { colour: 'beige' }, feet: { colour: 'brown' } } }, 'short'],
  [{ appearance: { skin_tone: 'skin_04', hair_colour: 'blue', eye_colour: 'grey' }, outfit: { top: { colour: 'black' }, outer: { colour: 'burgundy' }, bottom: { colour: 'olive' }, feet: { colour: 'black' } } }, 'long'],
  [{ appearance: { skin_tone: 'skin_08', hair_colour: 'white', eye_colour: 'brown' }, outfit: { top: { colour: 'forest' }, bottom: { colour: 'navy' }, feet: { colour: 'white' } } }, 'bun'],
];
people.forEach(([who, hair], i) => drawPerson(sheet, 6 + i * 20, 4, personRamps(appearance, colours, who), hair, { outer: Boolean(who.outfit.outer) }));
const t = tram();
sheet.blit(t.img, 4, 182 - t.H);
const at = (o, x, bottom) => sheet.blit(o.img ?? o, x, bottom - (o.img ?? o).h);
at(P.lamp(), 132, 66);
at(P.stopSign('ALTMARKT'), 146, 66);
at(P.shelter(), 186, 66);
at(P.litfass(7), 248, 66);
at(P.tree(3), 276, 182);
at(P.fountain(), 236, 182);
const g = (grid) => { const i = new Img(grid.w, grid.h); i.grid(grid, 0, 0); return i; };
at(g(P.BENCH), 132, 84);
at(g(P.BIN), 166, 84);
at(P.bike('red2'), 178, 84);
at(g(P.PIGEONS[0]), 202, 84);
at(g(P.PIGEONS[1]), 210, 84);
sheet.scale(4).save(path.join(OUT, 'pieces.png'));

console.log('wrote', OUT);
