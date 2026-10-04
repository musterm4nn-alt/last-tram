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

## Objects: the Späti counter (4 October)

`spaeti_counter` (map object 05af111d-…, style-matched to route B's floor tiles, 96×64
canvas): crowded shelves, counter and till, 66×42 px, not palette-locked (`"lock": false`)
so the goods keep their colours. **It cost 5 generations** (a 96×64 canvas; the 64×64 bench
cost 1). Too wide for the 3-cell counter, and the shelves hide the clerk behind them: in
production, split into back shelves (under people) and the counter front. The first trial
account is used up (40 of 40).

## Four more bodies (second trial account, 4 October)

`base_d` 4b237698-… (curly black hair, red jacket, blue chinos; black hair is found by
position, `dark_hair_rows`), `base_e` 09ae7578-… (ponytail, green sweater, jeans), `base_f`
3f6dc39e-… (short blonde hair, purple jacket, grey trousers), `base_g` 135de5b9-… (tall,
slim, grey hair, long navy coat; custom proportions). `PeopleSprites.base_for` picks: tied
hair → e, long hair → b, curly → d, heavy/beard/bald → c, slim and 180 cm+ → g, women
otherwise → f, else a. Second account: 36 of 40 used.

## Tidied colour maps (4 October)

Rules may carry a row range (rows from the top of the figure): eyes in the head rows keep
their colour (they were read as trousers), the blonde body's pale face highlights are skin,
the tall body's legs below the coat are trousers, the long-haired body's hair stops at the
shoulders, and the ponytail body's cheeks follow the skin. `_despeckle` gives a lone stray
pixel its neighbours' group.

## Heads cleaned up (4 October, after the owner's notes)

`_resolve_heads`: in the head rows, light one-off pixels (eye whites, highlights) join the
skin or hair around them, dark strands inside hair join the hair, skin pixels inside hair
join it, and clothing colours high on the head (a hair clip) join hair or skin; below the
head, dark folds inside clothes take the clothes' colour. `_shade` softens each pixel's
brightness against its group (CONTRAST) and snaps it to SHADES, so bright recolours don't
streak. Rules added: pale top-of-head pixels are the blonde body's hair; the tall body's
greys in the top rows are hair, and its coat takes lighter blue highlights.
