---
id: T-0078
title: Robustness and performance - free will at scale, session split, safer determinism
status: in-progress
milestone: M3
size: L
owner: builder
depends_on: [T-0077]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Make the engine ready for a bigger town and for the 30-day acceptance run (T-0076), as the
October reviews asked. Free will must get cheaper. `session.gd` gets split before it hits the
350-line lint. Time-skips stop freezing a frame. Determinism gets harder to break by accident,
and is proven on the full town. Measure first: every change in this ticket comes with numbers
from a stress run. Split into branches as needed (A: measure and speed; B: session and skip;
C: determinism and tests).

## Read first
`docs/architecture.md` (performance budget: ~150 residents, ≤4 ms sim per frame at 3x);
D27, D28; `sim/ai/autonomy.gd`, `sim/systems/autonomy_system.gd`, `sim/world/pathfinder.gd`,
`sim/jobs/jobs.gd`, `game/session.gd`, `tests/lint/test_sim_purity.gd`, `tests/sim/test_save.gd`,
`tools/sim_runner.gd`.

## Scope and specification

### A. Measure, then make free will cheap
1. **Stress run and per-system timing.** `tools/simrun.sh --residents=N` (fill extra homes
   by cloning flats on a test-only map, or allow households of up to 4 in a test mode) and
   `--profile`, which prints ms per step per system. Record the baseline at 30, 90 and 150
   people in the notes.
2. **Content-derived lookups computed once.** `ContentDB` keeps `interactions_for_def:
   Dictionary[String, Array[InteractionDef]]` and the sets of object defs offering "out" and
   errand interactions. `Interactions.offered_by`, `Autonomy._outing_objects` and
   `_errand_objects` use them instead of scanning all interactions × objects × tags per call.
3. **A spatial index for objects.** `World` keeps a coarse bucket grid (e.g. 8×8 cells per
   bucket, per level), rebuilt with the object footprint index. `Autonomy.candidates`
   queries the buckets within `SEARCH_RADIUS` instead of sorting every object id.
4. **Fewer A\* calls.** Rank candidates by need score minus a Chebyshev-distance travel
   estimate, then pathfind only the best K (e.g. 6) to confirm them and get the real cost.
   Keep the existing tests' behaviour (adjust thresholds only with measured reasons).
5. **Background people decide more cheaply:** in the background tier, free will runs at most
   every `background_autonomy_minutes` (data, e.g. 5) and skips social options.
6. **Indexes for jobs and homes:** `World` keeps `position → person_id` (rebuilt on
   hire/fire/load) so `Jobs.holder`/`vacancies` stop scanning everyone; each person's home
   objects are cached per home lot (rebuilt when objects change) for `_go_home_for`;
   `Jobs.workplace` uses a per-job cache of workplace object ids.
7. **Paths pop from the back:** store `Person.path` reversed in memory (or use an index) so
   `MovementSystem` stops calling `remove_at(0)`. The save format stays the same.
8. **Pathfinder hygiene:** `find_path` returns a result that tells "already there" from
   "unreachable" (e.g. `Pathfinder.Result` or a separate `reachable()`); update callers.
   Nav graphs rebuild per level (a per-level revision) instead of all levels on any change
   (needed before build mode, M5).
**Target:** at 150 people, sim cost ≤ 0.5 ms per step on the owner's Mac (record what it is);
at 30 people no slower than before T-0077.

### B. Session and time-skip
9. **Split `game/session.gd`** into `Session` (owns the sim, stepping, speed, viewed level)
   plus `BugReporter`, `Autosaver` and `TimeSkip` helpers (plain classes or child nodes) that
   take the Session. No behaviour change; existing game tests keep passing; Session ends
   well under 300 lines.
10. **Time-skip spread over frames:** skipping runs at most `SKIP_STEPS_PER_FRAME` (e.g. 1,200)
    steps per frame until the action ends, with a "Skipping…" overlay and the clock racing.
    Esc stops it. `advance_minutes` from the UI does the same (the CLI may stay instant).

### C. Determinism you can trust
11. **Full-town save-and-continue test:** for seeds 1–3, `new_game`, run 6 game hours with
    free will, save at an odd tick, load, run both 6 more hours and compare JSON (one test;
    keep it under ~10 s). Include a payday and a shift boundary in one of the seeds.
12. **Purity lint gaps:** add rules for `static var` in `sim/` (only `const`/immutable
    allowed, with an allow-list comment for the existing two), `get_instance_id`,
    `instance_from_id`, `hash(` on objects, `JSON.parse`/`JSON.parse_string` outside
    `Ser`, `Thread`/`WorkerThreadPool`, `print(` in `sim/`, and transcendental maths
    (`exp(`, `pow(`, `log(`, `sin(`, `cos(`) with a message about cross-machine replays.
    Replace `Conversations.acceptance`'s logistic `exp()` with a rational or table-based
    curve that keeps the same shape (test the old and new values agree within 0.01 on a grid).
13. **Stable dice:** `Autonomy.choose` draws noise only for options that survive
    `MIN_SCORE`, or derives it from a hash of (tick, person id, object id, interaction id),
    so adding one bench doesn't reshuffle everyone's choices. Note in D-entry.
14. **The replay tool shouts on divergence** ("DIVERGED at tick N: <path>") — check
    `Replay.check` already does; if so, add a test that a forced divergence prints it.
15. **Typed free-will options:** replace the `Dictionary` options in `Autonomy` with a small
    `AutonomyOption` class (`target_id`, `target_kind` "object"/"person", `interaction_id`,
    `score`, `cells`) so a person id no longer hides in `object_id`.
16. **Save-field coverage check:** a test that, for each saved sim class with `to_dict`
    (Person, Employment, Wallet, Household, Lot, Action...), every script property is either
    in `to_dict()` keys or listed in that class's `NOT_SAVED` constant.
17. **CI:** cache the Godot download (actions/cache keyed by version), verify its SHA-256, and
    fail the job if the `LAST_TRAM_TESTS:` line is missing.
**Out of scope:** new gameplay, art, the LICENSE.

## Acceptance criteria
- [ ] Profile numbers before and after at 30/90/150 people in the notes; the target met or
  the gap explained.
- [ ] Each optimisation has a test that the behaviour is unchanged (candidates equal on
  sample worlds, or documented differences); `--check-m2` PASSED on seeds 1–3.
- [ ] Session split with all game tests passing; skip overlay screenshot
  `out/t0078-skip.png`; Esc stops a skip (game test).
- [ ] Full-town save-and-continue test; new lint rules with a sample violation each in a
  lint fixture; acceptance curve without `exp`; stable-noise test (adding an unrelated object
  far away doesn't change a person's next choice).
- [ ] `AutonomyOption`, save-field coverage test, CI cache and checksum.
- [ ] `tools/check.sh` passes; nothing weakened.

## Implementation notes
**Part A (measure and speed), merged 2 October 2026** (D32). `tools/simrun.sh --profile` prints
ms per step per system (`tools/profiled_system.gd`); `--extra-residents=N` adds N adults to
existing homes (cost only: beds run short). Numbers on the cloud machine (about 2.5× slower
than the Mac), one day, seed 1:

| people | before | after | biggest after |
|---|---|---|---|
| 28 | 0.259 ms/step (WorkSystem 0.104, Actions 0.074, free will 0.047) | 0.139 | Actions 0.067 |
| 88 | 0.828 | — | — |
| 148 | 1.755 (free will 1.19) | 1.328 (free will 0.87) | free will |

Done in A: items 2 (interactions per def, defs per interaction, free-will object set), 3 in
part (objects by tag and by lot instead of a bucket grid; candidates still scan ids within
the radius), 4 (exact pruning, `Autonomy.decide`, instead of a top-K guess), 6 in part
(workplaces by tag, home objects by lot; `Jobs.holder` still scans people), 8 in part
(`Pathfinder.path_length`; stairs-only segment cache keys), 13 (stable noise). WorkSystem now
checks "already at work or on the way" before working out the walk. Not done in A: 5
(background tier cadence), 7 (paths popped from the back), the per-level nav rebuild.
Behaviour: `test_decide_equals_choose_over_all_candidates`, `test_path_length_matches_find_path`,
`test_noise_ignores_other_options` (`tests/sim/test_free_will_speed.gd`); the dice change
re-rolled the towns, and a real flaw showed (no supper before bed); fixed with
`eat_before_bed` (`test_supper_before_bed`). `--check-m2 --check-staffing` pass on seeds 1–6
in both work modes; 0.125–0.16 ms per step on this machine.


## Questions

## Review feedback
