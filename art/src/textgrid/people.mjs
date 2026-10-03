// People: 16 × 32 frames built from layers (body, then hair), tinted with the colours in
// data/appearance and data/clothing so every creator combination can be drawn.
import { grid, ramp } from './lib.mjs';

const LEGEND = {
  K: 'ink2',
  s: 'skin.2', S: 'skin.1', z: 'skin.3', m: 'skin.1',
  E: 'ink2', e: 'eye.1',
  o: 'outer.2', O: 'outer.1', p: 'outer.3', Q: 'outer.0',
  t: 'top.2', T: 'top.1',
  b: 'bottom.2', B: 'bottom.1', n: 'bottom.3',
  f: 'feet.2', F: 'feet.1', g: 'feet.3',
  h: 'hair.2', H: 'hair.1', j: 'hair.3', J: 'hair.4',
};

/** Standing, facing the camera. The head is bald here; hair is its own layer. */
export const BODY_FRONT = grid(
  `
  ................
  ................
  ................
  ................
  ......KKKK......
  ....KKzzssKK....
  ...KzzsssssSK...
  ..KzzsssssssSK..
  ..KzssssssssSK..
  ..KzssssssssSK..
  ..KzssssssssSK..
  ..KzssEssEssSK..
  ..KzssessessSK..
  ...KsssmmsssK...
  ....KSssssSK....
  .....KKSSKK.....
  ..KooopttpoooK..
  .KpoooOttOoooOK.
  .KpoooOTtOoooOK.
  .KpoOoOttOoOoOK.
  .KpoOoOttOoOoOK.
  .KpoOoOTtOoOoOK.
  .KpoOopttpoOoOK.
  .KzsOooTtooOsSK.
  .KzsOQQQQQQOsSK.
  ..KKnbbBBbbBKK..
  ...KnbbBBbbBK...
  ...KnbbBBbbBK...
  ...KnbbBBbbBK...
  ...KnbBKKnbBK...
  ...KgfFKKgfFK...
  ...KKKKKKKKKK...
  `,
  LEGEND,
);

/** The same body wearing only a top (no jacket or hoodie). */
export const BODY_FRONT_PLAIN = grid(
  BODY_FRONT.rows
    .map((row, y) => {
      const plain = {
        16: '..KoooOssOoooK..',
        17: '.KpooooooooooOK.',
        18: '.KpooooooooooOK.',
        19: '.KpoOooooooOoOK.',
        20: '.KpoOooooooOoOK.',
        21: '.KpoOooooooOoOK.',
        22: '.KpoOooooooOoOK.',
        23: '.KzsOooooooOsSK.',
      };
      return plain[y] ?? row;
    })
    .join('\n'),
  LEGEND,
);

export const HAIR_FRONT = {
  short: grid(
    `
    ................
    ................
    ................
    ................
    ......KKKK......
    ....KKhhhhKK....
    ...KhhhhjjhhK...
    ..KhhhhjjjhhhK..
    ..KhhhhhhhhhHK..
    ..KHhh....hhHK..
    ..KH........HK..
    `,
    LEGEND,
  ),
  long: grid(
    `
    ................
    ................
    ................
    ................
    ......KKKK......
    ....KKhhhhKK....
    ...KhhhjjhhhK...
    ..KhhhjjjhhhhK..
    ..KhhhhhhhhhhK..
    ..Khhhh..hhhhK..
    ..KhhH....HhhK..
    ..Khh......hhK..
    ..Khh......hhK..
    ..KhhK....KhhK..
    ..KhhhK..KhhhK..
    ..KhhhK..KhhhK..
    ..KhhH....HhhK..
    ..KhH......HhK..
    ..KH........HK..
    ...K........K...
    `,
    LEGEND,
  ),
  bun: grid(
    `
    ................
    ......KKKK......
    .....KhjjhK.....
    ....KKhhhHKK....
    ...KKhhhhhhKK...
    ..KhhhjjjjhhhK..
    ..KhhhhhhhhhhK..
    ..KhhhhhhhhhHK..
    ..KHh......hHK..
    ..KH........HK..
    `,
    LEGEND,
  ),
};

/** Colour ramps for one person, from the same ids the character creator saves. */
export function personRamps(appearanceData, clothingColours, person) {
  const find = (list, id) => (list.find((c) => c.id === id) ?? { color: '#ff00ff' }).color;
  const a = person.appearance;
  const o = person.outfit;
  const top = ramp(find(clothingColours, o.top.colour));
  return {
    skin: ramp(find(appearanceData.skin_tones, a.skin_tone)),
    hair: ramp(find(appearanceData.hair_colours, a.hair_colour)),
    eye: ramp(find(appearanceData.eye_colours, a.eye_colour)),
    top,
    outer: o.outer ? ramp(find(clothingColours, o.outer.colour)) : top,
    bottom: ramp(find(clothingColours, o.bottom.colour)),
    feet: ramp(find(clothingColours, o.feet.colour)),
  };
}

export function drawPerson(img, x, y, ramps, hairStyle, { outer = true } = {}) {
  for (let i = 3; i < 13; i++) img.px(x + i, y + 31, 'shadow');
  for (let i = 4; i < 12; i++) img.px(x + i, y + 32, 'shadow');
  for (let i = 5; i < 11; i++) img.px(x + i, y + 33, 'shadowSoft');
  img.grid(outer ? BODY_FRONT : BODY_FRONT_PLAIN, x, y, { ramps });
  const hair = HAIR_FRONT[hairStyle] ?? HAIR_FRONT.short;
  if (hairStyle !== 'bald') img.grid(hair, x, y, { ramps });
}
