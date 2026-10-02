---
id: T-0064
title: Applying for jobs, quitting, and residents filling vacancies
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0063]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The phone gets a Jobs app. It lists the open positions (title, place, days and hours, wage),
and you can apply, have an interview and maybe get the job, starting the next day. You can
quit, and you can register as unemployed to get benefit. Unemployed residents apply every
Monday too, so vacancies fill and you have competition.

## Read first
`docs/design/jobs-and-economy.md` → Applying; T-0058 (`Jobs.vacancies`, `hire`), T-0062
(`benefit_registered`), T-0063 (the phone).

## Design (draft: detailed when its dependencies are merged)
- `game/ui/phone/jobs_app.gd`: your job (title, level, shift, performance in words, unpaid
  wages), vacancies with Apply, Quit, and "Register as unemployed" while jobless.
- Commands: `ApplyForJobCommand(person_id, job_id, position)`, `QuitJobCommand(person_id)`,
  `RegisterUnemployedCommand(person_id)`, all validated, and all in the save validator's
  command list.
- The interview: a chance from presentation (hygiene; the outfit's formality against the
  job's, using `ClothingDef.formality`) and mood (skills join in T-0071), rolled on stream
  "jobs". `job_application {person_id, job_id, position, hired}` → a notice "You got the job!
  You start tomorrow at 09:00." or "They chose someone else." Hired people start the next day
  (`Employment.hired_day`).
- Quitting: unpaid wages are paid, `job = null`, `quit_job` event.
- `EconomySystem`, Monday 09:00: each registered, unemployed resident under 67 applies to one
  vacancy whose shift fits their routine (stream "jobs").

## Acceptance (sketch)
- Apply → hired → working the next day; a poor presentation lowers the chance (exact odds for
  fixed inputs); quitting pays out; registering gives benefit on Monday; over 14 days, NPC
  applications fill most vacancies. Screenshot of the Jobs app.

## Implementation notes
- Built from the draft: `Hiring` (`sim/jobs/hiring.gd`: the interview from hygiene, mood and
  how the outfit's formality fits the job's new `formality`; apply/quit/register; residents
  apply on Monday 09:00), `ApplyForJobCommand`, `QuitJobCommand`, `RegisterUnemployedCommand`
  (registered and validated), `Person.applied_day` (one application a day; save v9,
  `v9_basic.json`). Hired people start tomorrow (`Jobs.shift_on` skips days before
  `hired_day`). The phone's Jobs app (`JobsApp`): your job and performance, Quit, Register,
  open positions with Apply. HUD notices for applications, quitting and registering.
- Verified: `tools/check.sh` 558 passed, 0 failed (`test_hiring.gd`, 6 tests; a Jobs app
  test). `tools/simrun.sh --days=14 --check-m2` PASSED on seeds 1–2: 19 of 20/21 working-age
  residents employed after two weeks (vacancies refill), 4 promotions, no firings.
  Screenshot `out/t0064.png`: the Jobs app.

## Questions

## Review feedback
