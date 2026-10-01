---
id: T-0037
title: Relationships, memories and moodlets
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0034]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Each person keeps a directed relationship with everyone they've met (familiarity, friendship,
romance, trust, fear), a capped list of memories, and moodlets that shift their mood for a
while. Relationships drift towards neutral without contact; memories fade. Couples and
flatmates start out knowing each other. Mood can now rise above "Fine".

## Scope
Create `sim/social/` (`relationship.gd`, `memory.gd`, `moodlet.gd`, `social.gd`),
`sim/systems/social_system.gd`, `sim/content/moodlet_def.gd`, `moodlet_loader.gd`,
`data/moodlets.json`, `tests/sim/test_relationships.gd`. Change `sim/people/person.gd`,
`sim/people/mood.gd`, `sim/content/content_db.gd`, the interaction def and loader
(`finish_moodlet`), the interactions data, `sim/systems/action_system.gd`, `sim/sim.gd`,
`sim/people/resident_generator.gd`, `sim/save/save_person_validator.gd`,
`tests/sim/test_needs.gd` (labels).
**Out of scope:** social interactions that change these (T-0038), gossip, the inspector (T-0041).

## Specification
- `Relationship` (directed; values clamped: familiarity 0..100, friendship −100..100,
  romance 0..100, trust −100..100, fear 0..100; `last_contact_tick`),
  `Person.relationships: Dictionary[int, Relationship]`, saved sorted by other id.
- `Memory` (tick, kind, subject_ids, place_id, valence −100..100, salience 0..100, source
  experienced/witnessed/heard, source_id); `Person.memories`, capped at 60 (least salient
  forgotten).
- `Moodlet` (id, ends_tick) on `Person.moodlets`; `MoodletDef` from `data/moodlets.json`
  (value −100..100, duration_hours). Interactions may name a `finish_moodlet`.
- `Social` API: `relationship`, `relationship_or_new`, `change` (clamped, marks contact,
  emits `relationship_changed`), `set_values`, `remember` (emits `memory_added`),
  `memories_about`, `add_moodlet` (restarts an existing one; emits `moodlet_added`),
  `moodlet_total`.
- `SocialSystem`: ends moodlets each minute. At midnight, relationships quiet for 2+ days drift
  towards 0 (friendship, trust, romance 1/day, fear 2/day, familiarity 0.5/day but not below
  20 once above it), and memories lose 5 salience a day.
- Mood = needs part + moodlets. Labels: Great ≥ 50, Happy ≥ 35, Fine ≥ 20, Okay ≥ 0, Uneasy
  ≥ −40, else Miserable.
- New game: couples (familiarity 90, friendship 60, romance 70, trust 60) and flatmates
  (70, 30, –, 25) know each other.

## Acceptance criteria (`tests/sim/test_relationships.gd`)
- [x] Relationships are directed and clamped; households start out knowing each other.
- [x] Drift after quiet days, none with recent contact.
- [x] Memories are capped (the weakest go first) and fade away.
- [x] Moodlets add to mood, restart instead of stacking, and end; a meal gives "good meal".
- [x] Everything survives save/load; old saves load empty; bad values are rejected.
- [x] `tools/check.sh` passes.

## Implementation notes
- Finish moodlets: sleep "slept well" +10, cook "good meal" +6, shower "fresh" +5, drink
  "good night out" +12, coffee +5, bench "fresh air" +6. Social ones (laugh, flattered,
  insulted, argued, awkward, rejected, good talk) are defined for T-0038.
- `test_needs.gd`: `Mood.label(100)` is now "Great" (it was capped at "Fine" by M1 design);
  the test checks the new labels.
- Verified: `tools/check.sh` 422 passed, 0 failed. `tools/simrun.sh --days=2`: the player is
  "Happy" (35) on Tuesday and Wednesday mornings. 0.081 ms per step.

## Questions

## Review feedback
