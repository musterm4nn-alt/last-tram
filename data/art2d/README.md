# Art sets for the 2D view

One JSON file per art set: `data/art2d/<set>.json`, picked with `--art=<set>` (T-0080). View
only: the sim never reads these files. Anything a set doesn't map, or maps wrongly, draws as
the placeholder, and the problem is printed as a warning. Loaded by `game/view2d/art_set.gd`.

```json
{
  "name": "Kenney",
  "sheets": { "terrain": "res://art/export/kenney/terrain.png", "objects": "res://art/export/kenney/objects.png" },
  "terrain": {
    "grass": { "sheet": "terrain", "cell": [0, 0], "variants": 3 },
    "road":  { "sheet": "terrain", "cell": [3, 0] }
  },
  "objects": {
    "bench":      { "sheet": "objects", "rect": [0, 0, 32, 24] },
    "bed_double": { "sheet": "objects", "rects": [[0, 32, 32, 48], [32, 32, 48, 32], [80, 32, 32, 48], [112, 32, 48, 32]] }
  }
}
```

- `sheets`: name → an imported PNG under `res://art/export/`.
- `terrain`: terrain id (from `data/terrain.json`) → `cell` in 16-px tiles. `variants`
  (default 1) takes that many tiles to the right; each map cell picks one by a fixed hash of
  its position, the same every run.
- `objects`: object def id → `rect` `[x, y, w, h]` in sheet pixels for every rotation, or
  `rects` with exactly 4, one per rotation (0–3). A sprite may be larger than the footprint:
  its bottom edge sits on the footprint's bottom edge, centred horizontally.
- `thin_walls` (optional, T-0085): colours of the thin walls the view draws for side and
  bottom walls: any of `top`, `edge`, `face`, `glass` as `"#rrggbb"`. Without it they come
  from the wall tile's average colour. The `wall`, `window` and `door` tiles are drawn only
  where a wall shows its face (the top wall of a room), so draw them as faces.
- `roof` (optional, T-0086): `{ "sheet": ..., "cell": [x, y], "variants": n }`, like a
  terrain: the tile drawn over closed buildings. Without it the view draws shingles.
