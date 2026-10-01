# Handoff: building M3 (Making a Living)

Rewritten on 1 October 2026, when M3 was planned. For the next Claude Code session (the
architect, Opus). Read it after CLAUDE.md and AGENTS.md, and keep it current as M3 goes on.

## Where things stand

- **M1** ✅ and **M2** ✅ are signed off by the owner (M2 on 1 October 2026: "didn't feel
  bad"). `tools/check.sh`: 463 tests pass in about 40 s. `tools/simrun.sh --days=7
  --check-m2` passes on seeds 1, 2 and 3.
- **M3 is planned** (D29 in `docs/decisions.md`, the M3 section of `docs/roadmap.md`,
  `docs/design/jobs-and-economy.md`): tickets T-0054 to T-0076. T-0054 (money), T-0055
  (prices and `Requirements`) and T-0056 (Späti, Imbiss, ATM, Sunday closing) are `todo` and
  fully specified. The rest are `draft`s: detail each one (exact interfaces, files, tests)
  against the merged code before building it, and keep `depends_on` accurate.
- Build in the order of D29 / the roadmap's ticket list. Every ticket keeps
  `--check-m2` passing (the town must stay healthy while the economy arrives).

## How the owner wants us to work

- **Opus builds tickets itself** (memory: build-tickets-myself). No OpenCode builders (Muse,
  DeepSeek) and no subagents unless the owner asks. Still: a branch per ticket, tests,
  `tools/check.sh`, the ticket notes, then merge.
- Talk in game terms; they don't read code. Show screenshots of visible changes.
- They play on a **MacBook**: no Page Up/Down. R/F are the floor keys; keep keys Mac-friendly.
- They launch the game with **"Last Tram" on the desktop** (`~/Desktop/Last Tram.command`).
  It imports first, then runs `/Users/xamxim/last-tram/tools/run.sh` (the main checkout).
- **Playbook** (https://claude.ai/artifact/LPBmF4KMEeaBRh5zrJNEk8): after each merge, add or
  tick that ticket's build stop (`ArtifactData`, collection `steps`). After planning, add
  build/review stops and a play stop. Never tick "You" stops.

## Mechanics of this setup

- Sessions run in a git **worktree**, and `main` is checked out in `/Users/xamxim/last-tram`.
  Merge like this:
  `git -C /Users/xamxim/last-tram merge --no-ff t/NNNN-slug`, then push `main` from there,
  then `git merge --ff-only main` back in the worktree and delete the branch.
- Never `--no-verify`, and never a bare `git stash` (use a tagged stash with its SHA).
- CI: `.github/workflows/check.yml` runs `tools/check.sh` on pushes to `main` and pull
  requests (Godot 4.7.1 on ubuntu-latest).
- After adding a `class_name`, run `tools/check.sh` (it imports) before `tools/test.sh`.
- Throwaway experiments: `godot --headless --path . --script res://out/x.gd` (`out/` is
  git-ignored). See memory "headless-godot-experiments". For golden values from `main`
  before a change, use a temporary worktree in the scratchpad.

## What M2 added (map for M3 work)

| Area | Where | Notes |
|---|---|---|
| Floors, stairs, floor view | `sim/world/pathfinder.gd`, `game/session.gd` (`page_level`), `level_1/2.txt` | 15 neighbour homes in Haus 5, 9, 3 and 14 |
| Lots (access, opening hours) | `sim/world/lot.gd`, `lots.gd`, `district.json` | Shops need `"hours"`. M3's "staff only" access goes here |
| Residents, households | `sim/people/resident_generator.gd`, `household.gd` | Households of 1–2 that fit the flat's beds (`bed_places`) |
| Routines | `data/routines.json`, `sim/ai/routines.gd` | Sleep and out windows. M3 work shifts are "obligations" (design: actions-and-autonomy) |
| Going out | `data/objects/public.json`, `data/interactions/going_out.json` | The drinks and coffee are free: M3 adds prices |
| Social | `sim/social/` (`Social`, `Conversations`), `data/interactions/social.json`, `data/moodlets.json` | Relationships, memories, moodlets, six interactions |
| Free will | `sim/ai/autonomy.gd`, `utility.gd` | Objects + people. Retry back-off (D27) |
| Bubbles, inspector, scenes | `game/ui/bubbles_layer.gd`, `person_inspector.gd`, `scene_popup.gd`, `data/dialogue/`, `data/scenes/` | View only |
| Tiers | `sim/systems/tier_system.gd`, `World.tiers` | v1 = update rates (D28); "Full lives" in the Esc menu |
| Town health check | `tools/town_check.gd`, `tools/simrun.sh --check-m2` | Copy this pattern for M3's 30-day economy check |

Decisions D26 (exact floats in saves: read save text with `Ser.parse_json`), D27 (cost of 30
people) and D28 (tiers v1) are in `docs/decisions.md`.

## Lessons that will bite again

- **Tests on `SimFactory.new_game` now include ~27 residents with free will.** Filter events
  by `player_id`, turn free will off for test people, and never assume "the first fridge" is
  the player's. Tests that move the clock back must also move every `last_input_tick`.
- **Measure the town before tuning.** Every tuning change in M2 came from a headless run plus
  a throwaway script (residents' needs, who sleeps where, who talks to whom). Several bugs (a
  third flatmate without a bed, beds against walls) only showed in week-long aggregates.
- Cost now: about 0.08–0.10 ms per step with 28 people (7 days in about 18 s). The budget in
  `--check-m2` is 0.25 ms. Free will (paths per candidate) is the main cost. Watch it when
  shops add many objects.
- The suite is at about 40 s (the convention says about 20). Prefer short runs in tests and
  week-long checks in `simrun`.

## Known gaps and ideas (not tickets yet)

- The café closes at 19:00, so only early birds have coffee in the evening. Consider daytime
  "out" uses (lunch at the Imbiss arrives with M3 shops).
- Residents nap a lot in the daytime (~90 naps a day across the town). It's harmless, but
  could be tuned.
- Scenes have no images: content may not hold art paths until the art direction gate.
- Social: no awkward/backfire outcomes, no gossip yet (memories exist, so gossip is
  M3/M4-ready). Mean exchanges are rare, because dislike builds slowly.
- Tiers: the event-driven background (next_wake_tick) waits for a second district (M7).
- The player's own bed has one usable side (fine for one person; matters for M6
  partners).

## Secrets and discoveries

The owner's idea (1 October) is designed in `docs/design/discoveries.md` and planned as
T-0067 to T-0070. Smaller ideas from the same prototype, for when a milestone fits: tuned
crime, heat, fine and debt numbers (M4), small furniture effects, pay that grows per shift,
and a read/act surface over save files for agent playtesting.
