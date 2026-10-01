---
id: T-0075
title: Backgrounds in the character creator
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0071]
builder:
review_rounds: 0
---

## Goal
You choose where your life starts. In the creator, pick a background: Newcomer (some savings,
knows nobody), Local (knows a few neighbours, modest savings), Student (a cheap life, little
money, logic skill), Ex-con (almost no money; the record matters in M4) or Burnout (savings,
stress, office skills). It sets your starting money, job, skills and contacts.

## Read first
`docs/design/character-and-appearance.md` → Backgrounds; `sim/people/character_spec.gd`,
`game/ui/character_creator.gd`; T-0054 (starting money), T-0058 (`player_job`), T-0071
(skills).

## Design (draft: detailed when its dependencies are merged)
- `data/backgrounds.json` (`BackgroundDef`): money (cash, bank), job (or none), skills,
  `knows` (how many neighbours start as acquaintances), a moodlet, and `record` (saved for M4).
- `CharacterSpec.background` (validated); `SimFactory.new_game` applies it instead of
  `player_start` and `player_job`.
- A Background tab in the creator, with one line describing each background.

## Acceptance (sketch)
- Each background gives exactly its data; Local knows neighbours from the start; the creator
  tab; a screenshot.

## Implementation notes

## Questions

## Review feedback
