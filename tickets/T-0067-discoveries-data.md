---
id: T-0067
title: Discoveries - data and sim plumbing
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0055]
builder:
review_rounds: 0
---

## Goal
The foundation for the town's secrets (the owner's idea, `docs/design/discoveries.md`).
Discoveries become content: a clue to learn, a place, a time window, and effects when
uncovered. Each person remembers which clues they know and what they've found; a few rewards
(a stash of money) can only be taken once per world. Nothing in the game uses it yet
(T-0068).

## Read first
`docs/design/discoveries.md` (Clues and discoveries, Data, Effects, Tests), D29 (no `item`
effect in M3), the cookbook's "Add a new kind of content" and "Change the save format".

## Design (draft: detailed when its dependencies are merged)
- `data/discoveries/*.json` → `DiscoveryDef` (`DiscoveryLoader`): `id`, `name`, `clue`,
  `place_id`, `from`/`to` (game minutes; wrap past midnight), `level`, `clue_required`,
  `share_trust` (−1 = never shared), `effects` [{`kind`: note | money | moodlet | contact |
  unlock_interaction, plus its value}], optional `scene` (a presentation).
- `Person.known_clues` and `Person.discoveries` (`PackedStringArray`, kept sorted); the
  world-once set `World.looted_discoveries`. `from_dict` drops ids content no longer has.
  A save version bump, migration and fixture.
- `Discoveries` (`sim/discoveries/discoveries.gd`, static): `learn_clue(sim, person, id,
  source, source_id)`, `uncover(sim, person, id)` (applies the effects: money through
  `Money.earn(…, "found", CASH, id)` only once per world, a moodlet, a contact, a note, an
  unlocked interaction; writes a memory; emits `clue_learned` / `discovery_uncovered`).
- `InteractionDef.requires_discovery`; `Requirements` adds `unknown_secret` (hidden from the
  menu).
- One test discovery in the data (the real Altstadt content is T-0070).

## Acceptance (sketch)
- Validation (place ids, time windows, effect kinds, `requires_discovery` ids, every
  `clue_required` discovery has a clue source); learn and uncover with their effects, memory
  and events; money only once across two people; the save round trip and the old-save
  migration.

## Implementation notes

## Questions

## Review feedback
