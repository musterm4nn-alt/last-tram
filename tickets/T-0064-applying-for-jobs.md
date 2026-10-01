---
id: T-0064
title: Applying for jobs, quitting, and residents filling vacancies
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0063]
builder:
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

## Questions

## Review feedback
