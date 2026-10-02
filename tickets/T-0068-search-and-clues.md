---
id: T-0068
title: Discoveries - searching places and learning clues
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0067]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Discoveries become playable. Anywhere public you can "Have a look around" (30 minutes); at the
right place and time, with the right clue, you find something. People who trust you enough
share what they know, and notice boards and the like teach clues when you read them.

## Read first
`docs/design/discoveries.md` → The search interaction, Clues and discoveries;
`sim/social/conversations.gd` (how outcomes are resolved), `data/interactions/social.json`.

## Specification (as built)
- **Place interactions**: `"target": "place"`; the target id is the lot the person stands on.
  `Interactions.offered_by_place(sim, person, lot_id)` (only on that lot);
  `QueueInteractionCommand` accepts them; `Requirements`: `no_place`, `closed`, `private`
  (`Lots.may_enter`). `PlaceActions` (`sim/systems/place_actions.gd`) steps them: no walking
  or slot, start where you stand, moving off the lot or walking cancels.
- `search` ("Have a look around", 30 minutes, `data/interactions/discoveries.json`):
  `Discoveries.search(sim, person, place_id)` → "found" (a known clue, eligible now) |
  "clue" (a `clue_required: false` discovery here; any time) | "nothing"; event
  `&"searched" {person_id, place_id, result, discovery_id}`. No rng; id order.
- **Sharing**: after a successful friendly exchange (`Conversations.resolve`), each side tells
  the other the first clue (by id) they know or found and the other doesn't, if their trust
  in the listener reaches `share_trust` (`Discoveries.share_clues`). NPCs too.
- **Reading**: an interaction with `teaches_clue` teaches it when it finishes (source "read",
  source id the object). The notice boards themselves are content: T-0070.
- **Player**: E with nothing in reach (or a click on yourself in command mode) opens the
  place's menu ("Altmarkt · Have a look around"; `PlayerController.place_target`). Notices:
  "You heard something about …", "A lead: something about …", "You found something: …",
  "Nothing here." (`game/ui/phone/notebook_app.gd`).

## Acceptance criteria
- [x] With a clue at the right time and place a search uncovers it; wrong time or place finds
  nothing; without a clue a `clue_required: false` discovery gives its lead →
  `test_search_finds_a_lead_then_the_secret_at_the_right_time`,
  `test_searching_is_an_action_where_you_stand`.
- [x] Walking away stops it; closed or private places can't be searched →
  `test_walking_away_stops_the_search`, `test_closed_and_private_places_cant_be_searched`.
- [x] Trust-gated sharing → `test_people_share_clues_when_they_trust_you`.
- [x] Reading teaches a clue → `test_reading_teaches_a_clue`.
- [x] Save/load mid-search → `test_saving_mid_search_continues_identically`.
- [x] The menu and notices → `test_the_place_menu_offers_a_look_around` (tests/game).

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). The town is unchanged:
nobody knows a clue at the start and NPCs don't search, so no clue spreads until the player
starts one (or T-0070's content gives residents clues). Files: `place_actions.gd`,
`discoveries.gd` (`search`, `share_clues`), `interactions.gd`, `queue_interaction_command.gd`,
`requirements.gd`, `action_system.gd`, `conversations.gd`, `interaction_menu.gd`,
`player_controller.gd`, `hud.gd`, `notebook_app.gd`. Tests: `tests/sim/test_searching.gd` (7)
and one menu test. No screenshot needed beyond the menu; take `out/t0068.png` on the Mac with
E pressed on the Altmarkt if wanted.

## Questions

## Review feedback
