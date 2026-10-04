---
id: T-0093
title: Reports and the wanted level
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0092]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The third link of M4's chain: witnesses may call the police, and reported crimes give the
perpetrator a wanted level (0-5) that the player sees and that cools off.

## Scope
`sim/crime/police.gd`, `sim/content/police_rules.gd`, `"police"` in `data/crimes.json`
(+ `CrimeLoader`, `ContentDB.police_rules`), `Incident.reported_by` / `reported_tick` (saved;
read as unreported when absent), the call in `Crimes.commit`, the validator, `Hud`
(`wanted_text`, the wanted line, the "called the police" notice), tests. **Out of scope:**
officers responding, arrest, fines, records, identification by clothes.

## Specification
- `Police.maybe_report(sim, incident)`: each witness (ascending id, one draw each from the
  "crime" stream) reports with `report_chance`; the first is `reported_by`. Emits
  `crime_reported {incident_id, reporter_id, person_id}`.
- `Police.report_chance(sim, witness, perpetrator_id, severity)` = min(0.1 + 0.2 × severity,
  0.95), × 0.3 when the witness's friendship with the perpetrator is 30+.
- `Police.wanted_level(sim, person_id)` = min(ceil(sum of severities of their crimes reported
  in the last 48 game hours / 2), 5).
- HUD: "Wanted ★★☆☆☆" (tram yellow) under the place line while above 0; the notice
  "Someone called the police on you".

## Acceptance criteria
- [x] Report chances by severity and friendship → `test_police_reports.gd:
  test_report_chance_grows_with_severity_and_shrinks_for_friends`
- [x] About half of seen shopliftings get reported; unseen ones never →
  `test_about_half_of_seen_shopliftings_are_reported`, `test_unseen_crimes_are_never_reported`
- [x] Wanted level sums, caps and cools off → `test_wanted_level_sums_reported_crimes_and_cools_off`
- [x] Reports survive save/load → `test_reports_survive_save_and_load`
- [x] HUD text and notice → `test_hud_place.gd: test_wanted_text`
- [x] Screenshot `out/t0093.png` (seed 1, four snacks pocketed at the Späti, then 2 hours):
  "Wanted ★☆☆☆☆" under the place line

## Implementation notes
Built by the architect. Nobody comes for you yet: the stars only show that the police know.
Officers responding and arrests are the next ticket. `tools/check.sh` passes.
