---
id: T-0071
title: Skills v1 - getting better with practice
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0061, T-0064]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
People get better at things by doing them. Five skills (cooking, charisma, fitness, logic,
handiness) grow in levels 0–10 from practice: cooking at the stove, charisma in
conversations, logic on the laptop, and the job's own skill at work. Skills pay off: better
meals, better conversations, better job performance, and promotions that need a level.

## Read first
`docs/design/people.md` → Skills; T-0061 (performance, promotion), T-0064 (the interview).

## Specification (as built)
- `data/skills.json` → `SkillDef`, `SkillRules` (`max_level` 10, `xp_per_level` 200,
  `work_xp_per_hour` 15, effects: `finish_bonus_per_level` 0.05, `charisma_per_level` 0.08
  (logit), `performance_per_level` 0.2, `interview_per_level` 0.02). `SkillLoader` runs
  before interactions and jobs.
- `Person.skills` (id → XP, saved; v15, migration, fixture). `Skills.level`, `gain` (emits
  `&"skill_up"`), `practise` (each performing minute), `finish_factor`, `text`.
- `InteractionDef.skill_xp`, `finish_skill`: cook_meal (cooking 60/h, finish), browse_web
  (logic 20/h), chat/joke/compliment/flirt (charisma 120/h).
- `JobDef.skill` (every job; work XP each counted minute), `JobLevel.requires` (level n needs
  2n in the job's skill). `Careers.settle` adds performance per level; `Careers.skilled_for`
  gates promotion; `Conversations.acceptance` adds charisma for friendly and romantic moves;
  `Hiring.chance` adds the job's skill.
- Inspector line "Skills: Cooking 3, …"; notice "Cooking skill: level 3".

## Acceptance criteria
- [x] XP and levels from practice and work → `test_levels_from_xp_and_level_up_events`,
  `test_cooking_practice_and_better_meals`, `test_work_trains_the_jobs_skill_and_helps_performance`.
- [x] The effects with exact numbers → the same, plus `test_charisma_helps_conversations_and_interviews`.
- [x] Promotion blocked without the skill → `test_promotion_needs_the_skill`.
- [x] Save round trip → `test_skills_survive_saves`; content → `test_skill_content_loads`.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). `tools/check.sh` passes;
`--check-m2 --check-staffing` pass on seeds 1–6 in both work modes (12 of 12; gentle seed 5,
which failed in T-0065, now passes, because a little charisma helps the quietest residents:
the lone-worker edge is still thin, T-0079). The `repair` interaction for Kaya's workbench is
not added (no handiness use yet besides the builder's job).

## Questions

## Review feedback
