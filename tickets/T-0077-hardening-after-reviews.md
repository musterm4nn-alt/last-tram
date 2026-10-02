---
id: T-0077
title: Hardening after the October reviews - shifts, needs, honest checks, docs
status: todo
milestone: M3
size: L
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Fix the real problems nine external code reviews found (2 October 2026) before more M3
features land. Shifts are settled once and fairly. Critical needs come before routine ones.
The town check measures what really happens instead of a shortcut. Balance numbers move into
data. Jobs get different need profiles again, behind a switch that can turn them off. The
front-page docs tell the truth. Split it into two or three branches if it grows past
~400 lines (A: shifts and careers; B: needs, autonomy and the town check; C: docs). It is L
for its breadth, not its difficulty.

## Read first
`docs/decisions.md` D29, D30; `sim/jobs/` (`jobs.gd`, `careers.gd`, `work_session.gd`),
`sim/systems/work_system.gd`, `sim/systems/autonomy_system.gd` (`_see_to_home_needs`),
`sim/ai/routines.gd` (`home_needs`), `tools/town_check.gd`, `data/jobs.json`,
`data/economy.json`, `sim/save/save_migrations.gd`. The reviews' summary is in the M3
handoff (`docs/handoff.md` → "October reviews").

## Scope and specification

### A. Shifts are settled once (bugs found by the reviews)
1. **One shift, one settlement.** Today every end of a performing work action (finished,
   cancelled, failed) runs `Careers.record_shift`, so stopping and returning within one
   shift counts as two shifts (double lateness, extra `level_shifts`, early promotion). Give
   a shift an identity: its scheduled start tick. Keep on `Employment` the attendance of the
   current shift: `shift_start` (tick, -1 = none), `shift_minutes` (minutes worked so far),
   `shift_late` (late minutes of the first arrival). Work segments add minutes. The shift is
   settled **once**, when its window ends (`WorkSystem`, the same place that notices missed
   shifts), using the accumulated minutes. Pay, performance, `shifts_worked`,
   `level_shifts`, colleagues and the "left early" judgement all happen at settlement.
2. **Cancelling before the shift starts costs nothing.** Minutes before the window's start
   aren't attendance, and a segment with no attendance isn't a "left early".
3. **Wages don't lose cents to interruptions.** Pay from accumulated minutes at settlement,
   with the remainder rounded once (or carried in `Employment.unpaid_remainder`). A test
   with a wage not divisible by 60 proves that three 1-minute segments pay the same as one
   3-minute segment.
4. **Old saves mid-shift aren't marked missed.** The migration for this ticket's new fields
   derives `shift_start`/`shift_minutes` from a performing work action (`started_tick`,
   `minutes_done`) when there is one. A test loads a v9 fixture-style save (or a
   constructed v9 dictionary) mid-shift, runs past the end and asserts wages and no
   `shift_missed`.
5. **The job warning doesn't repeat.** `warned` re-arms only once performance rises above
   `warn_below + 10` (hysteresis; the number goes in `economy.json` "performance" as
   `warning_clears_at`).
6. **Career settings are validated by meaning:** thresholds and `after_promotion` in 0..100,
   `fire_at < warn_below < warning_clears_at <= promote_at`, `promote_after_shifts` a whole
   number ≥ 1. Add broken economy fixtures that prove each error.
7. **Leaving for work clears the queue sensibly:** `WorkSystem._go` cancels the front action
   and also drops the rest of an NPC's queue (the player's queue is kept, minus the front).
8. **Colleagues are people who actually worked that day.** `Jobs._know_colleagues` counts
   only colleagues whose settled shift that day had attendance (or who are working right
   now), not everyone who was scheduled.
Save version bump with migration and fixture for the new `Employment` fields.

### B. Needs, free will and an honest town check
9. **Critical needs first.** `Routines.home_needs` orders needs by urgency: any need below
   its critical level (`NeedDef.critical_below`) comes first, lowest first. Then the routine
   thresholds: hygiene, hunger, then the rest. Test: hygiene 44 and hunger 1 → food first.
10. **Balance numbers in data.** Move `Routines.WASH_BELOW`, `EAT_BELOW`, `LOW_BELOW`,
    `WorkSystem.LEAVE_MARGIN`, `RETRY_MINUTES`, `LOOK_AHEAD_HOURS`,
    `Autonomy.POCKET_MONEY`, `CASH_ERRAND_SCORE` and `Jobs.COLLEAGUE_DELTAS` into data
    (`data/needs.json` "home" block, `data/economy.json` "work" block), loaded and validated.
11. **Lunch is a real meal.** Instead of the job's +6 hunger cancelling the decay, a
    completed shift of 4 hours or more includes a `lunch_at_work` moment: an action-free
    finish effect that fills hunger like a meal and emits `meal_eaten {person_id, kind:
    "lunch"}`. `TownCheck` counts meals from `meal_eaten` and the eating interactions; it no
    longer counts any shift as a meal. Colleague contact is reported **separately** in the
    summary ("social exchanges N, colleague days M") and no longer counts as a social
    exchange in `failures()`. If the honest check then fails, fix the town (not the
    check), and report what changed.
12. **Different jobs, switchable (owner's decision, 2 October).** Give each job its own need
    profile in `data/jobs.json`: desk jobs restful but boring, standing jobs hard on comfort,
    manual jobs tiring (energy) but social, care work draining but rewarding (a "helped
    someone" moodlet per shift), bar work fun but exhausting. Keep today's shared gentle
    profile as `"gentle_profile"` in `data/economy.json`. A saved world setting
    `World.work.gentle` (default **false**: distinct jobs) switches between them, with a
    `SetGentleWorkCommand` (registered and validated) and an Esc menu button "Work: varied
    / gentle", like "Full lives". The town check must pass with **both** settings on seeds
    1–3 for 7 days.
13. **Acceptance rules are frozen per milestone.** Add to `docs/workflow.md`: from the start
    of a milestone, its acceptance criteria and `TownCheck`'s thresholds change only with
    the owner's approval, recorded in `docs/decisions.md`.
14. **Input only counts when it works.** `QueueInteractionCommand` (and any command doing the
    same) stamps `last_input_tick` only when the command is accepted. A refused click no
    longer delays free will.
15. **Small fixes:** `Careers._change` returns safely if the job is missing; tests stop
    asserting HUD wording inside `tests/sim/` (move them to `tests/game/`); the shower's
    hygiene appears once (check advertise vs finish in a content test, or derive advertise
    when it's absent); name the `(shift.from + 23 + i) % 24` idiom (`HOUR_BEFORE_SHIFT`);
    `Autonomy._restock_needed` becomes public (`restock_needed`), and so does anything else
    `AutonomySystem` calls with a leading underscore.

### C. Docs tell the truth
16. `README.md`: status (M3 in progress), how to run, the real key list (copy
    `Hud.hint_text`), links to the playbook doc and `docs/playtesting.md`. Add a lint test
    that fails when the README's status line doesn't match the roadmap's ▶ row.
17. `AGENTS.md`/`CLAUDE.md`: one source of truth. AGENTS.md describes builders generically
    (whoever builds: currently Opus itself) and CLAUDE.md points to it for the shared rules
    instead of repeating them.
18. `docs/architecture.md`: the folder map lists `sim/economy/`, `sim/jobs/`, `game/ui/phone/`;
    the module plan keeps only future milestones; the systems paragraph matches
    `Sim.default_systems()` (Tier, Action, Movement, Needs, Social, Work, Economy, Autonomy).
19. Delete stale branches: `t/0001…t/0022` locally and remotely; keep `backup/*` but tag
    milestones (`m0`, `m1`, `m2`) at their sign-off merges. Do not delete anything else.
**Out of scope:** performance and robustness work (T-0078), the LICENSE (the owner decides
later), new features.

## Acceptance criteria
- [ ] Split-shift test: work 09:00–12:00, leave, return 12:05–17:00 → one settled shift, pay
  for 475 minutes, one lateness judgement, `shifts_worked` +1 (`test_careers.gd`).
- [ ] Early-cancel test: Work at 08:10, cancel 08:15, work the whole shift → no penalty.
- [ ] Segment-invariant pay test with a wage not divisible by 60.
- [ ] Mid-shift old-save test: wages, no `shift_missed`.
- [ ] Warning hysteresis test; broken-economy fixture tests for the career rules.
- [ ] Queue test for leaving for work; colleague test with an absent colleague.
- [ ] `home_needs` ordering test with a critical need.
- [ ] Data-moved constants load and are validated (`test_content.gd` broken fixtures).
- [ ] Lunch: a shift emits `meal_eaten`; `TownCheck` meal and colleague counts are
  separate; `test_m2_town_lives.gd` still passes with the honest check.
- [ ] Gentle/varied switch: command, save round trip, Esc menu button (game test),
  screenshot `out/t0077-menu.png`; `tools/simrun.sh --days=7 --check-m2` PASSED for seeds 1–3
  in **both** modes (numbers in the notes, incl. ms/step).
- [ ] Refused commands don't stamp input (test).
- [ ] README lint test; docs updated; milestone tags pushed; stale branches gone.
- [ ] `tools/check.sh` passes; nothing weakened (any changed test explained in the notes).

## Implementation notes

## Questions

## Review feedback
