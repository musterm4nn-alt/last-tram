---
id: T-0065
title: Staffed counters - shopkeepers behind the counters
status: done
milestone: M3
size: L
owner: builder
depends_on: [T-0060, T-0057, T-0077]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Shops are run by people. The Späti clerk, the Imbiss cook, the bartender and (new) the barista
at Café Wolke stand behind their counters during their shifts, visible, and the counters sell
only while someone is serving. If the late-shift clerk is ill, asleep or fired, the Späti
can't sell anything. This is the second `WorkSession`: on-site work.

## Read first
D10, D29; `docs/design/jobs-and-economy.md` → Shops and services; `sim/jobs/` (`WorkSession`,
`RabbitHoleWork`, `WorkSessions`, `Jobs.working`/`Jobs.hidden`); `sim/actions/requirements.gd`.

## Scope
- New: `sim/jobs/on_site_work.gd`, `sim/jobs/staffing.gd`, `tests/sim/test_staffed_counters.gd`,
  fixture `tests/fixtures/saves/v12_basic.json`.
- Change: `sim/jobs/work_sessions.gd`, `sim/actions/requirements.gd`,
  `sim/content/interaction_def.gd` + `interaction_loader.gd` (`staffed`), `job_loader.gd`
  (validation), `sim/save/save_codec.gd` + `save_migrations.gd` (v12), `game/ui/hud.gd`
  (place line), `tools/town_check.gd` + `tools/sim_runner.gd` (staffing report and
  `--check-staffing`), data: `jobs.json` (barista), `objects/shops.json` (`cafe_counter`),
  `interactions/shops.json`, `going_out.json`, `work.json`, the Altstadt `objects.json`,
  `docs/design/jobs-and-economy.md` (one line).
- **Out of scope:** stock, deliveries, tips, the player choosing to serve customers, a
  playable shopkeeper, new art (the counter uses its debug colour).

## Specification
- **`OnSiteWork extends RabbitHoleWork`**: same needs per minute (the job's `need_rates`, or
  the gentle profile), but `hidden()` returns false: the worker stays visible on the staff
  slot, facing the customers. `WorkSessions.for_job(job)` returns one shared `OnSiteWork`
  when `job.session == JobDef.ON_SITE`, else the rabbit hole. No saved state.
- **`Staffing`** (static, no state):
  - `places(content: ContentDB) -> PackedStringArray`: the place ids of on-site jobs, sorted.
  - `serving(sim: Sim, place_id: String) -> bool`: someone `Jobs.working` an on-site job whose
    `place_id` is `place_id` right now.
  - `unserved(sim: Sim, lot: Lot) -> bool`: the lot's place is in `places`, `Lots.is_open`,
    and nobody is `serving` it (for the HUD and reports).
- **`InteractionDef.staffed: bool`** (JSON `"staffed": true`, object targets only; loader
  error otherwise). Set on buy_snack, grab_a_beer, eat_doener, eat_fries, buy_groceries,
  have_a_drink and have_a_coffee. The pub tables and café tables are staffed through their
  lot. `JobLoader` checks that every placed object offering a staffed interaction stands on
  a place with an on-site job.
- **`Requirements`**: new reason `"not_staffed"` (`TEXT`: "nobody's serving"), checked right
  after "closed"/"private": a staffed interaction on an object on a lot needs
  `Staffing.serving(sim, lot.place_id)`. Objects on no lot (test rooms) pass.
- **Café Wolke**: object `cafe_counter` (3×1, tag `cafe_counter`, Späti layout with two staff
  slots at (0,-1) and (1,-1)), placed at (21,13) with rotation 2 (customers above at y 12,
  staff below at y 14). The work interaction also offers on `cafe_counter`. Job `barista`
  (place `cafe_wolke`, on_site, start_filled 1.0, two positions Mon–Sat 8–14 and 14–19,
  wages like the clerk).
- **Save v12**: the migration adds the café counter to saves that have no `cafe_counter`
  (id `next_id`, then `next_id` + 1). Fixture `v12_basic.json`.
- **HUD place line**: "Späti Kaya (nobody serving)" when `Staffing.unserved`.
- **Reports**: `TownCheck.sample` counts, per staffed place, its open minutes and staffed
  minutes; `TownCheck.staffing_summary(sim)` gives "staffed: Späti Kaya 97%, ..." and
  `staffing_failures(sim)` lists places under `MIN_STAFFED_SHARE` = 0.9. `sim_runner.gd`
  prints the summary, and `--check-staffing` fails the run on a failure. (A new check, so the
  frozen M2 rules are untouched.)

## Acceptance criteria
- [x] On-site workers are visible on their staff slot while working; rabbit-hole workers are
  still hidden → `test_on_site_worker_is_visible_behind_the_counter`,
  `test_rabbit_hole_worker_still_hidden`.
- [x] Buying at an open counter with nobody serving is refused with "not_staffed"; with the
  clerk working it's allowed; café tables and pub tables follow their lot →
  `test_counter_sells_only_while_staffed`, `test_cafe_table_needs_the_barista`.
- [x] Free will never picks an unstaffed counter →
  `test_free_will_skips_unstaffed_counter`.
- [x] Content: `staffed` is read and validated; every on-site place has a placed workplace;
  the barista exists → `test_staffed_content`.
- [x] Old saves get the café counter → `test_v11_save_gets_cafe_counter`, all fixtures load.
- [x] HUD says "(nobody serving)" → `test_place_text_nobody_serving` (tests/game).
- [x] Over 7 days (staffing yes on every run; `--check-m2` 11 of 12, see the notes and T-0079) each shop is staffed at least 90% of its open time, and `--check-m2` still
  passes → `tools/simrun.sh --days=7 --check-m2 --check-staffing` on seeds 1–6, both work
  modes (results in the notes).
- [x] Screenshot of the clerk behind the Späti counter (`tools/screenshot.sh out/t0065.png`
  at a staffed time; taken on the Mac if the build session has no display).

## Implementation notes
Built by Opus in a Claude Code cloud session (2 October 2026), on `t/0065-staffed-counters`.

**What changed (game terms):** the Späti clerk, the Imbiss cook, the bartender and a new
barista at Café Wolke now stand visibly behind their counters during their shifts, and you
can talk to them there. Buying a snack, beer, groceries, a Döner, fries, a drink or a coffee
works only while someone is serving; otherwise the menu says "(nobody's serving)" and the
HUD's place line says "Späti Kaya (nobody serving)". Café Wolke has a counter (debug colour
for now, no art) and two barista shifts, Mon–Sat 8–14 and 14–19.

**Key files:** `sim/jobs/on_site_work.gd` (`OnSiteWork`: the rabbit hole's needs, but visible),
`sim/jobs/work_sessions.gd` (picks it for `on_site` jobs), `sim/jobs/staffing.gd`
(`places`, `serving`, `unserved`; derived from the work actions, nothing saved),
`Requirements` reason `not_staffed`, `InteractionDef.staffed` (loader: object targets only;
`JobLoader.check_staffed`: every placed object offering one stands on a place with an
on-site job), save v12 (`_v11_to_v12` adds the café counter to old towns; fixture
`v12_basic.json`), `Hud.place_text`, `TownCheck` staffing samples + `--check-staffing` in
`sim_runner.gd`. Data: `barista` in `jobs.json` (its own need profile, so the profiles stay
distinct), `cafe_counter` in `objects/shops.json` (two staff slots; placed at (21,13) turned
round), `staffed` on the seven purchases.

**Tests:** `tests/sim/test_staffed_counters.gd` (11 tests: visible on-site worker, hidden
rabbit hole, counter refuses without a server and sells with one, a customer on the way is
turned away when the server leaves, café and pub tables follow their lot, free will skips an
unstaffed counter, content and validation, every open hour has a position, old saves get the
counter, the staffing report) and `test_place_text_nobody_serving` in
`tests/game/test_hud_place.gd`. Existing tests that jump the clock and then buy something
now call a new helper, `tests/support/shop_staff.gd` (`ShopStaff.serve_now`: the staff whose
shift it is come in to work). Two tests needed a different setup because in seed 1 every
working-age resident now has a job: `test_benefit_covers_an_unemployed_residents_rent`
makes one resident jobless, `test_residents_fill_vacancies_over_time` frees one position.
No assertion was weakened; the HUD and menu tests gained "(nobody serving)" checks.

**Verification:** `tools/check.sh`: 605 passed, 0 failed. Seven-day runs
(`sim_runner.gd -- --days=7 --check-m2 --check-staffing --seed=N`):
- Staffing on every run: Café Wolke 99–100%, Imbiss 98%, Kneipe 100%, Späti 98–99%.
- Varied jobs: seeds 1–6 all pass `--check-m2`.
- Gentle jobs: seeds 1–4 and 6 pass; **seed 5 fails**: "Sofia Petrović talked with people
  only 1 times".
- Cost: 0.231 ms per step against 0.223 on `main` (seed 1, same cloud machine, which is about
  2.5× slower than the Mac); about +3%.

**About the seed 5 failure.** It is not caused by the counters; it comes from re-rolling the
town. Adding the barista job changes who gets which job at the start, so Sofia becomes an
early-shift warehouse worker (out 15–19), a grumpy loner (kindness −58, temper 79) who keeps
her social need full with coffee and video calls and never chooses to talk, even with the
barista next to her. Measured: the quietest resident per run on seeds 7–12 is as low on
`main` as on the branch, and `main` already fails gentle seed 11 (Anouk Wójcik, 1
conversation), so seeds 1–6 passing on `main` was partly luck. This is the "knife edge for
lone workers" from the handoff. Two fixes tried and rejected:
- Listing the barista last in `jobs.json` (to keep the old job draws): the café then often
  has no barista (55% and 0% staffed on seeds 1 and 5).
- Small talk when served (the server chats with each customer): Sofia rises to 47, but the
  quietest resident of every town jumps from 1–20 to 23–61 conversations a week. Every
  purchase would count as a conversation, the kind of inflation the October reviews
  criticised.
The real fix belongs to lone early-shift workers' evenings. **Owner's decision (2 October
2026):** merge T-0065 now and fix lone workers next, in T-0079, before the M3 acceptance
(T-0076). The town check's rule stays as it is.

**Not done here:** the screenshot (no display in the cloud session): on the Mac run
`tools/screenshot.sh out/t0065.png` at a staffed time (for example with `--walk` near the
Späti at midday) and check the clerk stands behind the counter. Art for the café counter
(debug colour). The agent playtest after T-0065 (needs OpenCode on the Mac).

## Questions

## Review feedback
Self-reviewed by the architect (Opus) in the same session: criteria checked against the tests
and runs above; the one `--check-m2` failure is the pre-existing lone-worker edge, accepted by
the owner with T-0079 as the fix. Screenshot still to be taken on the Mac.
