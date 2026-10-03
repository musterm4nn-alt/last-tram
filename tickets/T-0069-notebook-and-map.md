---
id: T-0069
title: Discoveries - the Notebook app and the map
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0068, T-0063]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Your phone gets a Notebook: Leads (clues you know but haven't followed up: the place and the
clue) and Finds (what you uncovered and what it gave you). The town map hides secret places
until you've found them, and marks your finds with a small note icon.

## Read first
`docs/design/discoveries.md` → Events and UI; `game/ui/map_view.gd`, `game/ui/town_map.gd`
(T-0048); the phone (T-0063).

## Specification (as built)
- `game/ui/phone/notebook_app.gd`: `lines(sim, player_id)` ("Leads": place and clue per known
  clue; "Finds": name (place) and what each effect gave), `effect_text`. Phone app "Notebook".
- `PlaceDef.hidden` (`"hidden": true` in `district.json`); `Discoveries.found_places`.
  `MapView.labels(content, level, found)` leaves hidden places out unless found, and marks
  found places ("✎"); the HUD place line says "Altstadt" and the place menu "Here" in a
  secret place you haven't found.

## Acceptance criteria
- [x] Leads and Finds → `test_notebook_lists_leads_and_finds`.
- [x] A hidden place is off the map and unnamed until found, then marked →
  `test_hidden_places_appear_once_found`.
- [x] Screenshots of the Notebook and the map (taken 3 October under a virtual display: `out/t0069-notebook.png`, `out/t0069-map.png`).

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). No place is hidden yet:
the hidden places (vestry, alcove) come with T-0070's content; the tests hide the Altmarkt
in a copy of the content. Screenshots to take on the Mac: `P` → Notebook after finding the
fountain coins, and the town map (`M`).

## Questions

## Review feedback
