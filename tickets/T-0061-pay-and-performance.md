---
id: T-0061
title: Payday, performance, promotion and getting fired
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0060]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Work pays and work counts. Every shift earns the job level's hourly wage, paid into the bank
on Friday at 18:00. How you work shows in your performance. Turn up on time in a good mood and
you get promoted to the next title and wage; turn up late, leave early or miss shifts and you
get a warning, then you're fired. The player can now get paid and get fired.

## Read first
D29 (the weekly cycle); `docs/design/jobs-and-economy.md` → Jobs and careers; T-0059 and
T-0060 (`WorkResult`, `WorkSystem`).

## Design (draft: detailed when its dependencies are merged)
- `Employment` gains `unpaid` (cents earned since the last payday), `shifts_worked`,
  `shifts_missed`, `days_at_level` and `warned`. A save version bump.
- Pay per shift: `minutes × wage / 60`, rounded down, added to `unpaid`.
- `EconomySystem` (`sim/systems/economy_system.gd`): Friday 18:00 →
  `Money.earn(…, "wage", BANK, job_id)` for everyone's `unpaid`; `wages_paid` event.
- Performance (0..100) after each shift: +2 for a full shift, +1 more in a good mood; −1 per
  5 minutes late; −10 for leaving more than 30 minutes early. `WorkSystem` marks a shift that
  never started as missed at its end: −20 and `shift_missed`.
- Promotion: performance ≥ 80 and `days_at_level` ≥ the level's `promote_days` → the next
  level, performance 60, a `promoted` event, a notice, a memory and a moodlet.
- Warning below 25 (once until it recovers): `job_warning` and a notice. Fired at 0:
  unpaid wages are paid at once, `job = null`, `fired` event, a notice, a memory and a
  moodlet; the position becomes a vacancy.
- `economy.json`/`jobs.json` hold the numbers; the inspector shows performance in words.

## Acceptance (sketch)
- Exact pay for a shift; payday on Friday; three missed shifts in a row get you fired; a good
  streak gets you promoted; save/load keeps unpaid wages.
- 7-day run: the ledger shows wages, nobody is fired in a normal week, `--check-m2` still
  passes.

## Implementation notes
- Built from this draft directly (detailed while building): `Careers` (`sim/jobs/careers.gd`:
  `record_shift`, `miss`, `pay`, `fire`, promotion and warnings), `EconomySystem` (payday,
  Friday 18:00 by `economy.json`), `Employment` gains `unpaid`, `level_shifts`,
  `shifts_worked`, `shifts_missed`, `warned`, `last_shift_start` (save v7, `_v6_to_v7`,
  validator, `v7_basic.json`). `WorkSystem` notices a missed shift at its end. Rules are in
  `economy.json` "performance"; moodlets `promoted`, `fired`, `payday`; memories `promoted`,
  `fired`. HUD notices (`Hud.career_notice`); the inspector adds "doing well/okay/struggling".
- Verified: `tools/check.sh` 539 passed, 0 failed (`test_careers.gd`, 6 tests: exact pay,
  payday, lateness and leaving early, three missed shifts → warning → fired, promotion, save).
  `tools/simrun.sh --days=7 --check-m2` PASSED on seeds 1–3; wages paid €7,006/€6,176/€4,936
  in the week; nobody missed a shift or was fired; the ledger balances.

## Questions

## Review feedback
