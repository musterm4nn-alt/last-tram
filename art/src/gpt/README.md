# Last Tram — Altstadt art kit

Original pixel art drawn entirely in JavaScript, following the supplied Route B art brief.

## View the art

Requires Node.js 18 or newer. There are no packages to install.

```sh
npm run dev
```

Open `http://localhost:3000` in a browser. The viewer opens directly on Altmarkt, with a yellow tram, shops, a fountain and a furnished cutaway of Haus 12.

- **Altmarkt / Haus 12 / Asset catalog** switch between the town, the larger apartment study and the first asset set.
- **Day / Night** applies the scene's blue tint and warm light pools. Exported asset sheets stay in daylight colours.
- **Roof** covers Haus 12 with a seamless terracotta roof.
- **Pause** stops the ambient residents and tram. Reduced-motion preferences pause them by default.
- **WASD / arrow keys** walk the selected adult resident. Focus the scene first. This is an art preview, not a complete life sim.
- **Click an object** to inspect its sprite and footprint.
- **Zoom** supports nearest-neighbour 1×, 2×, 3×, 4× and 6×. Fit selects a whole-number scale. Smaller screens can scroll inside the scene to pan.
- **Grid** overlays the 16-pixel tile grid. **Save PNG** downloads the current scene at 2× without the grid or interface.
- **Resident / Shuffle appearance** changes the player using the same layered character generator.
- **Download art kit** downloads the packaged source, asset sheets and previews.

## Files

| File | Contents |
| --- | --- |
| `assets/terrain.png` | 19 terrain/building tile types, 3 variants each, plus a 16-tile cobble/grass corner set |
| `assets/objects.png` | All 27 requested objects in 4 directions, plus 7 original scene props |
| `assets/characters.png` | 9 clothed adults, each in 4 directions; one idle and four walk frames |
| `assets/character-layers.png` | 13 compatible layers for the reference player, with the same animation layout |
| `assets/art.json` | Sheet coordinates, object footprints, rotation order, animation layout, layer order and available character options |
| `previews/` | Town and flat, by day and night, at native and 2× scale; asset catalog |
| `src/` | Editable generators, scene composition and browser viewer |
| `docs/ART_BRIEF.md` | A copy of the supplied art guidelines |

## Regenerate and check

```sh
npm run build
npm run check
npm run package
```

The exporter and packager use small native JavaScript PNG and ZIP encoders and Node's built-in zlib. No Canvas, image service, browser, or third-party library is required to regenerate the assets or package them.

The checks read the actual exported PNGs, validate their CRCs, palette, transparency, mapping bounds and alignment, compare exports with the generator, and exercise all character options across builds, heights and skin tones.

## Use in the game

`terrain[id].cell` uses 16-pixel tile coordinates. `variants` continues to the right. The top-level `roof` is mapped separately as in the brief. Object `rects` contain exactly four `[x, y, width, height]` pixel rectangles in **down, left, up, right** order. Place a sprite's bottom centre on the footprint's bottom centre. For side-facing objects, swap the footprint's width and height.

Each resident occupies an 80 × 128 block on the character sheet. Columns are idle, walk 0, walk 1, walk 2, walk 3; rows are down, left, up, right. Feet are anchored at `[8, 32]` relative to a 16 × 32 frame. Walk playback is 6 frames per second.

The supplied layer sheet is one reference configuration, not an exhaustive atlas of every possible person. `characterLayers(config, direction, frame, walking)` in `src/characters.js` produces compatible layers for any supported combination of 5 builds, 3 heights, 8 skin tones, 15 hair styles, 15 hair colours, facial features and all clothing slots. `character()` composites those layers. Clothes use configurable colour indices rather than fixed asset recolouring. Keep `layerOrder` when compositing. All base layers wear an undershirt and shorts, and the composed residents remain clothed.

The view draws full faces only for northern interior walls. Side and southern walls use a six-pixel band, with glass strips or doorway gaps. The larger flat includes collision gaps for its doors. The roof demonstration is an explicit viewer control; game-side room detection and automatic roof hiding still belong to the game.

This first set includes idle and walking; sitting, sleeping, using and fighting animations, optional portraits and other terrain transition sets remain future work, as allowed by the brief. Actual integration into a game's engine has not been performed.
