---
id: T-0061
title: Payday, performance, promotion and getting fired
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0060]
builder:
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

## Questions

## Review feedback
