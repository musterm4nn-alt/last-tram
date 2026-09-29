---
id: T-0033
title: Personality - seven axes on every person
status: todo
milestone: M2
size: S
owner: builder
depends_on: []
builder:
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
- [ ] Random personalities stay within −100..100 and cluster near 0 (over 1000 draws most
  axes are within ±50); the same seed gives the same personality.
- [ ] `CharacterSpec.random` for an existing seed keeps its name, look and outfit (the
  personality is drawn last).
- [ ] Person and CharacterSpec round-trip the personality; an old save loads with zeros.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
