---
id: T-0051
title: Saves keep every number exactly
status: done
milestone: M2
size: S
owner: architect
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Found while building T-0034: with 30 residents, "save mid-run and continue = uninterrupted
run" failed. Godot's JSON parser reads about one float in ten back a little off (the last
digit or two), at any number of written digits. Saves, bug reports and replays must restore
every float exactly (golden rule 5, D26).

## Scope
`sim/core/ser.gd` (`to_json`, `parse_json`, `exact_floats`, `restore_floats`), every place
that reads save or command-log JSON (`SaveCodec.from_json`, `SaveSlots`, `Replay.compare`,
`tools/replay_files.gd`), `docs/architecture.md`, `docs/decisions.md` (D26).
Create `tests/sim/test_exact_save_numbers.gd`.

## Specification
`Ser.to_json` writes a float as a plain number when JSON reads it back unchanged, otherwise
as `"#f64:"` + the 16 hex digits of its 8 little-endian bytes. `Ser.parse_json(json, text)`
parses like `JSON.parse` and turns those strings back into floats. Old saves (plain numbers)
load as before; no version bump.

## Acceptance criteria
- [x] 5,000 random floats round-trip exactly; plain JSON demonstrably loses some →
  `test_exact_save_numbers.gd`.
- [x] Simple numbers stay readable; other strings are untouched.
- [x] A save with awkward needs and position loads exactly.
- [x] `tools/check.sh` passes (old fixtures still load).

## Implementation notes
- Measured: 9,461 of 100,000 random floats come back different through
  `JSON.stringify(full_precision) → JSON.parse`. `String.num` with 15–20 decimals and
  `num_scientific` lose 14–35% (the parser is the limit, not the digits).
- `_reads_back` checks each float with the real parser, so only floats that need it are
  written as hex (simple values like 0.5, 4.5 and 80.0 stay plain).
- Verified: `tools/check.sh` 390 passed, 0 failed.

## Questions

## Review feedback
