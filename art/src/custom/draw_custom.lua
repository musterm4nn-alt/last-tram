-- Last Tram, art gate route B: tiles and objects drawn by Opus in Aseprite.
-- Draws art/src/custom/terrain.aseprite and objects.aseprite and exports them to
-- art/export/custom/*.png. The layout matches data/art2d/custom.json.
-- Run from the Aseprite MCP (run_lua_script) with: dofile("<repo>/art/src/custom/draw_custom.lua")
-- after setting ROOT to the repo path.

local ROOT = ROOT or "."
local pc = app.pixelColor

local function hex(s, a)
  s = s:gsub("#", "")
  return pc.rgba(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16), a or 255)
end

-- The palette (docs/art.md): grey stone and asphalt, ochre Altbau, rust, copper green,
-- yellow trams, sodium orange.
local P = {
  ink = hex("#1e1c22"), shadow = hex("#2c2d31"),
  asph0 = hex("#36373c"), asph1 = hex("#414248"), asph2 = hex("#4b4c53"), asph3 = hex("#585a61"),
  st0 = hex("#6e6a66"), st1 = hex("#85807a"), st2 = hex("#9c968e"), st3 = hex("#b2aba1"), st4 = hex("#c7c0b4"),
  cb0 = hex("#554c46"), cb1 = hex("#73685f"), cb2 = hex("#867a6f"), cb3 = hex("#978a7d"), cb4 = hex("#ab9d8e"),
  oc0 = hex("#7a5a2e"), oc1 = hex("#9c7638"), oc2 = hex("#b98f47"), oc3 = hex("#cfa95f"), oc4 = hex("#e0c486"),
  rust0 = hex("#6e3626"), rust1 = hex("#8e4a32"), rust2 = hex("#a85e3c"), rust3 = hex("#c27a52"),
  cu0 = hex("#2f5246"), cu1 = hex("#3f6b5a"), cu2 = hex("#5f8f7a"), cu3 = hex("#86b39c"),
  wd0 = hex("#5e3f29"), wd1 = hex("#7d5536"), wd2 = hex("#966644"), wd3 = hex("#ab7b52"), wd4 = hex("#c29164"),
  tl0 = hex("#a39d90"), tl1 = hex("#c2bcae"), tl2 = hex("#d9d4c7"), tl3 = hex("#e8e3d8"),
  gr0 = hex("#3e5429"), gr1 = hex("#4c6632"), gr2 = hex("#5d7a3e"), gr3 = hex("#728f4a"), gr4 = hex("#8aa65a"),
  wa0 = hex("#355f78"), wa1 = hex("#4f7f99"), wa2 = hex("#6fa0b8"), wa3 = hex("#a9cfe0"),
  yel = hex("#e8b83a"), yel2 = hex("#f4d47a"), white = hex("#ece6d8"), white2 = hex("#f8f5ee"),
  glass = hex("#8fb8c9"), glass2 = hex("#c4dde6"), lamp = hex("#f6d58e"), pink = hex("#d97a9a"),
  steel0 = hex("#5a5e64"), steel1 = hex("#8d939b"), steel2 = hex("#c4c9ce"),
}

-- A fixed hash for texture noise: 0-99.
local function h(x, y, s)
  local v = (x * 73856093) ~ (y * 19349663) ~ ((s or 0) * 83492791)
  v = (v ~ (v >> 13)) * 1274126177
  v = v ~ (v >> 16)
  return v % 100
end

local img -- the image being drawn
local OX, OY = 0, 0 -- origin of the current tile or sprite

local function px(x, y, c) img:drawPixel(OX + x, OY + y, c) end
local function rect(x, y, w, hh, c)
  for yy = y, y + hh - 1 do for xx = x, x + w - 1 do px(xx, yy, c) end end
end
local function hline(x, y, w, c) rect(x, y, w, 1, c) end
local function vline(x, y, hh, c) rect(x, y, 1, hh, c) end
local function box(x, y, w, hh, fill, line)
  rect(x, y, w, hh, line or P.ink)
  rect(x + 1, y + 1, w - 2, hh - 2, fill)
end
-- Fill with base and sprinkle `a` and `b` by hash (percent chances).
local function noise(x, y, w, hh, base, a, pa, b, pb, seed)
  for yy = y, y + hh - 1 do
    for xx = x, x + w - 1 do
      local n = h(OX + xx, OY + yy, seed)
      local c = base
      if n < pa then c = a elseif b and n < pa + pb then c = b end
      px(xx, yy, c)
    end
  end
end
local function disc(cx, cy, r, c)
  for yy = math.floor(cy - r), math.ceil(cy + r) do
    for xx = math.floor(cx - r), math.ceil(cx + r) do
      if (xx - cx) ^ 2 + (yy - cy) ^ 2 <= r * r then px(xx, yy, c) end
    end
  end
end

---------------------------------------------------------------- terrain (16x16 each)

local T = {}

function T.sidewalk(v)
  noise(0, 0, 16, 16, P.st2, P.st1, 8, P.st3, 6, 11 + v)
  -- big slabs with grout, staggered on the second variant
  local off = v == 2 and 4 or 0
  hline(0, 7, 16, P.st0); hline(0, 15, 16, P.st0)
  vline((7 + off) % 16, 0, 7, P.st0); vline((15 - off) % 16, 8, 7, P.st0)
  hline(0, 0, 16, P.st3); hline(0, 8, 16, P.st3)
  if v == 2 then -- a cigarette butt and a crack: lived-in
    px(11, 3, P.white); px(12, 3, P.rust3)
    px(3, 10, P.st0); px(4, 11, P.st0); px(5, 11, P.st0); px(6, 12, P.st0)
  end
end

function T.cobblestone(v)
  rect(0, 0, 16, 16, P.cb0)
  local shades = { P.cb1, P.cb2, P.cb3, P.cb2 }
  for row = 0, 3 do
    local off = (row % 2) * 2
    for col = -1, 4 do
      local x = col * 4 + off
      local c = shades[h(col + 7 * v, row, 5) % 4 + 1]
      for yy = row * 4, row * 4 + 2 do
        for xx = x, x + 2 do
          if xx >= 0 and xx < 16 then px(xx, yy, c) end
        end
      end
      if x >= 0 and x < 16 then px(x, row * 4, P.cb4) end
    end
  end
  if v == 3 then px(9, 6, P.yel); px(10, 6, P.white) end -- a bottle cap
end

function T.road(v)
  noise(0, 0, 16, 16, P.asph1, P.asph0, 10, P.asph2, 9, 21 + v)
  if v == 2 then -- a darker patch where the road was dug up
    rect(3, 4, 9, 7, P.asph0)
    hline(3, 4, 9, P.asph2); vline(3, 4, 7, P.asph2)
  end
end

function T.tram_track()
  T.road(1)
  for _, y in ipairs({ 3, 10 }) do -- grooved rails set in the asphalt
    hline(0, y - 1, 16, P.asph0)
    hline(0, y, 16, P.steel2)
    hline(0, y + 1, 16, P.steel1)
    hline(0, y + 2, 16, P.shadow)
  end
end

function T.crossing()
  T.road(1)
  for _, y in ipairs({ 1, 9 }) do
    rect(0, y, 16, 5, P.tl2)
    for xx = 0, 15 do -- worn paint
      if h(xx, y, 3) < 18 then px(xx, y + h(xx, y, 4) % 5, P.st2) end
    end
  end
end

function T.grass(v)
  noise(0, 0, 16, 16, P.gr2, P.gr1, 14, P.gr3, 14, 31 + v)
  for i = 0, 5 do
    local x, y = h(i, v, 7) % 15, h(v, i, 8) % 14
    px(x, y, P.gr4); px(x, y + 1, P.gr3)
  end
  if v == 2 then px(5, 9, P.yel); px(11, 4, P.white2) end
  if v == 3 then px(10, 11, P.gr0); px(11, 12, P.gr0); px(3, 3, P.gr0) end
end

function T.tree()
  T.grass(1)
  disc(9, 10, 6.2, P.gr0) -- shadow on the grass
  disc(8, 8, 7.2, P.ink)
  disc(8, 8, 6.5, hex("#34502a"))
  disc(7, 7, 5, hex("#46683a"))
  disc(6, 6, 3, hex("#5c8344"))
  for i = 0, 6 do
    local x, y = 3 + h(i, 1, 9) % 10, 3 + h(1, i, 9) % 10
    px(x, y, hex("#71994f"))
  end
end

function T.fountain()
  rect(0, 0, 16, 16, P.st1)
  hline(0, 0, 16, P.st3); vline(0, 0, 16, P.st3)
  rect(2, 2, 12, 12, P.wa1)
  hline(2, 2, 12, P.wa0); vline(2, 2, 12, P.wa0)
  for i = 0, 4 do px(4 + h(i, 2, 1) % 8, 4 + h(2, i, 1) % 8, P.wa2) end
  rect(6, 6, 4, 4, P.wa2); rect(7, 7, 2, 2, P.wa3) -- the spout's splash
end

function T.wall(v)
  noise(0, 0, 16, 16, P.oc2, P.oc1, 9, P.oc3, 7, 41 + v)
  hline(0, 0, 16, P.oc4); hline(0, 1, 16, P.oc3) -- the top of the wall
  hline(0, 14, 16, P.oc1); hline(0, 15, 16, P.oc0) -- the face in shadow
  if v == 2 then -- a graffiti tag and a flyer
    hline(3, 7, 4, P.pink); px(2, 8, P.pink); px(7, 8, P.pink); hline(4, 9, 3, P.cu3)
    rect(10, 4, 3, 4, P.white); px(11, 5, P.rust2)
  end
end

function T.window()
  T.wall(1)
  box(2, 2, 12, 11, P.glass, P.white)
  vline(7, 3, 9, P.white); vline(8, 3, 9, P.white)
  hline(3, 6, 10, P.white)
  px(4, 4, P.glass2); px(5, 3, P.glass2); px(10, 4, P.glass2); px(11, 3, P.glass2)
  hline(1, 13, 14, P.oc0) -- the sill
end

function T.door()
  rect(0, 0, 16, 16, P.wd1)
  for xx = 1, 14, 3 do vline(xx, 1, 14, P.wd2) end
  hline(0, 0, 16, P.wd0); hline(0, 15, 16, P.wd0); vline(0, 0, 16, P.wd0); vline(15, 0, 16, P.wd0)
  px(12, 8, P.yel); px(12, 9, P.oc0)
end

function T.floor_wood(v)
  local shades = { P.wd2, P.wd3, P.wd2, P.wd4 }
  for row = 0, 3 do
    local y = row * 4
    local c = shades[h(row, v, 13) % 4 + 1]
    rect(0, y, 16, 4, c)
    hline(0, y + 3, 16, P.wd1)
    local joint = (h(row, v, 14) % 12) + 2
    vline(joint, y, 3, P.wd1)
    px(h(row, v, 15) % 16, y + 1, P.wd1)
  end
end

function T.floor_tile()
  for ty = 0, 1 do
    for tx = 0, 1 do
      local c = (tx + ty) % 2 == 0 and P.tl2 or P.tl1
      rect(tx * 8, ty * 8, 8, 8, c)
      hline(tx * 8, ty * 8, 8, P.tl3)
    end
  end
  hline(0, 7, 16, P.tl0); hline(0, 15, 16, P.tl0); vline(7, 0, 16, P.tl0); vline(15, 0, 16, P.tl0)
end

-- terrain id, number of variants (in the order of data/art2d/custom.json)
local TERRAIN = {
  { "sidewalk", 3 }, { "cobblestone", 3 }, { "road", 5 }, { "tram_track", 1 }, { "crossing", 1 },
  { "grass", 3 }, { "tree", 1 }, { "fountain", 1 }, { "wall", 4 }, { "window", 1 }, { "door", 1 },
  { "floor_wood", 2 }, { "floor_tile", 1 },
}

---------------------------------------------------------------- objects

local O = {}

function O.bench() -- 32x20: wooden slats on iron legs, backrest behind
  box(1, 2, 30, 6, P.wd2); hline(2, 4, 28, P.wd1); hline(2, 3, 28, P.wd3)
  box(0, 9, 32, 7, P.wd3); hline(1, 12, 30, P.wd1); hline(1, 10, 30, P.wd4)
  for _, x in ipairs({ 2, 28 }) do rect(x, 7, 2, 2, P.shadow); rect(x, 16, 2, 3, P.shadow) end
end

function O.street_lamp() -- 16x48: a lantern on a dark post
  rect(6, 12, 3, 34, P.ink); vline(7, 12, 34, P.steel0)
  box(4, 43, 8, 5, P.shadow)
  box(3, 2, 10, 10, P.lamp)
  rect(4, 3, 8, 8, P.lamp); rect(5, 4, 3, 3, P.white2)
  box(2, 0, 12, 3, P.shadow); px(7, 0, P.steel1)
  hline(4, 11, 8, P.shadow)
end

function O.atm() -- 16x24: a cash machine with a copper-green sign
  box(0, 4, 16, 20, P.st2)
  box(0, 0, 16, 6, P.cu1); hline(4, 2, 8, P.yel)
  box(3, 8, 10, 6, P.wa1); hline(4, 9, 8, P.wa2)
  for yy = 15, 19, 2 do for xx = 4, 10, 3 do rect(xx, yy, 2, 1, P.st0) end end
  hline(4, 21, 8, P.ink)
end

function O.notice_case() -- 16x24: a glass case of notices on two legs
  box(0, 0, 16, 16, P.glass, P.cu0)
  rect(2, 2, 5, 6, P.white); rect(8, 3, 6, 4, P.yel2); rect(3, 9, 4, 5, P.yel2); rect(8, 8, 5, 6, P.white)
  hline(3, 4, 3, P.st0); hline(9, 10, 3, P.rust1)
  rect(2, 16, 2, 8, P.cu0); rect(12, 16, 2, 8, P.cu0)
end

function O.bed_double() -- 32x32: headboard at the top
  box(0, 0, 32, 32, P.wd2)
  box(0, 0, 32, 5, P.wd1)
  box(2, 5, 13, 6, P.white2); box(17, 5, 13, 6, P.white2)
  box(1, 11, 30, 20, P.cu2)
  hline(2, 12, 28, P.white); hline(2, 13, 28, P.cu3)
  for yy = 16, 29, 4 do hline(2, yy, 28, P.cu1) end
end

function O.sofa() -- 32x20: rust fabric, two cushions
  box(0, 0, 32, 9, P.rust1); hline(1, 1, 30, P.rust2)
  box(0, 7, 5, 12, P.rust1); box(27, 7, 5, 12, P.rust1)
  box(4, 8, 12, 9, P.rust2); box(16, 8, 12, 9, P.rust2)
  hline(5, 9, 10, P.rust3); hline(17, 9, 10, P.rust3)
  rect(2, 19, 2, 1, P.shadow); rect(28, 19, 2, 1, P.shadow)
end

function O.wardrobe() -- 16x32: a tall cabinet
  box(0, 0, 16, 32, P.wd2)
  rect(1, 1, 14, 3, P.wd4)
  vline(7, 4, 27, P.wd0); vline(8, 4, 27, P.wd1)
  px(6, 16, P.yel); px(9, 16, P.yel)
  hline(1, 30, 14, P.wd1)
end

function O.fridge() -- 16x28
  box(0, 0, 16, 28, P.white)
  rect(1, 1, 14, 3, P.white2)
  hline(1, 11, 14, P.tl0)
  vline(12, 5, 4, P.st1); vline(12, 14, 8, P.st1)
  vline(14, 4, 23, P.tl1)
end

function O.stove() -- 16x16, from above: four rings and knobs
  box(0, 0, 16, 16, P.st3)
  for _, c in ipairs({ { 4, 4 }, { 11, 4 }, { 4, 10 }, { 11, 10 } }) do
    disc(c[1] - 0.5, c[2] - 0.5, 2.6, P.ink); px(c[1] - 1, c[2] - 1, P.st0)
  end
  hline(1, 14, 14, P.st1); px(4, 14, P.ink); px(8, 14, P.ink); px(12, 14, P.ink)
end

function O.sink() -- 16x16: a basin in a worktop, tap at the back
  box(0, 0, 16, 16, P.st3)
  box(2, 4, 12, 10, P.st1); rect(3, 5, 10, 8, P.st2); px(8, 9, P.st0)
  rect(7, 1, 2, 4, P.steel1); px(7, 1, P.steel2)
end

function O.kitchen_table() -- 32x16: wood top with two plates and a fruit bowl
  box(0, 0, 32, 16, P.wd3)
  hline(1, 1, 30, P.wd4); hline(2, 6, 12, P.wd2); hline(16, 10, 13, P.wd2)
  disc(7.5, 8.5, 3, P.white); disc(7.5, 8.5, 1.5, P.tl1)
  disc(24.5, 7.5, 3, P.white); disc(24.5, 7.5, 1.5, P.tl1)
  disc(16, 6, 2.5, P.wd1); px(15, 5, P.rust3); px(16, 6, P.yel); px(17, 5, P.gr3)
  hline(0, 15, 32, P.wd0)
end

function O.desk() -- 16x20: a desk with an open laptop and a mug
  box(0, 4, 16, 16, P.wd3); hline(1, 5, 14, P.wd4); hline(1, 18, 14, P.wd1)
  box(2, 0, 10, 8, P.shadow); rect(3, 1, 8, 6, P.wa1); px(4, 2, P.wa3)
  box(1, 8, 12, 4, P.steel1); hline(2, 9, 10, P.steel0)
  box(12, 12, 3, 4, P.rust2)
end

function O.tv() -- 16x20: a flat TV on a low stand
  box(0, 0, 16, 12, P.shadow); rect(2, 2, 12, 8, P.wa0); hline(3, 3, 4, P.wa2); px(3, 4, P.wa2)
  rect(7, 12, 2, 2, P.ink)
  box(1, 13, 14, 7, P.wd2); hline(2, 16, 12, P.wd1)
end

function O.shower() -- 16x16: tiled tray, drain and a glass screen
  box(0, 0, 16, 16, P.tl3)
  for yy = 1, 14, 4 do hline(1, yy, 14, P.tl2) end
  rect(7, 7, 2, 2, P.st0)
  vline(14, 1, 14, P.glass2); vline(13, 1, 14, P.glass)
  rect(2, 1, 3, 2, P.steel1)
end

function O.tram_stop() -- 96x40: a glass shelter, copper roof, the yellow and green H sign
  box(0, 0, 96, 9, P.cu1); hline(1, 1, 94, P.cu3); hline(1, 7, 94, P.cu0)
  box(0, 8, 96, 26, P.glass)
  for x = 16, 80, 16 do vline(x, 9, 24, P.steel0) end
  for i = 0, 5 do px(4 + i * 16, 12, P.glass2); px(5 + i * 16, 11, P.glass2); px(6 + i * 16, 10, P.glass2) end
  box(26, 24, 44, 6, P.wd3); hline(27, 25, 42, P.wd4)
  box(3, 14, 10, 14, P.white); hline(5, 17, 6, P.st0); hline(5, 20, 6, P.st0); hline(5, 23, 4, P.st0) -- the timetable
  rect(88, 6, 2, 34, P.ink)
  disc(88.5, 5.5, 5, P.ink); disc(88.5, 5.5, 4.2, P.yel)
  vline(87, 3, 6, P.cu1); vline(90, 3, 6, P.cu1); hline(87, 5, 4, P.cu1)
end

-- def id, width, height (left to right in objects.png, in the order of custom.json)
local OBJECTS = {
  { "bench", 32, 20 }, { "street_lamp", 16, 48 }, { "atm", 16, 24 }, { "notice_case", 16, 24 },
  { "bed_double", 32, 32 }, { "sofa", 32, 20 }, { "wardrobe", 16, 32 }, { "fridge", 16, 28 },
  { "stove", 16, 16 }, { "sink", 16, 16 }, { "kitchen_table", 32, 16 }, { "desk", 16, 20 },
  { "tv", 16, 20 }, { "shower", 16, 16 }, { "tram_stop", 96, 40 },
}

---------------------------------------------------------------- build

local function make(w, hh, draw_all, name)
  local spr = Sprite(w, hh, ColorMode.RGB)
  img = Image(w, hh, ColorMode.RGB)
  draw_all()
  spr.cels[1].image = img
  spr.layers[1].name = name
  spr:saveAs(ROOT .. "/art/src/custom/" .. name .. ".aseprite")
  spr:saveCopyAs(ROOT .. "/art/export/custom/" .. name .. ".png")
  spr:close()
end

local tiles = 0
for _, t in ipairs(TERRAIN) do tiles = tiles + t[2] end
make(tiles * 16, 16, function()
  local col = 0
  for _, t in ipairs(TERRAIN) do
    for v = 1, t[2] do
      OX, OY = col * 16, 0
      T[t[1]](v)
      col = col + 1
    end
  end
end, "terrain")

local width = 0
for _, o in ipairs(OBJECTS) do width = width + o[2] end
make(width, 48, function()
  local x = 0
  for _, o in ipairs(OBJECTS) do
    OX, OY = x, 0
    O[o[1]]()
    print(string.format('"%s": [%d, 0, %d, %d]', o[1], x, o[2], o[3]))
    x = x + o[2]
  end
end, "objects")
print("drew " .. tiles .. " tiles")
