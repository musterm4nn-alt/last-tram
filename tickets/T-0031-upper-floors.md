---
id: T-0031
title: Upper floors: flats above the shops for about 30 residents
status: draft
milestone: M2
size: M
owner: builder
depends_on: [T-0030, T-0032]
builder:
review_rounds: 0
---

## Goal
Haus 3, Haus 12 and the Altbau fronts get level 1 and 2 maps with stairwells and 12–14 small flats (each a `home` place/lot), so ~30 residents can live in Altstadt. Command mode pages floors with Page Up/Down; the view follows the player's floor.

## Notes for the architect (to detail before this becomes todo)
- Design the floor plans in `level_1.txt`/`level_2.txt` (same size as level 0; void outside buildings) and verify with a scratch script like T-0011's: every flat reachable from the street by stairs, no content errors.
- Flats: 1–2 rooms, bed + fridge + stove + sink/shower minimum (objects.json).
- Screenshot each floor with a `--level=N` launch option.

## Implementation notes

## Questions

## Review feedback
