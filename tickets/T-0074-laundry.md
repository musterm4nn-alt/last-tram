---
id: T-0074
title: Dirty clothes and the Waschsalon
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0072, T-0064]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Clothes get dirty as you wear them, faster at work, and dirty clothes make you feel and look
worse. Washing machines at Waschsalon Blitz clean your whole wardrobe for a few euros. How you
look ("presentation": hygiene, clean clothes, an outfit that fits the place) now affects job
interviews.

## Read first
`docs/design/character-and-appearance.md` → Presentation; T-0064 (the interview), T-0072 (the
wardrobe).

## Specification (as built)
- `Person.dirt` ("item:colour" → 0..100, saved; v18). `Laundry` (`sim/people/laundry.gd`):
  worn pieces get `dirt_per_hour` (0.5) dirtier per waking hour, plus `work_dirt_per_hour`
  (0.5) at work (`NeedsSystem` calls `Laundry.minute`); from `dirty_at` (60) the clothes cost
  `hygiene_per_hour` (1.0) and renew the `dirty_clothes` moodlet (−8) on the hour.
  `economy.json` "laundry".
- Four `washing_machine`s at Waschsalon Blitz; `wash_clothes` (€4, 60 min, `launders`:
  everything owned is clean; moodlet `clean_laundry`). With dirty clothes a wash is an errand
  (`Autonomy.errand`) worth `errand_score` (12).
- `Presentation.of(sim, person, formality)`: (hygiene − 50) / 200 − worn dirt / 250 − 0.1 ×
  formality mismatch; `Hiring.chance` uses it (the old hygiene and dress terms, plus dirt).
- Found on the way, fixed in the game: in the background tier, starting, walking and
  conversations now step every step (`ActionSystem._minute_paced`); at a minute per
  transition background towns talked a quarter less, and `test_tiered_and_full_towns_live_
  the_same_lives` failed once the town re-rolled. A lunch break now also gives
  `lunch_fun` (10): desk workers came home at fun 2 (`test_lunch_at_work_is_a_meal`).
- `SaveMigrations` was over 350 lines: the M3 steps (v12–v18) moved unchanged into
  `SaveMigrationsM3`.

## Acceptance criteria
- [x] Dirt rises (faster at work) and washing resets it → `test_worn_clothes_get_dirty_faster_at_work`,
  `test_washing_cleans_everything_for_four_euros`.
- [x] The moodlet and the hygiene cost → `test_dirty_clothes_show_and_cost_hygiene`.
- [x] Presentation with exact numbers → `test_presentation_counts_at_interviews`.
- [x] Residents visit the Waschsalon in a 7-day run: 6–12 washes a week on seeds 1–6
  (`resident actions` line); `test_dirty_clothes_send_people_to_the_waschsalon`.
- [x] Saves → `test_laundry_survives_saves`.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (3 October 2026). `--check-m2
--check-staffing`: varied seeds 1–6 pass; gentle seeds 1–4 and 6 pass, seed 5 fails on Sofia
Petrović (0 conversations), the lone-worker case the owner decided to fix in T-0079, next.
The first tuning (dirt 1.5 per hour) made clothes dirty in under two days, washes too rare
and hygiene fall to 0; measured and retuned before merging. Tier gap after the fix (full vs
tiered conversations, 2 days): seeds 1–5 −2%, 9%, 23%, −9%, 14% (was up to 32% on `main`).

## Questions

## Review feedback
