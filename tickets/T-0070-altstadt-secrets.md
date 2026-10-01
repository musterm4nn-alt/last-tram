---
id: T-0070
title: Discoveries - the first Altstadt secrets
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0069, T-0066]
builder:
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

## Design (draft: detailed when its dependencies are merged)
- `data/discoveries/altstadt.json` and scenes; any new places (the promenade alcove, a
  hidden vestry) in `district.json` (hidden where the design says so).
- `unlock_interaction` targets that exist by then: a quiet `sit` spot (vestry), `sleep_rough`
  at the alcove (T-0066), and `repair` waits for handiness (T-0071).
- A headless check: every discovery can be uncovered from a new game (a scripted route per
  discovery in a test).

## Acceptance (sketch)
- All eight load and validate; each one's test walks a person through learning the clue and
  uncovering it; a 7-day run with the player idle changes nothing for the economy except
  finds. Screenshot of a scene.

## Implementation notes

## Questions

## Review feedback
