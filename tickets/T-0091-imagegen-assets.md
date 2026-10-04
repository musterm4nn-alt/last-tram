---
id: T-0091
title: Try the owner's Imagegen environment and walking assets in game
status: review
milestone: Art
size: M
owner: builder
depends_on: [T-0080, T-0084]
builder: Codex
review_rounds: 0
---

## Goal
The owner supplied generated environment and walking sheets and explicitly asked Codex to
try them in the game. Add a selectable `imagegen` art set and show the actual game with it.
The owner's direct request authorizes this art integration despite the normal art-owner
restriction. The artwork comes from the image generation tool; no JavaScript draws assets.

## Read first
`data/art2d/README.md`, `docs/art.md`, `docs/conventions.md`, `docs/cookbook.md`.

## Scope
- Copy the generated PNGs and their provenance into `art/export/imagegen/` and
  `art/src/imagegen/`; add `data/art2d/imagegen.json`.
- View-only support for high-resolution source regions, logical object sizes, and
  four-direction character frames. Cache 16-pixel terrain textures in memory; preserve
  the generated source PNGs.
- Connect walking poses to actual movement, running and pause; retain the player marker.
- Document and test the mapping, then inspect day/night, interiors and walking in game.
- No simulation, save, appearance-data or default-art changes.

## Acceptance criteria
- [x] The set loads without errors and covers all 27 object types and visible terrain.
- [x] Terrain regions are adapted to 16-pixel tiles; the plaza fountain uses four quadrants.
- [x] All four characters have four walk phases in all four directions.
- [x] Stopped/blocked people use a resting phase, running advances faster, and pause freezes
  the current pose without changing simulation state.
- [x] Existing art sets and their fallbacks still load and render.
- [x] `tools/check.sh` passes; screenshots are opened and inspected; the trial can be launched.

## Implementation notes

- Added `data/art2d/imagegen.json`: 18 visible terrain types, all 27 map-object definitions,
  and 64 walking frames across the player and three stable NPC designs. Nine PNGs copied
  from the owner's generated pack are byte-for-byte unchanged (SHA-256 checked).
- `SourceTiles2D` samples native source regions into cached 16-pixel textures in memory.
  Alpha grounds are composed from the generated terrain sheet; the fountain is one 32-pixel
  image split across its four map cells. Original prompts and mappings live in
  `art/src/imagegen/`.
- `ArtSet` and `ObjectView2D` accept logical drawing sizes, retaining footprint anchoring
  while sampling the raw, high-resolution sheets. `CharacterSprites2D` validates and
  selects frames; `WalkPose2D` advances only for actual displacement and respects running,
  simulation speed and pause. `PersonView2D` keeps the existing player marker and falls
  back to the appearance-based drawer for existing art sets.
- Validation: `tools/check.sh --filter=imagegen`: 11 passed; full `tools/check.sh`:
  **737 passed, 0 failed**, including architecture lint. `git diff --check` passed.
- Rendered and opened the fixed art-gate noon/night and close views, the player's flat,
  and live movement screenshots using `tools/screenshot.sh` / `tools/art_shots.sh`.
  The native game was also launched with `--art=imagegen`. Output screenshots and a
  one-click launcher are in the requesting Codex chat's
  `/Users/xamxim/Documents/Codex/2026-10-04/usi/outputs/`.
- Limits: this is an optional visual trial, selected with `--art=imagegen`; fixed generated
  character designs do not reflect clothing or appearance customization. Missing custom
  roof art uses the game's existing shingles. Several object rotations reuse a supplied
  view where the generated pack has no distinct side view. The standard `custom` set,
  simulation, saves and project settings are unchanged.

## Questions

## Review feedback
