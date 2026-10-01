---
id: T-0069
title: Discoveries - the Notebook app and the map
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0068, T-0063]
builder:
review_rounds: 0
---

## Goal
Your phone gets a Notebook: Leads (clues you know but haven't followed up: the place and the
clue) and Finds (what you uncovered and what it gave you). The town map hides secret places
until you've found them, and marks your finds with a small note icon.

## Read first
`docs/design/discoveries.md` → Events and UI; `game/ui/map_view.gd`, `game/ui/town_map.gd`
(T-0048); the phone (T-0063).

## Design (draft: detailed when its dependencies are merged)
- `game/ui/phone/notebook_app.gd` with pure `lines(sim, player_id)`.
- Places get an optional `"hidden": true` in `district.json`; `MapView` skips hidden places
  unless the player uncovered a discovery there, and draws a note marker for found ones.

## Acceptance (sketch)
- Leads and Finds for a known state; a hidden place appears on the map only after its
  discovery; screenshots of the Notebook and the map.

## Implementation notes

## Questions

## Review feedback
