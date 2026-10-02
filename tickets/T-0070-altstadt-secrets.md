---
id: T-0070
title: Discoveries - the first Altstadt secrets
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0069, T-0066]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The Altstadt gets its first eight secrets, written as content (clue lines, places, times,
effects and short scenes): the tram-stop notices, the sublet in Haus 9, the Kneipe's cellar
door, Kaya's workbench, the Waschsalon's back room, the vestry at St. Nikolai, the coins in
the Altmarkt fountain and the dry alcove on the promenade.

## Read first
`docs/design/discoveries.md` → Altstadt v1 content; the content rules in AGENTS.md (D17,
D20); `data/scenes/core.json`.

## Specification (as built)
- `data/discoveries/altstadt.json`: the eight secrets (table in the design doc), with two new
  effect and field types: `clue` {discovery} (a lead to another secret) and
  `known_at_start` (residents or staff of a place know the clue in a new town;
  `Discoveries.seed_clues`, called by `SimFactory.new_game`).
- Hidden places `st_nikolai_vestry` and `uferweg_alcove` in `district.json`; objects
  `notice_case` (tram stop), `service_board` (St. Nikolai), `vestry_chair` (vestry);
  interactions `read_timetable` and `read_service_board` (teach clues), `rest_quietly`
  (requires the vestry), `sleep_in_the_alcove` (a place interaction limited to the alcove by
  the new `InteractionDef.places`, requires the alcove); moodlet `quiet_moment`; scenes
  `the_cellar_door` and `coins_at_night`.
- `spati_workbench` gives a contact and a note; its `repair` unlock waits for handiness.

## Acceptance criteria
- [x] All eight load and validate → `test_all_eight_secrets_load`.
- [x] Each one from a new game: the intended clue route, the wrong time where it matters, the
  find and its effects → one test per secret in `tests/sim/test_altstadt_secrets.gd`, plus
  `test_locals_know_their_secrets_from_the_start`.
- [x] A 7-day run changes nothing for the economy except finds: NPCs share clues but never
  search, and nothing new draws random numbers; `--check-m2 --check-staffing` pass on seeds
  1–3 (meals 592/564/516, as before).
- [ ] Screenshot of a scene (`the_cellar_door` after searching the Kneipe with the clue): on
  the Mac.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). Two new places get lots
in old saves on load (`Lots.create_from_content(only_missing)`), so nothing else is needed for
them; old saves' residents know no clues (seeding is for new towns). Two older tests changed
with the rules: the map labels test now skips secret places, and the v11 fixture test checks
ids continue after the café counter instead of the exact next id (the new lots take ids too).
All clue and scene text follows the content rules.

## Questions

## Review feedback
