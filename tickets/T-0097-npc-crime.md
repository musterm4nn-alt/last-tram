---
id: T-0097
title: Residents commit crimes
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0096]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The town has crime of its own: dishonest or broke residents pick pockets and pocket snacks
when nobody is watching, at believable rates, and the police respond to them as to the player.

## Docs
[docs/design/crime-and-police.md](../docs/design/crime-and-police.md) "NPC crime"

## Scope
- `sim/ai/temptation.gd` (new `Temptation`: `willing`, `bonus`, `risk`), used by `Autonomy`
  for object and person options.
- `"temptation"` in `data/crimes.json` (+ `TemptationRules`, `ContentDB.temptation_rules`,
  `CrimeLoader` with validation); `steal_snack` advertises hunger 15.
- `tools/crime_report.gd` (`CrimeReport.line`), printed by `tools/sim_runner.gd`.
- Tests, the design doc.

**Out of scope:** NPCs fleeing the police, NPC jail, gossip, a `--check-m4`.

## Specification
- `Temptation.willing(sim, person)`: never the player; honesty <= `honesty_below` (-40) or
  wallet total < `broke_below` (1000); not wanted; no incident of theirs within
  `cooldown_hours` (72).
- `Temptation.risk(sim, person, cell, victim_id)`: for each id in `Witnesses.find(cell,
  person)` other than the victim, `risk_per_witness` (3), plus `risk_per_officer` (10) for an
  on-duty officer; times (1 - bravery / 200).
- `Temptation.bonus`: `steal_bonus` (5) for a crime with `steal_share` > 0, minus the risk.
- Autonomy: crime options only when willing; their base score adds `bonus` (at the object's
  origin, or the target person's cell excluding them).

## Acceptance criteria
- [x] Content and validation → `test_npc_crime.gd: test_temptation_content`
- [x] Who is willing → `test_who_is_willing`
- [x] Risk by onlookers, officers and bravery → `test_risk_counts_witnesses_officers_and_bravery`
- [x] A crook picks a pocket when unseen, once, and not when watched →
  `test_a_crook_picks_a_pocket_only_when_nobody_watches`, `test_a_crook_leaves_pockets_alone_with_someone_watching`
- [x] Broke and hungry residents consider shoplifting; others pay →
  `test_broke_and_hungry_residents_may_shoplift`
- [x] simrun prints crimes per day → `test_the_crime_report_line`; `tools/simrun.sh --days=7`
- [x] The town still passes M2 (and staffing) for 7 days, and M3 for 30 days (seed 1: 58 crimes, 9 reported, €800 in fines, M3 PASSED)

## Implementation notes
Built and reviewed by the architect. `tools/check.sh` passes.
- Rates (7 days): seeds 1-4 gave 13, 9, 13, 16 crimes, all pickpocketing, 1-3 reported each.
  The first tuning (cooldown 24 h, steal_bonus 6) gave 4-5 a day, too many for ~35 people.
  Shoplifting needs someone broke and hungry; the economy rarely lets anyone go broke yet
  (the M3 balance note), so it shows up in tests, not in runs.
- Two older tests said residents never steal; they now check the new rule:
  `test_crimes.gd: test_only_the_tempted_steal` (a day in town: every thief is dishonest or
  broke, never the player) and `test_pickpocketing.gd:
  test_free_will_never_picks_a_pocket_for_the_honest`.
- `tools/simrun.sh --days=7 --check-m2 --check-staffing` passes on seeds 1 and 2 (0.12-0.13
  ms per step, budget 0.25).
