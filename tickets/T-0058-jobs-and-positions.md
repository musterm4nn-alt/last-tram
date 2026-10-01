---
id: T-0058
title: Jobs - job data, positions, and residents with jobs
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0054]
builder:
review_rounds: 0
---

## Goal
The town gets jobs. Jobs are data: who employs you, what you do, your wage, and the shifts
(positions) to fill. Residents get jobs when the town is generated, and a routine that fits
their shift. People of 67 and over are retired. The player starts as an office clerk in the
city (Monday to Friday 9–17, by tram) until backgrounds decide otherwise (T-0075). Nobody goes
to work yet (T-0059).

## Read first
`docs/design/jobs-and-economy.md` → Jobs and careers; D10, D29 (jobs are positions);
`sim/people/resident_generator.gd`, `sim/content/routine_def.gd`, `data/routines.json`.

## Design (draft: detailed when its dependencies are merged)
- `data/jobs.json` → `JobDef` (`sim/content/job_def.gd`, `JobLoader`): `id`, `name` (the job
  title), `place_id` (employer place), `session` ("rabbit_hole" | "on_site"),
  `workplace_tag` (object tag where they work), `need_rates` (per hour while working),
  `levels` [{`title`, `wage` (cents per hour)}], `positions` [{`days` ["mon"…], `from`,
  `to`}] (whole hours, `to < from` = past midnight), `start_filled` (0..1, the chance a
  position is filled at new game; 1.0 for shop staff).
- First jobs (tune when measuring): Späti clerk (on-site; daily 8–17, Mon–Thu 17–2,
  Fri–Sun 17–2), Imbiss cook (on-site; daily 11–17, 17–23), bartender at the Kneipe (on-site;
  daily 17–2), police officer (rabbit hole at the Polizeiposten; Mon–Fri 6–14, 14–22), and
  city jobs by tram (rabbit hole at the tram stop): office clerk (Mon–Fri 9–17), warehouse
  worker (Mon–Fri 6–14), care worker (Mon–Fri 7–15, Wed–Sun 14–22), builder (Mon–Fri 7–16).
  Baristas come with the café counter (T-0065). Workplace objects that don't exist yet (the
  tram stop, the police desk) arrive in T-0059; validate the tag against objects, as
  interactions do.
- `Employment` (`sim/jobs/employment.gd`, saved as `Person.job`, null when unemployed):
  `job_id`, `position`, `level`, `performance` (50), `hired_day`. **Save v6.**
- `Jobs` (`sim/jobs/jobs.gd`, static): `holder(world, job_id, position) -> Person`,
  `vacancies(sim) -> Array[Dictionary]`, `hire(sim, person, job_id, position)`,
  `shift_on(sim, person, day) -> Vector2i` (start and end ticks, or (-1, -1) for a day off),
  `fits_routine(content, job, position, routine_id) -> bool` (the shift doesn't overlap the
  sleep window).
- Generation (after residents, before starting money): for each job and position in content
  order, roll `start_filled` (stream "jobs"), pick a jobless resident aged 18–66 whose
  routine fits (else give them the first routine that fits). `economy.json`:
  `retirement_age` 67, `player_job` "office_clerk".
- The inspector shows "Job: Office clerk (Mon–Fri 9–17)", "Unemployed" or "Retired".

## Acceptance (sketch)
- Content validation (places, tags, levels, wages > 0, days, hours) with a broken fixture.
- A new game: every shop position is filled, about 70–80% of working-age residents have jobs,
  nobody aged 67+ works, every worker's routine fits their shift, the same seed gives the same
  jobs. Save v6 round trip; old saves load with no jobs.

## Implementation notes

## Questions

## Review feedback
