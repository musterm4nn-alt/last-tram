// The Last Tram palette: muted and urban (docs/art.md). Every sprite picks its colours from
// here, except people, whose skin, hair and clothes come from data/appearance and
// data/clothing and are turned into ramps when they are drawn.
// Ramps run dark → light (0 is the darkest).
export const PAL = {
  // outlines and cast shadows
  ink: '#17161c',
  ink2: '#26232b',
  shadow: '#1b1830@38',
  shadowSoft: '#1b1830@22',

  // asphalt
  asph0: '#26282e',
  asph1: '#30333a',
  asph2: '#383b42',
  asph3: '#42454c',
  asph4: '#4f5258',
  tar: '#2b2d33',

  // road paint
  paint: '#d6d3c8',
  paintWorn: '#a4a39b',

  // rails
  rail0: '#1f2024',
  rail1: '#5f6166',
  rail2: '#9c9ea2',
  rail3: '#d2d4d4',

  // pavement slabs
  slab0: '#5a5b5f',
  slab1: '#737478',
  slab2: '#808184',
  slab3: '#8c8c89',
  slab4: '#9a9993',

  // granite curbs
  curb0: '#3e3e44',
  curb1: '#78777a',
  curb2: '#a4a29b',
  curb3: '#bdbab0',

  // cobblestones
  cob0: '#39352f',
  cobJ: '#4a453f',
  cob1: '#57514a',
  cob2: '#6a635a',
  cob3: '#7d766b',
  cob4: '#93897b',
  cobR: '#76604f',
  cobB: '#5f666b',

  // grass
  gr0: '#2a3f27',
  gr1: '#37522f',
  gr2: '#466536',
  gr3: '#597b40',
  gr4: '#72944d',
  gr5: '#94b062',

  // linden foliage
  lf0: '#1b2d22',
  lf1: '#27432c',
  lf2: '#355a33',
  lf3: '#4a733c',
  lf4: '#67904a',
  lf5: '#8fb05c',

  // bark and soil
  bark0: '#271e1b',
  bark1: '#3f3129',
  bark2: '#58463a',
  soil0: '#332820',
  soil1: '#4b3d33',

  // water
  wat0: '#1c384a',
  wat1: '#28526a',
  wat2: '#3a6f88',
  wat3: '#6699ac',
  wat4: '#b6d6da',

  // facade: ochre
  och0: '#6b5231',
  och1: '#957649',
  och2: '#b3915f',
  och3: '#c9a974',
  och4: '#dcc393',

  // facade: sage grey
  sag0: '#454d47',
  sag1: '#5f6963',
  sag2: '#77837b',
  sag3: '#909c92',
  sag4: '#adb7ab',

  // facade: salmon
  sal0: '#6a4843',
  sal1: '#90645d',
  sal2: '#ad8277',
  sal3: '#c59f90',
  sal4: '#dbbeac',

  // facade: pale blue-grey
  pbl0: '#454c56',
  pbl1: '#636c77',
  pbl2: '#7e8893',
  pbl3: '#99a3ab',
  pbl4: '#b6bec2',

  // sandstone (darkens with age, like Elbsandstein)
  ss0: '#3f372f',
  ss1: '#62574a',
  ss2: '#83786a',
  ss3: '#a39884',
  ss4: '#bfb49e',

  // roof: weathered terracotta
  ter0: '#3a221e',
  ter1: '#542f28',
  ter2: '#6d4033',
  ter3: '#85523f',
  ter4: '#9d6750',
  moss: '#58623a',

  // roof: slate
  sl0: '#23272e',
  sl1: '#31363f',
  sl2: '#40464f',
  sl3: '#535b66',
  sl4: '#6a737e',

  // roof: copper
  cu0: '#2c463f',
  cu1: '#3b5f53',
  cu2: '#507b6a',
  cu3: '#6d9b86',
  cu4: '#97bea8',

  // brick (chimneys)
  br0: '#3b221f',
  br1: '#5a3129',
  br2: '#774235',

  // wood
  wd0: '#281b16',
  wd1: '#40281e',
  wd2: '#5a3a29',
  wd3: '#755034',
  wd4: '#926844',

  // glass by day
  gl0: '#1a222c',
  gl1: '#263442',
  gl2: '#374b5d',
  gl3: '#546d82',
  gl4: '#88a6b8',
  gl5: '#c6d9e0',

  // painted window frames
  wf0: '#88867f',
  wf1: '#b8b5ab',
  wf2: '#d9d6cb',
  wf3: '#ece9df',

  // grey metal
  mt0: '#1d1f24',
  mt1: '#31343a',
  mt2: '#494d54',
  mt3: '#686d74',
  mt4: '#8d949b',

  // street-furniture green
  dg0: '#141d19',
  dg1: '#1f2f27',
  dg2: '#2d4336',
  dg3: '#405c4b',

  // tram
  ty0: '#76521a',
  ty1: '#aa7a20',
  ty2: '#d49f2c',
  ty3: '#e8bd48',
  ty4: '#f4d77a',
  tc0: '#8a857b',
  tc1: '#c9c4b5',
  tc2: '#e3dfd2',
  tr0: '#25272c',
  tg0: '#55534f',
  tg1: '#74716b',
  tg2: '#8c8981',
  tg3: '#a8a49a',

  // accents
  red0: '#5a1f1d',
  red1: '#862e28',
  red2: '#aa4437',
  red3: '#c96650',
  hgreen: '#2d6c43',
  hyellow: '#e6c33f',
  teal0: '#1e4747',
  teal1: '#2e6664',
  teal2: '#468a84',
  teal3: '#78b3a8',
  cream0: '#c9c0a6',
  cream1: '#e4dcc3',
  pinkG: '#c35e8a',
  violetG: '#6c4e98',
  white: '#ecebe6',

  // light sources (night)
  sod1: '#c86a1e',
  sod2: '#f0953a',
  sod3: '#ffc06a',
  sod4: '#ffe3b0',
  lw0: '#7e5226',
  lw1: '#c9873a',
  lw2: '#eeb65c',
  lw3: '#ffdc98',
  fl1: '#cfe9dd',
  fl2: '#f1fbf6',
};
