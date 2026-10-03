# Handoff: continuing M3 (Making a Living)

Rewritten on 2 October 2026, when the previous session's context ran full; updated after
T-0077, when the owner moved the work to a Claude Code **cloud** session, and on 3 October,
when that session had built the rest of M3. For the next Claude Code session (the architect and builder, Opus). Read this after
CLAUDE.md and AGENTS.md. In the cloud, start with "Working in a cloud session" below.

## Working in a cloud session (read first in the cloud)

**The task there (2–3 October, done):** detail and build the M3 drafts, T-0065 to T-0076,
in D29 order. See "Where things stand". A new cloud session follows the same steps for
whatever the owner asks next; agent playtests need OpenCode on the owner's Mac.

What differs from the owner's Mac:
- **Godot.** The SessionStart hook (`tools/cloud_session_start.sh`) runs `tools/setup.sh`
  when `godot` is on the PATH. If it says Godot is missing, install 4.7.1 the way CI does
  (`.github/workflows/check.yml`: the `Godot_v4.7.1-stable_linux.x86_64.zip` release into
  `~/.local/bin/godot`), then run `tools/setup.sh`. The pre-commit hook needs it.
- **Git.** There is one clone, no worktrees: branch from `main`, then
  `git checkout main && git merge --no-ff t/NNNN-slug && git push`, and delete the branch
  locally and on GitHub. Ignore the `git -C /Users/xamxim/last-tram` lines below.
- **Screenshots work under a virtual display:**
  `xvfb-run -a -s "-screen 0 1280x720x24" tools/screenshot.sh out/tNNNN.png ...` (Godot
  prints Vulkan errors, then falls back to software rendering). Open the PNG and look at it.
  `tools/run.sh` (a window to play in) still needs the Mac.
- **The Playbook** (`ArtifactData`) may not be reachable. If it isn't, list in your final
  message which stops to tick or add (ids `t<nnnn>-build`), so the Mac session can do it.
- **No local memory.** The Mac session's memory notes don't travel. What matters from them:
  the owner wants Opus to write the code itself (no OpenCode builders, no subagents unless
  asked). Headless experiments go in a throwaway `out/x.gd` run with
  `godot --headless --path . --script res://out/x.gd`: call `quit.call_deferred(0)` first
  in `_initialize()`, never mention `Session` or `game/` classes there (they don't compile
  outside the game), and never write to `user://`. Check that a probe printed something:
  a compile error prints `SCRIPT ERROR` and nothing else.
- **Speed.** On the Mac the suite takes about 3 minutes and a 7-day `simrun` about 45 s.
  Run the six seeds one after another (`simrun.sh` shares `out/simrun.log`), or call
  `godot --headless --path . --script res://tools/sim_runner.gd -- --days=7 --check-m2
  --seed=N` directly to run several in parallel.
- **Before handing back:** everything merged and pushed, the ticket notes complete, and a
  short message for the owner in game terms. Back on the Mac, `main` in
  `/Users/xamxim/last-tram` needs `git pull --ff-only` before the desktop icon runs the new build.

## Where things stand

**Update, 3 October 2026 (end of the cloud session): M3 is done.** Every M3 ticket is built
and merged (T-0054 to T-0079), the owner signed M3 off, and `main` is tagged `m3`. The
owner's own playtest of T-0076's checklist (Playbook stop `play-m3`) is still to come; turn
what it finds into tickets. Next on the roadmap: the art direction gate. Save version 19; `tools/check.sh`
runs 685 tests. `tools/simrun.sh --days=30 --check-m3` passes on seeds 1–3, and
`--days=7 --check-m2 --check-staffing` on seeds 1–6 in both modes.

Built in the cloud session (2–3 October), in order: T-0065 staffed counters (save v12),
T-0066 eviction and moving (v13), T-0067 to T-0070 secrets and discoveries (v14), T-0071
skills (v15), T-0072 wardrobe (v16), T-0078 robustness and speed (D32), T-0073 clothes rail
and barber in the Waschsalon (v17), T-0074 laundry (v18), T-0079 lone workers (D33), T-0075
backgrounds (v19), T-0076 the M3 check. The M3 save steps live in
`sim/save/save_migrations_m3.gd`.

**Left for the Mac:**
- Screenshots: all the M3 ones were taken and checked in the cloud on 3 October (the
  Späti clerk, Housing, Notebook, map, wardrobe, clothes rail, a secret's scene, the skip
  overlay, the Background tab). Taking them found and fixed two bugs (a long click-walk
  ended with free will sending you home; "Woke up" after a shift): see T-0076's notes.
- The Playbook is up to date: build stops for T-0066 to T-0079 are ticked, and two new play
  stops wait: `play-m3-muse` (an agent playtest, OpenCode) and `play-m3` (the owner's; never
  tick it yourself).
- An agent playtest of a working week (Muse in OpenCode), before or with the owner's.
- After `git pull --ff-only` on the Mac, the desktop icon runs the new build.

**Balance note for M4:** money piles up. In 30 days the town earns more in wages than it
spends; nobody gets near broke, so the safety nets (benefit, eviction) are only exercised by
tests. Tune rents and prices when crime makes money a motive, and re-run `--check-m3`.

## Owner decisions still open or recent

- **LICENSE:** the owner will decide later. Don't add one.
- **Distinct job profiles** (2 Oct): yes, but switchable. Built in T-0077 (varied by
  default, "Work: Gentle" in the Esc menu). The profiles had to stay mild (D31).
- **Conversations are judged over a full week** (2 Oct, approved by the owner as a change to
  a frozen acceptance rule): the suite's two-day town check no longer applies the
  "talks with people" rule (D31).
- The owner wants **agent playtests** for play steps: Muse Spark 1.3 (free, xhigh) in
  OpenCode, run by Opus unattended (`docs/playtesting.md`, memory "agent-playtests"). Two
  were done (shopping; a working week). Do one after T-0077 and after T-0065/T-0066. Ask the
  owner for a **human** playtest of a working week before M3 is called done.
- Process changes after the reviews: acceptance rules are frozen per milestone
  (`docs/workflow.md`) and milestones are tagged (`m0`–`m2`; tag `m3` at its sign-off).
  Still waiting for the owner: an independent adversarial reviewer (a different model) for
  saves, money and time handling.

## October reviews (summary, so you don't need the files)

Nine external reviews (2 October) agreed: the architecture, determinism, saves and tests
are strong. The criticism that held up became T-0077 and T-0078:
- Shift bugs: split shifts counted twice, pre-shift cancel penalised, a mid-shift old save
  marked missed, wage cents lost per segment (T-0077 A).
- The town check was bent to pass: every shift counted as a meal and social contact, and all
  jobs share one gentle profile (T-0077 B: lunch as a real meal, colleagues reported apart,
  varied jobs with a gentle switch, frozen acceptance rules).
- Hard-coded balance numbers, hygiene before critical hunger, colleagues counted without
  attending, a repeating warning, stale queues, refused clicks counting as input (T-0077).
- Stale README (still "M1 in progress"), stale architecture module plan, AGENTS.md vs
  CLAUDE.md drift, old branches, no tags (T-0077 C).
- Scale: free will scans and pathfinds too much; background tiers don't make it cheaper;
  `session.gd` at 346/350 lines; time-skip runs 28,800 steps in one frame; lint blind spots
  (`static var`, `JSON.parse`, `exp()` in `Conversations.acceptance`); dice draws depend on
  option count; the main save-and-continue test runs in a tiny room (T-0078).
- Rejected or already true: saves are written atomically; ages under 18 are rejected loudly
  at load and in the creator (the clamp is only the last defence).

## How the owner wants us to work

- **Opus builds tickets itself** (memory: build-tickets-myself). No OpenCode builders and no
  subagents unless the owner asks; Muse in OpenCode only playtests. Still: a branch per ticket, tests,
  `tools/check.sh`, the ticket notes, then merge.
- Talk in game terms; they don't read code. Show screenshots of visible changes.
- They play on a **MacBook**: no Page Up/Down. R/F are the floor keys; keep keys Mac-friendly.
- They launch the game with **"Last Tram" on the desktop** (`~/Desktop/Last Tram.command`).
  It imports first, then runs `/Users/xamxim/last-tram/tools/run.sh` (the main checkout).
- **Playbook** (https://claude.ai/artifact/LPBmF4KMEeaBRh5zrJNEk8): after each merge, add or
  tick that ticket's build stop (`ArtifactData`, collection `steps`; orders are 1000+ for M2,
  1100–1230 so far for M3). Record agent playtests as done "play" stops (`where`:
  "OpenCode"). Never tick "You" stops (the owner's `play-m2`, `play-shops` are theirs).

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

## What M3 added (map)

| Area | Where |
|---|---|
| Money, ledger, statement | `sim/economy/money.gd`, `wallet.gd`, `ledger.gd`, `data/economy.json` |
| What a person may do now | `sim/actions/requirements.gd` (closed, private, cant_afford, no_food, fridge_full, not_your_job, not_your_shift) |
| Shops, ATM, Sunday closing | `data/objects/shops.json`, `data/interactions/shops.json`, `Lot.closed_days` |
| Groceries | `sim/economy/groceries.gd`, `Household.groceries`, errands in `Autonomy.errand` |
| Jobs and work | `data/jobs.json`, `sim/jobs/` (`Jobs`, `Employment`, `WorkSession`, `RabbitHoleWork`, `WorkSessions`, `Careers`, `Hiring`), `data/objects/workplaces.json` (tram shelter, police desk), staff slot roles |
| Weekly cycle | `sim/systems/work_system.gd`, `economy_system.gd`, `sim/economy/housing.gd` |
| Home needs first, colleagues | `Routines.home_needs`, `AutonomySystem._see_to_home_needs`, `Jobs._know_colleagues` (D30) |
| Phone | `game/ui/phone/` (Phone, BankApp, JobsApp, ContactsApp), `CallCommand`, remote interactions |
| Reports | `tools/sim_runner.gd` lines: money, groceries, jobs, work, housing, staffed, economy |
| Staffed counters | `sim/jobs/on_site_work.gd`, `staffing.gd`, `InteractionDef.staffed` |
| Eviction, moving, sleeping rough | `sim/economy/moving.gd`, `RentFlatCommand`, `game/ui/phone/housing_app.gd` |
| Secrets and discoveries | `data/discoveries/`, `sim/discoveries/`, `sim/systems/place_actions.gd`, `game/ui/phone/notebook_app.gd` |
| Skills | `data/skills.json`, `sim/people/skills.gd`, `JobLevel.requires` |
| Clothes, laundry, looks | `sim/people/wardrobe.gd`, `shopping.gd`, `laundry.gd`, `presentation.gd`, `game/ui/wardrobe_screen.gd`, `shop_screen.gd` |
| Backgrounds | `data/backgrounds.json`, `sim/people/backgrounds.gd`, `game/ui/creator_background_tab.gd` |
| Economy check | `tools/economy_check.gd`, `tools/simrun.sh --days=30 --check-m3` |

## Lessons that will bite again

- **The honest town check is a knife edge for lone workers** (T-0077). A few people who
  live alone and work long shifts sit right at "3 conversations a week". Global levers move
  it a lot: talk-while-out 1.0 gave five times the conversations. New towns give workers
  the routine that leaves the most evening out (`Jobs.routine_fit`); check both modes.
- **Workers' days are tight.** Any change to needs, jobs or free will can make someone go to
  bed unwashed or hungry. Run `tools/simrun.sh --days=7 --check-m2` on seeds 1–6 and use the
  probe pattern from the M3 work (a throwaway `out/*.gd` that prints a failing person's last
  30 events) before tuning. Rules that made it work are in D30.
- A free-will filter or floor that looks right can wreck the social life of the town or
  double the cost; measure exceptions on several seeds (D30 lists two rejected ideas).
- Headless `out/*.gd` scripts can't use `game/` classes (Hud, InteractionMenu,
  PersonInspector): they reference the `Session` autoload.
- Building in a second worktree while Muse playtests in the first works well
  (`git worktree add --detach <scratchpad>/x main`, then import once).

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
