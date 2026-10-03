---
id: T-0088
title: Route B is the game's look (the art gate's pick)
status: done
milestone: Art
size: S
owner: builder
depends_on: [T-0080, T-0084]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The owner picked route B, with PixelLab for people and objects (3 October, D35). Bring route
B's art set into `main` and make it what the game draws by default, so the desktop icon shows
the new look.

## Scope
The `art/custom` branch (route B: `art/src/custom/`, `art/export/custom/`,
`data/art2d/custom.json`), `game/launch_options.gd`, `game/main.gd` (doc comment),
`tools/art_shots.sh`, their tests, and the docs that record the pick (`docs/decisions.md`
D35, `docs/art.md`, `docs/roadmap.md`, `docs/vision.md`, `data/art2d/README.md`). **Out of
scope:** PixelLab art (stays on `art/pixellab-test` until character production is planned),
any new art.

## Specification
- `LaunchOptions.DEFAULT_ART = "custom"`; `LaunchOptions.art` starts at it. `--art=placeholder`
  sets `art` to "" (the placeholders).
- `tools/art_shots.sh placeholder` (any set without a file) passes `--art=placeholder`.

## Acceptance criteria
- [x] Route B by default, placeholders on request → `test_launch_options.gd: test_art_option`
- [x] The default set loads without errors and draws every terrain and object of the art
  gate's scene → `test_art_set.gd: test_default_set_covers_the_scene`
- [x] Screenshot `out/t0088.png` (a plain launch, no `--art`): route B

## Implementation notes
Built by the architect right after the owner's pick. Route B merged as it was on `art/custom`
(one commit, e564dea). The old default assertion ("placeholders by default") changed with the
spec, not weakened. Checked: `tools/check.sh` passes; `tools/screenshot.sh out/t0088.png
--hide-hud --zoom=2` shows route B's tiles, objects and roofs.
