// Text-grid parts for facades: windows, doors, dormers, chimneys and small details.
import { grid } from './lib.mjs';

const WIN_LEGEND = {
  h: 'trim.4', H: 'trim.2', t: 'trim.3', T: 'trim.1', S: 'trim.4', s: 'trim.2', d: 'wall.1',
  g: 'wf1', f: 'wf2', o: 'gl0', a: 'gl1', b: 'gl2', c: 'gl3', e: 'gl4', k: 'cream0', K: 'cream1',
  Q: 'wall.1', p: 'wall.2', P: 'wall.3',
};

/** Tall Altbau window: stone hood, six-pane frame, sill and a panel below. */
export const WINDOW = grid(
  `
  .hhhhhhhhhhhh.
  HHHHHHHHHHHHHH
  .tggggggggggT.
  .tfoooffooofT.
  .tfbbbffbbcfT.
  .tfbbbffbcefT.
  .tfbbbffbbbfT.
  .tffffffffffT.
  .tfoooffooofT.
  .tfaaaffaabfT.
  .tfaaaffabcfT.
  .tfaaaffbcefT.
  .tfaaaffaabfT.
  .tfaaaffaaafT.
  .tfaaaffaaafT.
  .tffffffffffT.
  .tfoooffooofT.
  .tfaaaffaaafT.
  .tfaaaffaaafT.
  .tfaaaffaabfT.
  .tfaaaffabbfT.
  .tfaaaffaaafT.
  .tggggggggggT.
  SSSSSSSSSSSSSS
  .ssssssssssss.
  ..dddddddddd..
  ..tQQQQQQQQT..
  ..tppppppppT..
  ..tppppppppT..
  ..tPPPPPPPPT..
  `,
  WIN_LEGEND,
);

/** The same window with its curtains drawn. */
export const WINDOW_CURTAINS = grid(
  WINDOW.rows
    .map((row, y) =>
      [...row]
        .map((ch, x) => {
          if (y < 3 || y > 21 || !'oabce'.includes(ch)) return ch;
          if (x === 3 || x === 10) return 'K';
          if ((x === 4 || x === 9) && (y < 6 || y % 4 === 0)) return 'k';
          return ch;
        })
        .join(''),
    )
    .join('\n'),
  WIN_LEGEND,
);

/** Glass that glows at night: warm light behind the panes and curtains. */
export const LIT = { o: 'lw1', a: 'lw2', b: 'lw2', c: 'lw3', e: 'lw3', K: '#f0cf8c', k: '#d9a95e' };
export const litGrid = (g) => ({ ...g, legend: { ...g.legend, ...LIT } });

/** Wooden double door with a fanlight, a stone hood and two steps. */
export const DOOR = grid(
  `
  .hhhhhhhhhhhh.
  HHHHHHHHHHHHHH
  .tddddddddddT.
  .tkkkkkkkkkkT.
  .tkoookkoookT.
  .tkabbkkbcekT.
  .tkkkkkkkkkkT.
  .twwwwxwwwwxT.
  .twqqqxwqqqxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twxxxxwxxxxT.
  .twwwwxwwwwxT.
  .twwwwmwwwwxT.
  .twqqqxwqqqxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twqppxwqppxT.
  .twxxxxwxxxxT.
  .twwwwxwwwwxT.
  .twwwwxwwwwxT.
  hhhhhhhhhhhhhh
  HHHHHHHHHHHHHH
  dddddddddddddd
  `,
  {
    h: 'trim.4', H: 'trim.2', t: 'trim.3', T: 'trim.1', d: 'trim.0',
    k: 'wd1', o: 'gl0', a: 'gl1', b: 'gl2', c: 'gl3', e: 'gl4',
    w: 'wd2', x: 'wd1', q: 'wd4', p: 'wd3', m: 'mt4',
  },
);

/** Pointed dormer window that sits in the roof. */
export const DORMER = grid(
  `
  .......rr.......
  ......rRRr......
  .....rRRRRr.....
  ....rRRRRRRr....
  ...rRRwwwwRRr...
  ..rRRwwwwwwRRr..
  .rRRwwwwwwwwRRr.
  rRRWwggggggwWRRr
  ..RWwfoofoofwWR.
  ..RWwfbbfbcfwWR.
  ..RWwfbbfcefwWR.
  ..RWwffffffwWR..
  ..RWwfaafaafwWR.
  ..RWwfaafabfwWR.
  ..RWwfaafaafwWR.
  ..RWwggggggwWR..
  ..RWwwwwwwwwwWR.
  ..RWWWWWWWWWWWR.
  `,
  {
    r: 'roof.0', R: 'roof.1', W: 'wall.1', w: 'wall.2',
    g: 'wf1', f: 'wf2', o: 'gl0', a: 'gl1', b: 'gl2', c: 'gl3', e: 'gl4',
  },
);

/** Brick chimney with a cap: its front face and its sooty top. */
export const CHIMNEY = grid(
  `
  .ccccccc.
  cCoooooCc
  ccccccccc
  .MMMMMMM.
  .bbmbbbm.
  .bbbbmbb.
  .mbbbmbb.
  .bbbbbbb.
  .bbmbbbm.
  .bbbbmbb.
  .Mbbbbbb.
  .bbbbbbb.
  .rrrrrrr.
  `,
  { c: 'mt2', C: 'mt3', o: 'ink', M: 'mt0', b: 'br1', m: 'br0', r: 'roof.0' },
);

export const SAT_DISH = grid(
  `
  ..mmm.
  .mMMMm
  mMMMMm
  mMMMm.
  .mmm..
  ..k...
  ..kk..
  `,
  { m: 'mt3', M: 'wf1', k: 'mt1' },
);

export const TAGS = [
  grid(
    `
    p..pp..p.
    p.p..p.pp
    pp...pp.p
    p....p..p
    `,
    { p: 'pinkG' },
  ),
  grid(
    `
    .ww.ww..w
    w..w..ww.
    .ww.w..w.
    `,
    { w: 'white' },
  ),
  grid(
    `
    tt.t..tt.t
    t.tt.t..tt
    t..t.tt..t
    `,
    { t: 'teal2' },
  ),
];

export const WASHER = grid(
  `
  FFFFFF
  fmfkkf
  ffffff
  frrrrf
  fraerf
  frrrrf
  gggggg
  `,
  { F: 'wf3', f: 'wf2', m: 'teal2', k: 'mt2', r: 'mt2', a: 'gl1', e: 'gl3', g: 'wf0' },
);
