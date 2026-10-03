# Art direction and pipeline

**Owner of all art work: Claude Code (Opus).** Builders don't make or edit art. The human
owner approves every look.

## Now: placeholders on purpose

Until the art gate (after M3) everything is a readable placeholder:
- Terrain: flat colour tiles generated at runtime from `debug_color` in `data/terrain.json`
  (`game/view2d/placeholder_tiles.gd`).
- People: drawn from their appearance and outfit by `PersonDrawer2D` (T-0019): body width
  from the build, height from the height, skin tone, hair by style (`ViewConfig.HAIR_SHAPE`)
  and colour, facial hair, glasses, clothes and headwear in their colours. The player has a
  small yellow marker above the head. Unknown ids draw magenta so mistakes show.
- Objects (M1): a coloured footprint with a short label.

Placeholder rules: every kind of thing must be distinguishable at zoom 2, colours stay in the
muted palette below, and nothing in `sim/` depends on how anything looks.

**Walls by direction** (T-0085, view only, `WallShapes`): the wall along the top of a room
shows its face (the wall, window or door tile); side and bottom walls are thin lines with the
ground beside them, windows there are strips of glass, doors there are doorways. So wall,
window and door tiles are always drawn as faces.

**Day and night** (T-0083, view only): `DayNight` tints the world by the clock (white by day,
dusk at 19:30, blue night from 21:00 to 05:00) and `NightLights2D` adds one light whose
texture is a light map: lit interiors in warm white, sodium-orange pools under the street
lamps, and amber glows at a share of the windows. Art should read under both.

## The look we're aiming for

- **Top-down 3/4 pixel art**, like modern Stardew-style or LimeZu's Modern series, but
  grittier.
- **Palette:** muted and urban. Grey stone and asphalt, ochre and pastel Altbau facades,
  rust, weathered green copper, **yellow trams**, warm sodium-orange street lights at night.
- **Grit:** graffiti, stickers on lamp posts, bins, cigarette butts, bikes chained to railings,
  a Späti's crowded window. A lived-in, not dystopian, look.
- **Readable silhouettes:** people must read at 16 px wide; interactables must stand out
  from decoration.

## The art gate (after M3)

Opus makes the **same scene** (Altmarkt + Haus 12, day and night) in two or three routes, and
the owner picks one:

| Route | Pros | Cons |
|---|---|---|
| **Asset pack**: LimeZu *Modern Interiors* and *Modern Exteriors* (paid, 16/32/48 px), or Kenney (free, CC0) | Fast and consistent; covers a huge amount | Not unique; must fit the tone; licence terms |
| **AI-drawn in Aseprite** (Opus via the Aseprite MCP) | Fully custom and consistent with the setting | Slower; quality varies; animation is hard |
| **ChatGPT Images → Aseprite cleanup** (owner's ChatGPT Plus, Opus cleans up) | Rich concepts, fast ideation | Output isn't real pixel art: it needs downscaling, palette locking and cleanup, and consistency takes discipline |

A mix is likely: a pack for the bulk plus custom pieces for signature things (the tram, the
Späti, characters).

## Technical spec (applies to every route)

- **Tile size:** 16 px (`ViewConfig.TILE_PX`). If the gate picks 32 px, change that one
  constant; the sim is unaffected.
- **Characters:** 16×32 px frames, 4 directions (down, up, left, right), idle + walk (4
  frames), later sit, sleep, use, fight. Layered to match the appearance and outfit data
  (body and skin tone, hair style and colour, facial hair, features, one layer per clothing
  slot), tinted with the colours in `data/appearance/` and `data/clothing/`, so every
  combination the character creator allows can be drawn, and residents can be generated.
- **Portraits:** a larger front-facing "paper doll" (about 64×128 px) for the character
  creator, the wardrobe and the person inspector, layered the same way.
- **Objects:** sized in whole cells matching their `size` in data; 4 rotations where
  rotatable (or 2 plus flip).
- **Filtering:** nearest (already the project default). No mipmaps. Integer zoom levels.
- **Files:** sources in `art/src/` (`.aseprite`), exports in `art/export/<category>/`, and
  licences and credits in `art/LICENSES.md` (every third-party asset is listed with source and
  licence).
- **Mapping art to content:** by content id, in view-only art sets (`data/art2d/<set>.json`,
  format in [data/art2d/README.md](../data/art2d/README.md), T-0080), picked with `--art=<set>`.
  Terrain maps to 16-px tiles (with variants), objects to a sheet rect (or one per rotation).
  The view falls back to the placeholder when an id has no art, so art can arrive gradually.

## AI image pipeline (if chosen)

1. The owner (or Opus through the ChatGPT Images tool) generates a concept or sheet; images
   land in `~/Downloads`.
2. Opus imports the image into Aseprite (MCP), downscales to target size, quantises to the
   project palette, cleans up edges and outlines by hand, and fixes the perspective to top-down
   3/4.
3. Opus exports to `art/export/`, adds the mapping entry, takes a screenshot in-game and asks
   the owner to approve.

## Later: 3D low-poly isometric

If the view moves to 3D, the same content ids map to low-poly models (Blender MCP; Poly Pizza
or Poly Haven assets with credits for CC-BY). The grid (cells + levels) maps directly to
isometric blocks. Nothing in `sim/` changes.
