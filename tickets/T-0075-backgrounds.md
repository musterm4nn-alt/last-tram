---
id: T-0075
title: Backgrounds in the character creator
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0071]
builder: Claude Code / Opus 5.5
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

## Specification (as built)
- `data/backgrounds.json` → `BackgroundDef` (`BackgroundLoader`, after jobs, skills and
  moodlets): cash, bank, job, skills (levels), knows, moodlet, record; `default`
  "newcomer". Newcomer = the old start (€40 cash, €300 bank, office clerk), so default games
  are unchanged; Local (warehouse, knows 5), Student (no job, logic 3, knows 2), Ex-con (no
  job, €15, a record, "A fresh start"), Burnout (no job, €1,250, logic 3, charisma 2, "Burned
  out"). `economy.json` `player_start` and `player_job` are gone.
- `CharacterSpec.background` (validated; "" = default). `SimFactory.new_game` passes the
  background's job to `Jobs.fill_at_start` and its money to `Money.give_start`, then
  `Backgrounds.apply` (skills as XP, the first `knows` other residents of a shuffled list from
  the "background" stream become acquaintances both ways, the moodlet, `Person.origin`,
  `Person.record`; save v19).
- The creator's Background tab (`CreatorBackgroundTab`): a button per background with its
  line ("… · €340.00 · Office clerk"); Randomise picks one.

## Acceptance criteria
- [x] Each background gives exactly its data → `test_each_background_gives_exactly_its_data`.
- [x] Local knows neighbours (both ways) → the same test (`knows`).
- [x] The tab → `test_the_background_line`, `test_randomising_a_section_leaves_the_others_alone`
  (now with "background").
- [ ] Screenshot of the tab: on the Mac (`tools/screenshot.sh out/t0075.png --screen=creator`
  then the Background tab).

## Implementation notes
Built and self-reviewed by Opus in a cloud session (3 October 2026). The golden
"randomise everything" test now drops "background" like it drops "personality" (both were
added after it was recorded and are drawn last). Residents still all start the same way.

## Questions

## Review feedback
