---
id: T-0077
title: Hardening after the October reviews - shifts, needs, honest checks, docs
status: in-progress
milestone: M3
size: L
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
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

Built by Opus in three branches, as the ticket allows: `t/0077a-shifts` (A),
`t/0077b-needs` (B), `t/0077c-docs` (C), each merged on its own.

### A. Shifts are settled once (`t/0077a-shifts`)
- `Employment` keeps the shift being attended: `shift_start`, `shift_minutes`, `shift_late`.
  `last_shift_start` now means "the last settled shift they worked in".
- `Jobs.start_shift` → `Careers.attend` (a new shift, or coming back to the same one, which
  keeps the first arrival's lateness). `Jobs.work_minute` counts a personal minute only if
  it began inside the window, so minutes before 09:00 never count.
- `Careers.settle` runs once per shift: when the work action completes, or, for a shift
  left early, in `WorkSystem._settle_shifts` once the window is over and they aren't
  working it. It pays `minutes × wage / 60` rounded once, judges lateness once, counts
  `shifts_worked`/`level_shifts`, meets colleagues, and emits `shift_settled`
  {person_id, job_id, minutes, late_minutes, left_early, pay}. No minutes inside the
  window: a missed shift. "Left early" is now "worked minutes + lateness more than 30
  short of the shift" (a late arrival who stays to the end isn't also "left early").
  `shift_ended` still goes out per segment (views and reports use it).
- Missed shifts: at a window's end, `shift_missed` unless that shift was settled or is
  being attended.
- Quitting or being fired mid-shift pays the open minutes (`Careers.close_shift`).
- Warning hysteresis: `performance.warning_clears_at` (35) in `economy.json`.
  `EconomyLoader.read_performance` checks the rules by meaning; six broken fixtures in
  `tests/fixtures/economy_broken/`.
- `WorkSystem._go` drops an NPC's whole queue; the player's queue keeps everything but the
  front.
- `Jobs.know_colleagues(sim, person, shift_start)` counts only colleagues whose settled
  shift started that day, or who are working that day's shift now (`Jobs.worked_on`).
- `Careers._change` returns when the job is unknown. `Jobs.HOUR_BEFORE_SHIFT` names the 23.
- Save v10: migration `_v9_to_v10` derives `shift_start`/`shift_minutes`/`shift_late` from
  a performing `work` action and v9's `last_shift_start` (set on arrival in v9). Saves
  older than that, which have no `last_shift_start`, are picked up at the first worked
  minute after loading (`Jobs.work_minute`), so they aren't marked missed either. Fixture
  `tests/fixtures/saves/v10_basic.json`.
- Tests (`test_careers.gd`): split shift (475 minutes, one settlement, lateness 0,
  `shifts_worked` +1), cancel before the shift (no penalty; never coming back is a miss),
  pay that doesn't depend on interruptions (3 × 1 minute = 1 × 3 minutes = 70 cents at
  €14/h), an old v9 save made mid-shift (full pay, no miss), warning hysteresis, unknown
  job. `test_leaving_for_work.gd`: the queue on leaving, colleagues who turned up.
  `test_content.gd`: the career rule fixtures.
- Verified (A alone): `tools/check.sh` 569 tests pass; `tools/simrun.sh --days=7 --check-m2` PASSED
  on seeds 1–6 (0.152, 0.146, 0.122, 0.140, 0.133, 0.129 ms/step).
- **Changed test:** `test_lateness_and_leaving_early_cost_performance` now checks that
  nothing is judged on walking away, and the same numbers once the shift's window is over.
  That's the behaviour the ticket asks for (item 1); the numbers it checks are unchanged.

### B. Needs, free will and an honest town check (`t/0077b-needs`)
- **Item 9:** `Routines.home_needs` puts every need below its `critical_below` first (lowest
  first), then hygiene/hunger by the home thresholds, then the rest (lowest first).
- **Item 10:** `data/needs.json` "home" (`wash_below`, `eat_below`, `low_below` →
  `ContentDB.home_thresholds`); `data/economy.json` "work" (`leave_margin`,
  `retry_minutes`, `look_ahead_hours`, `colleague_deltas`, plus the new `lunch_*`) and
  top-level `pocket_money`, `cash_errand_score` (money, not work, so not in "work").
  All validated (`NeedsLoader`, `EconomyLoader._read_work`), broken cases in
  `tests/fixtures/content_broken/`.
- **Item 11:** jobs no longer have a hunger rate. `Jobs.have_lunch` fills hunger by
  `lunch_hunger` (60, like cooking) and emits `meal_eaten {person_id, kind: "lunch"}`, once
  a shift (`Employment.shift_lunch`). **Interpretation:** "a shift of 4 hours or more
  includes lunch" became "lunch after 3 hours of work, or sooner when hunger falls below
  `eat_below`". Lunch only at the end of a shift starved early-shift workers who woke
  hungry and had to abandon breakfast for a 07:00 start (a care worker hit hunger 0 at
  08:25 on seed 2). `TownCheck` counts `meal_eaten` and the eating interactions, never a
  shift; `shift_settled` now carries `colleagues`, and the summary reports
  "colleague days" apart from social exchanges.
- **Item 12:** per-job profiles in `data/jobs.json` (see D31 for the numbers and why they
  are mild), `care_worker.shift_moodlet = "helped_someone"` (new moodlet, given only in
  varied mode), `economy.json` `gentle_profile` (today's shared profile without hunger).
  `WorkSettings` (`World.work.gentle`, default false), `SetGentleWorkCommand` (registered,
  validated in saves), Esc menu "Work: Varied / Gentle", `--gentle-work` for `simrun`.
- **Fixing the town, not the check:** the honest check first failed with varied jobs
  (fun, comfort, hunger to 0) and then, in both modes, on seeds 4–5 with a few lone workers
  having 1–2 conversations a week. Fixed by: milder profiles; early lunch; new towns give a
  worker the routine that leaves the most going-out hours free (`Jobs.routine_fit`, a
  14–22 shift had eaten an early bird's every evening); friendly talk while out
  `SOCIAL_OUT_SHARE` 0.8 → 0.9. Tried and rejected: lower social rates at work (comfort
  fell to 0 elsewhere) and 1.0 (five times the conversations). All in D31.
- **Owner decision (2 October, recorded in D31):** the suite's two-day check
  (`test_m2_town_lives.gd`) failed on the social rule: on Monday and Tuesday, both
  workdays, 1–4 working loners per town hadn't talked to anyone yet. Over a week all six
  seeds pass in both modes. Asked the owner (a frozen rule): the "talks with people" rule
  is now judged only over 7+ days (`TownCheck.SOCIAL_MIN_DAYS`), and the two-day check
  covers meals, sleep and needs. An evening-shift routine was tried for it first and
  rejected (it broke two week-long runs).
- **Item 13:** `docs/workflow.md` "Acceptance rules are frozen per milestone".
- **Item 14:** `QueueInteractionCommand` stamps `last_input_tick` only once it queues the
  action; `CallCommand` only with room in the queue; `WalkToCommand` only when there is a
  way (or it is a stop). Cancel, move intent and settings are unchanged.
- **Item 15:** `Careers._change` returns without a job (A). HUD/menu/inspector wording
  moved from `tests/sim/` to `tests/game/test_job_and_money_texts.gd`, with a lint test
  (`test_sim_tests_do_not_use_game_classes`) that fails if a sim test names a `game/`
  class. The shower has no "advertise" (an interaction without one advertises its
  `finish_needs`); content test. `Jobs.HOUR_BEFORE_SHIFT` (A). `Autonomy.restock_needed`
  and `Autonomy.cells_to_free_slot` are public.
- Save v11 (`world.work`, `job.shift_lunch`); fixture `v11_basic.json`.
- **Changed tests (all for behaviour the ticket changes):**
  `test_every_player_command_counts_as_input` queued an unknown interaction, which is now
  refused and is no longer input, so it queues a real one (a TV in a room);
  `test_people_see_to_low_needs_at_home` keeps its case with fun above its critical level
  and adds the critical case; `test_a_day_in_town_keeps_everyone_fed_rested_and_apart`
  counts lunch from `meal_eaten` instead of a finished shift; wording checks moved to
  `tests/game/` (same strings); `test_colleagues_get_to_know_each_other` reads the deltas
  from data.
- New tests: `test_work_profiles.gd` (lunch, early lunch, no lunch on a short stint,
  varied vs gentle rates, distinct profiles, the care moodlet, the command and save round
  trip, a bad saved setting, TownCheck counts), `test_free_will.gd` (refused commands and
  a refused click aren't input), `test_leaving_for_work.gd` (critical first),
  `test_content.gd` (moved numbers, broken data, the shower), `test_jobs.gd`
  (`routine_fit`), `tests/game/test_pause_menu.gd` (the Work button), the lint test.
- **Town check, 7 days, `--check-m2`, all PASSED** (ms/step; social exchanges; colleague days):
  varied seeds 1–6: 0.159, 0.151, 0.125, 0.144, 0.135, 0.130 ms (exchanges 1504, 1761,
  1254, 1347, 1206, 935); gentle (`--gentle-work`) seeds 1–6: 0.156, 0.150, 0.126, 0.142,
  0.134, 0.129 ms (exchanges 1482, 1708, 1280, 1223, 1137, 873). Colleague days 59, 49,
  29, 50, 44, 44. Before B, with colleagues counted as conversations, the town had about
  1000 exchanges a week on seed 1; cost is about 5% higher than after A (0.152 on seed 1).
- Screenshot `out/t0077-menu.png`: the Esc menu with "Work: Varied" under "Full lives".
- `tools/check.sh`: 591 tests pass.

## Questions

## Review feedback
