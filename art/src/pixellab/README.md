# PixelLab test (branch art/pixellab-test only)

A throwaway test of PixelLab (pixellab.ai MCP) against route B, 3 October 2026. Not for `main`.

- `raw/`: PixelLab downloads. Resident "Resident test small" (id 958225a8-…, standard mode,
  size 30, low top-down, 4 directions; template animations `walking-4-frames` and
  `breathing-idle`). Tilesets (16 px, high top-down, chained by base tile ids):
  `pavement_grass` 1f2127a1-…, `road_cobbles` ef895f19-…, `cobbles_grass` 4bd7eaba-…,
  `cobbles_pavement` 4658ebf9-…. Bench: map object 8e673703-…, style-matched to a crop of
  route B's cobbles.
- `build.json` + `build_pixellab.gd`: palette-locks the tiles and the bench to route B's
  colours and writes `art/export/pixellab/`. `make_set.py` writes `data/art2d/pixellab.json`
  (route B + everything) from the build's printed "wang" entries; `pixellab_mix.json` is
  route B + only the people and the bench.
- Game side (test only): `ArtSet.wang` / `people`, `WorldView2D._wang_layer` (corner tiles
  half a cell off the grid), `PersonView2D._draw_sprite` (every person uses the one sheet).

## Characters: base bodies, recoloured (4 October)

Three PixelLab base bodies (standard mode, size 30, 4 directions, `walking-4-frames` and
`breathing-idle`; 9 generations each): `resident` (base_a: short hair, hoodie, jeans),
`base_b` 573de5e4-… (long hair, jacket, skirt), `base_c` abed88fa-… (heavy, bald, beard,
custom proportions). `fetch_character.sh <id> <name>` downloads one. `build_pixellab.gd`
writes `<base>.png` and `<base>_mask.png`: per-base colour rules in `build.json` sort each
pixel into skin, hair, top, bottom (or keep), with its shade. In the game,
`PeopleSprites` picks a base from the appearance (long hair → b; stocky, heavy or a beard
→ c; else a) and paints the groups in the person's skin, hair, outer-or-top and bottom
colours, cached per look.
