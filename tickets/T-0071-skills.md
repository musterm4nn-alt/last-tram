---
id: T-0071
title: Skills v1 - getting better with practice
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0061, T-0064]
builder:
review_rounds: 0
---

## Goal
People get better at things by doing them. Five skills (cooking, charisma, fitness, logic,
handiness) grow in levels 0–10 from practice: cooking at the stove, charisma in
conversations, logic on the laptop, and the job's own skill at work. Skills pay off: better
meals, better conversations, better job performance, and promotions that need a level.

## Read first
`docs/design/people.md` → Skills; T-0061 (performance, promotion), T-0064 (the interview).

## Design (draft: detailed when its dependencies are merged)
- `data/skills.json` (`SkillDef`: id, name, xp per level), `Person.skills` (id → xp, saved,
  a version bump), `Skills.level(person, id)`.
- `InteractionDef.skill_xp` ({skill: xp per hour}); `JobDef.skill` (gained at work, adds to
  performance); job levels' `requires` ({skill: level}) gate promotion.
- Effects: cooking adds to `cook_meal`'s hunger gain; charisma to social success odds;
  presentation and charisma to the interview.
- The inspector lists skills ≥ 1; a level-up gives a notice.

## Acceptance (sketch)
- XP and levels from practice and work; the effects with exact numbers; promotion blocked
  without the skill; save round trip.

## Implementation notes

## Questions

## Review feedback
