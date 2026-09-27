---
id: T-0008
title: Needs panel and current action in the HUD
status: draft
milestone: M1
size: S
owner: builder
depends_on: [T-0005, T-0006]
builder:
review_rounds: 0
---

## Goal
The player sees their seven needs as bars (with a mood label), and what they're doing right now with its progress.

## Notes for the architect (to detail before this becomes todo)
- `game/ui/needs_panel.gd` bottom-left, built in code; colours green → yellow → red by value; mood label from `Mood.label()`.
- Current action line: interaction name + progress (minutes_done / duration, or the need value for until_need).
- Screenshot criteria at zoom 3, with an advanced clock (`--advance=240`) so bars differ.

## Implementation notes

## Questions

## Review feedback
