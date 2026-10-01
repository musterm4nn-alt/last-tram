---
id: T-0068
title: Discoveries - searching places and learning clues
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0067]
builder:
review_rounds: 0
---

## Goal
Discoveries become playable. Anywhere public you can "Have a look around" (30 minutes); at the
right place and time, with the right clue, you find something. People who trust you enough
share what they know, and notice boards and the like teach clues when you read them.

## Read first
`docs/design/discoveries.md` → The search interaction, Clues and discoveries;
`sim/social/conversations.gd` (how outcomes are resolved), `data/interactions/social.json`.

## Design (draft: detailed when its dependencies are merged)
- `search` as a place-level offer: decide how the menu offers it (a lot-level entry when you
  click the ground in command mode or press E with nothing in front of you), and how the action
  system runs an action with no object (target "place"). Resolution as in the design: uncover
  a known, eligible clue; else learn the local clue if `clue_required` is false; else a
  "nothing here" line and a small comfort gain. No rng.
- Sharing: a friendly conversation shares one clue the speaker knows and the listener doesn't,
  when the speaker's trust in the listener reaches the discovery's `share_trust`
  (deterministic order). NPCs pass clues to each other the same way.
- Clue objects: a `notice_board` (at the tram stop, St. Nikolai) with "Read the notice board";
  `InteractionDef.teaches_clue`.
- HUD notices: "You heard something about the Kneipe" / "You found something".

## Acceptance (sketch)
- Search with a clue at the right time uncovers it; the wrong time or place finds nothing;
  without a clue, a `clue_required: false` discovery teaches its clue; trust-gated sharing;
  reading a notice board teaches a clue. Save/load in the middle of a search.

## Implementation notes

## Questions

## Review feedback
