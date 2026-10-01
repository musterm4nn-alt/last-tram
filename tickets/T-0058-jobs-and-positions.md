---
id: T-0058
title: Jobs - job data, positions, and residents with jobs
status: todo
milestone: M3
size: M
owner: builder
depends_on: [T-0057]
builder:
review_rounds: 0
---

## Goal
The town gets jobs. Jobs are data: who employs you, where you work, your wage, and the shifts
(positions) to fill. Residents get jobs when the town is generated, and a routine that fits
their shift; people of 67 and over are retired. The player starts as an office clerk in the
city (Monday to Friday 9–17, by tram) until backgrounds decide otherwise (T-0075). The tram
stop on the Altmarkt gets a shelter and the Polizeiposten a desk. Nobody goes to work yet
(T-0059); the inspector shows everyone's job.

## Read first
`docs/design/jobs-and-economy.md` → Jobs and careers; D10, D29 (jobs are positions);
`sim/people/resident_generator.gd`, `sim/content/routine_loader.gd`, `data/routines.json`,
`sim/ai/routines.gd` (`in_hours`), the cookbook's "Add a new kind of content".

## Scope
Create `data/jobs.json`, `sim/content/job_def.gd`, `sim/content/job_loader.gd`,
`sim/jobs/employment.gd`, `sim/jobs/jobs.gd`, `tests/sim/test_jobs.gd`,
`tests/fixtures/saves/v6_basic.json`. Change `data/objects/shops.json` (two objects),
`data/world/districts/altstadt/objects.json` (placements), `data/economy.json` (+
`EconomyDef`/loader), `sim/content/content_db.gd`, `sim/people/person.gd`,
`sim/world/world.gd`, `sim/sim_factory.gd`, the save codec, migration and validators,
`game/ui/person_inspector.gd`, `tools/sim_runner.gd`.
**Out of scope:** going to work (T-0059), pay (T-0061), applying (T-0064), slot roles
(T-0059).

## Specification

### Workplace objects
In `shops.json`: `tram_stop` ("Tram shelter", 6×1, tag `tram_stop`; slots [0..5, 1] facing
[0,-1], plus [-1, 0] and [6, 0] facing [0,-1]: 8 slots) at (27, 22, 0), on
`tram_stop_altmarkt`; `police_desk` ("Desk", 2×1, tag `police_desk`; slots [0,-1], [1,-1]
facing [0,1] and [0,1], [1,1] facing [0,-1]) at (65, 27, 0) in the Polizeiposten. Nothing
offers interactions on them yet.

### `data/jobs.json` → `ContentDB.jobs: Dictionary[String, JobDef]` (`JobLoader`)
```json
{ "id": "office_clerk", "name": "Office clerk", "place_id": "tram_stop_altmarkt",
  "session": "rabbit_hole", "workplace_tag": "tram_stop",
  "need_rates": { "energy": -3.0, "fun": -4.0, "comfort": 6.0, "hunger": 3.0 },
  "levels": [ { "title": "Office clerk", "wage": 1400 }, { "title": "Senior clerk", "wage": 1700 }, { "title": "Team lead", "wage": 2100 } ],
  "positions": [ { "days": ["mon", "tue", "wed", "thu", "fri"], "from": 9, "to": 17, "count": 3 } ],
  "start_filled": 0.7 }
```
- `JobDef`: `id`, `name`, `place_id`, `session` ("rabbit_hole" | "on_site"), `workplace_tag`,
  `need_rates` (per hour while working, on top of decay: the hunger term stands for lunch),
  `levels: Array[JobLevel]` (`title`, `wage` in cents per hour), `positions: Array[Shift]`
  (`days: PackedInt32Array` 0 = Monday, `from`, `to` whole hours, `to < from` = past
  midnight; a `"count"` expands into that many identical positions, in order),
  `start_filled` (0..1).
- Validation: the place exists; some placed object with `workplace_tag` stands on that place;
  the session is known; needs exist; levels aren't empty and wages are > 0; days are known
  names; hours are 0..24 with `from != to`; `start_filled` is in 0..1; no duplicate ids.
- The jobs (wages in cents per hour; tune when measuring):

| id | place, tag | session | positions | start_filled |
|---|---|---|---|---|
| `spaeti_clerk` | spaeti_kaya, spaeti_counter | on_site | daily 8–17; Mon–Thu 17–2; Fri–Sun 17–2 | 1.0 |
| `imbiss_cook` | imbiss_anadolu, imbiss_counter | on_site | daily 11–17; daily 17–23 | 1.0 |
| `bartender` | kneipe_anker, bar | on_site | daily 17–2 | 1.0 |
| `police_officer` | polizeiposten, police_desk | rabbit_hole | Mon–Fri 6–14; Mon–Fri 14–22 | 1.0 |
| `office_clerk` | tram_stop_altmarkt, tram_stop | rabbit_hole | Mon–Fri 9–17 ×3 | 0.7 |
| `warehouse_worker` | tram_stop_altmarkt, tram_stop | rabbit_hole | Mon–Fri 6–14 ×2 | 0.7 |
| `care_worker` | tram_stop_altmarkt, tram_stop | rabbit_hole | Mon–Fri 7–15; Wed–Sun 14–22 | 0.7 |
| `builder` | tram_stop_altmarkt, tram_stop | rabbit_hole | Mon–Fri 7–16 ×2 | 0.7 |

  Wages: Späti 1150/1300, Imbiss 1200/1400, bartender 1250/1450, police 1900/2300, office
  1400/1700/2100, warehouse 1300/1500, care 1500/1800, builder 1600/1900 (each level a title).

### `Employment` (`sim/jobs/employment.gd`), saved as `Person.job` (null = no job)
`job_id: String`, `position: int` (index into the expanded positions), `level: int`,
`performance: float` (50.0), `hired_day: int`. `to_dict`/`from_dict`. **Save v6**:
`_v5_to_v6` adds `"job": null` to everyone. Validator: `job` is null or a dictionary with a
text `job_id`, integers `position`, `level` and `hired_day` ≥ 0, and `performance` 0..100.
`World.from_dict` drops a job whose `JobDef` or position no longer exists.

### `Jobs` (`sim/jobs/jobs.gd`, static)
- `holder(world, job_id, position) -> Person` (null when vacant).
- `vacancies(sim) -> Array[Dictionary]`: `{job_id, position}` in content order.
- `hire(sim, person, job_id, position) -> bool`: false if the position is taken or doesn't
  exist; sets `person.job` and emits `hired {person_id, job_id, position}`.
- `shift(job, position) -> Shift`; `shift_on(sim, person, day) -> Vector2i`: the start and end
  ticks of the person's shift starting on `day`, or (-1, -1) on a day off or without a job.
- `fits_routine(content, job, position, routine_id) -> bool`: the shift's hours don't overlap
  the routine's sleep window (both wrap past midnight).
- `days_text(shift) -> String`: "daily", "Mon–Fri", "Fri–Sun", "Mon, Wed".

### Generation (`SimFactory.new_game`, after residents, before money)
1. `economy.json` `"player_job": "office_clerk"` → the player is hired into its first free
   position.
2. For each job in content order and each position: skip if taken; roll `start_filled` on
   `sim.rng.stream("jobs")`; pick (same stream) a resident without a job, aged 18 to
   `retirement_age` − 1 (`economy.json` 67), preferring those whose routine fits. If none
   fits, take one anyway and give them the first routine (in id order) that fits.

### Showing it
- Inspector: `"Job: Office clerk (Mon–Fri 9–17)"`, `"Unemployed"`, or `"Retired"` (aged
  ≥ `retirement_age` without a job).
- simrun: `jobs: 17 of 21 working-age residents employed, 6 retired, 4 vacancies`.

## Acceptance criteria
- [ ] Content loads; broken jobs (unknown place, no workplace object on the place, zero
  wage, bad day, `from == to`) are reported → `test_jobs.gd`.
- [ ] A new game (seeds 1–3): every `start_filled: 1.0` position is filled, the player is an
  office clerk, nobody aged ≥ 67 has a job, every worker's routine fits their shift, and the
  same seed gives the same jobs → `test_jobs.gd`.
- [ ] `shift_on` for a day shift, a day off and a shift past midnight; `fits_routine`
  examples; `days_text` examples → `test_jobs.gd`.
- [ ] v6 round trip, the migration, and a dropped unknown job → `test_jobs.gd`; fixture.
- [ ] Inspector line → `test_person_inspector.gd`.
- [ ] `tools/check.sh` passes; `--check-m2` still passes (nobody works yet). Screenshot
  `out/t0058.png` of the tram shelter.

## Implementation notes

## Questions

## Review feedback
