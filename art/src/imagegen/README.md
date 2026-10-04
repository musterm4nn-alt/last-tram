# Owner-requested Imagegen trial

The owner requested these assets with the built-in image generation tool in Codex, then
supplied this repository and asked to try them in the game. This direct request authorizes
the integration despite the repository's usual assignment of art work to Opus.

Nine original 1254 × 1254 PNG sheets live under `art/export/imagegen/`. They are copied
unchanged from the generated pack. `generation-prompts.json` contains the exact nine
prompts; the other JSON files preserve the original pack mappings and verification.

`data/art2d/imagegen.json` adapts the source regions to Godot: cached 16-pixel terrain,
logical prop sizes, and aligned character frame rectangles. Godot performs the display
resampling in memory. No JavaScript or Python draws or edits the artwork.

Run `tools/run.sh --art=imagegen --quickstart` for the visual trial. The character sheets
are four fixed designs with four-direction walks; appearance customization still uses
the existing layered/procedural system outside this art trial.
