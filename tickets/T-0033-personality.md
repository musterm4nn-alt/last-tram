---
id: T-0033
title: Personality - seven axes on every person
status: done
milestone: M2
size: S
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Every person has a personality: kindness, honesty, sociability, ambition, temper, vice and
bravery, each −100..+100. It is saved, random for generated people, neutral for the default
player, and ready for autonomy and social outcomes to use. (Choosing it in the creator is
T-0044.)

## Read first
- `docs/design/people.md` → "Personality (M2)"
- As merged: `sim/people/person.gd`, `sim/people/character_spec.gd` (`random`, `apply_to`,
  `to_dict`/`from_dict`)

## Scope
Create `sim/people/personality.gd` (`Personality`), `tests/sim/test_personality.gd`. Change
`sim/people/person.gd`, `sim/people/character_spec.gd`.
**Out of scope:** using it in scoring (T-0036, T-0038), the creator (T-0044), traits.

## Specification
- `Personality` (RefCounted): `const AXES: PackedStringArray = ["kindness", "honesty",
  "sociability", "ambition", "temper", "vice", "bravery"]`; `var values: Dictionary[String,
  int]` (every axis, clamped −100..100); `get_axis(id)`, `set_axis(id, v)`, `copy()`,
  `to_dict()`, `static from_dict(d)` (missing axes → 0), `static random(rng)` (each axis the
  sum of two `randi_range(-50, 50)`, so most people are moderate).
- `Person.personality` (saved; old saves → all 0). `CharacterSpec.personality` (default all
  0; `random()` draws it after the outfit, so earlier random draws don't change; `apply_to`
  copies it; `to_dict`/`from_dict` with default).

## Acceptance criteria (`tests/sim/test_personality.gd`)
- [x] Random personalities stay within −100..100 and cluster near 0 (over 1000 draws most
  axes are within ±50); the same seed gives the same personality.
- [x] `CharacterSpec.random` for an existing seed keeps its name, look and outfit (the
  personality is drawn last).
- [x] Person and CharacterSpec round-trip the personality; an old save loads with zeros.
- [x] `tools/check.sh` passes.

## Implementation notes
- `sim/people/personality.gd` as specified (`AXES`, `values`, `get_axis`, `set_axis` with
  clamping, `copy`, `to_dict`, `from_dict`, `random`), plus `MIN_VALUE`/`MAX_VALUE`.
- `Person.personality` and `CharacterSpec.personality` (saved; missing → neutral).
  `CharacterSpec.random` draws it last; `apply_to` copies it.
- Save validation: each known axis present in a saved personality must be an integer in
  −100..100 (`save_person_validator.gd`). Unknown keys are ignored, as `from_dict` does.
- The "earlier draws unchanged" proof is a golden test: `CharacterSpec.random` output for
  seeds 1234 and 7, recorded from main before this change in a throwaway worktree.
- Verified: `tools/check.sh` 355 passed, 0 failed (`test_personality.gd`, 8 tests). Over 1000
  random people, about 75% of axis values are within ±50, as the two-draw sum predicts.

## Questions

## Review feedback
