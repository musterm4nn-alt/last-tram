---
id: T-0067
title: Discoveries - data and sim plumbing
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0055]
builder: Claude Code / Opus 5.5
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

## Specification (as built)
- `data/discoveries/*.json` → `DiscoveryDef` + `DiscoveryEffect` (`DiscoveryLoader`, after
  jobs): `id`, `name`, `clue`, `place_id`, `from`/`to` ("HH:MM"), `level` (must be the
  place's), `clue_required`, `share_trust` (−1 or 0..100), `effects` (note {text}, money
  {cents}, moodlet {moodlet}, contact {place_id}, unlock_interaction {interaction}), `scene`.
  `check_links`: interactions' `requires_discovery`/`teaches_clue` name real discoveries; an
  unlock names an interaction that requires that discovery; a clue-only discovery is shared
  or taught.
- `Person.known_clues`, `Person.discoveries`, `World.looted_discoveries` (sorted; unknown ids
  dropped on load). Save v14, migration, fixture `v14_basic.json`.
- `Discoveries`: `eligible`, `learn_clue`, `uncover` (effects, memory of kind = the id,
  scene for the player, events), `people_of`. `InteractionDef.requires_discovery` /
  `teaches_clue`; `Requirements` `unknown_secret` (hidden).
- One discovery in the data: `fountain_coins` (Altmarkt, 22:00–04:00, €3.40 once).

## Acceptance criteria
- [x] Validation → `test_broken_discoveries_are_reported`, `test_discovery_content_loads`.
- [x] Learn and uncover with effects, memory and events → `test_learn_and_uncover`,
  `test_eligibility_and_effects`.
- [x] Money once across two people → `test_money_only_once_per_world`.
- [x] Secret interactions hidden until found → `test_secret_interactions_need_the_discovery`.
- [x] Save round trip, dropped ids, migration → `test_discoveries_survive_saves`; fixtures load.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). Nothing in the game
uses discoveries yet (searching comes with T-0068), so play is unchanged. Contact effects
raise familiarity to 30 with everyone who lives or works at the place (the phone lists people
from 30). A missing `data/discoveries/` folder means no discoveries, so content packs and the
broken-content fixtures don't need one. Tests: `tests/sim/test_discoveries.gd` (7).

## Questions

## Review feedback
