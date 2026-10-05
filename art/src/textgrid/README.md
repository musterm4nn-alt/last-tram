# Text-grid pixel art (art test)

A candidate art route for the art gate (see `docs/art.md`): sprites written as text grids
(one character per pixel, a legend per sprite, colours from `palette.mjs`), assembled by
small Node scripts. No dependencies beyond Node.

```bash
node art/src/textgrid/build.mjs   # writes out/art-test/*.png
```

| File | What it holds |
|---|---|
| `palette.mjs` | The muted urban palette, as named ramps (dark → light) |
| `lib.mjs` | Colours and ramps, text-grid sprites, an RGBA image, a PNG writer |
| `ground.mjs` | Terrain tiles (16 × 16): arc paving, setts, asphalt, slabs, grass, water, tram track |
| `buildings.mjs` | Facades built from the openings (`W`, `D`) in the district map |
| `facade-parts.mjs`, `shopfronts.mjs`, `roofs.mjs` | Windows, doors and dormers; shop windows and signs; roofs |
| `people.mjs` | 16 × 32 bodies and hair layers, tinted from `data/appearance` and `data/clothing` |
| `props.mjs`, `plants.mjs`, `fountain.mjs`, `tram.mjs` | Street furniture, trees and hedges, the fountain, and the tram |
| `font.mjs` | A 3 × 5 pixel font for signs |
| `world.mjs`, `scene.mjs` | Reads `data/world/districts/altstadt`, composes the scene, lights it at night |

The scene is a mock-up for the art decision. Nothing here is loaded by the game yet.
Snapshots of the output are in `docs/img/art-test/`.
