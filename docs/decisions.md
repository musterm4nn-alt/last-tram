# Decisions

Settled decisions and why. Don't re-open them inside a ticket. If you think one is wrong,
write it in the ticket notes for the architect. **Only the architect edits this file**; new
decisions are appended with the next number.

**D1 · Godot 4.7 with typed GDScript.** Scenes and scripts are plain text that every agent can
read and edit; the engine is free and light. GDScript over C#: no build step, and every model
knows it well. Untyped declarations are compile errors (`project.godot`), because typed code
catches mistakes at parse time and nobody reads the code by eye.

**D2 · Pure simulation, separate view.** `sim/` holds all state and rules as plain
`RefCounted` objects; `game/` only draws and sends Commands. This allows headless tests, long
simulation runs, replays, and swapping the 2D view for 3D isometric later without touching
game logic. Lint-enforced.

**D3 · Grid world, 1 cell ≈ 1 m, levels, walls occupy whole cells.** Cells are
`Vector3i(x, y, level)`. Whole-cell walls (not Sims-style thin walls on edges) keep
pathfinding, ASCII authoring, collision and a later 3D conversion simple. The trade-off is
chunkier walls; that's accepted.

**D4 · Seamless interiors.** Buildings are part of the one world grid; no separate interior
scenes. NPCs walk in and out naturally, and roofs hide when you're inside.

**D5 · Fixed-step deterministic sim.** 20 steps per game minute; 1 game minute per real second
at 1x (a day is 24 real minutes). Integer tick counter, seeded random streams, no real time
in sim.

**D6 · Commands in, events out, ids not references.** The only way to change the sim is a
serializable Command. The sim reports what happened as events. Saved state references
entities by integer id.

**D7 · Content is JSON plus ASCII maps, validated at load.** It's readable and writable by any
agent, and diffable. `ContentDB` collects errors instead of crashing, and a test requires zero
errors. Saves store content ids, never indices.

**D8 · Saves are versioned JSON with migrations and fixtures.** Readable and debuggable.
Every format change bumps `SAVE_VERSION`, adds a migration step and a fixture save, so old
saves keep loading.

**D9 · Tiered NPC simulation with one data model.** Everyone has the same full data; tiers
only decide update frequency and detail (full near the player, abstract elsewhere). A
fidelity dial can raise it to "full lives for everyone".

**D10 · Jobs behind a `WorkSession` interface.** Rabbit hole by default, and on-site
(counter) jobs for visible staff. Playable jobs replace individual implementations later.

**D11 · Systemic social first; LLM dialogue later behind `DialogueProvider`.** Outcomes are
decided by the systemic model (deterministic, testable). An LLM may only write the words, never
change sim state.

**D12 · Placeholder art first; art route decided at the gate after M3.** 16 px tiles for now
(`ViewConfig.TILE_PX`, one constant). Opus owns all art work.

**D13 · UI, input bindings and node trees built in code.** Minimal `.tscn` files, because
hand-edited scene and input blobs are where agents make mistakes. The exception is a scene an
editor-authored asset really needs.

**D14 · Own tiny test runner, no addons.** `tests/runner.gd` has no third-party code and no
version drift. It fails a test when any error is logged during it, and prints a sentinel line
because Godot's exit code is unreliable when a script fails to parse.

**D15 · The player is a Person.** Same rules and systems as every NPC. Direct control (WASD)
and command mode (click) are two front ends to one action system. Switching to another
character later is trivial.

**D16 · Ageless sandbox.** No forced ending; ageing is a setting (off by default). Player
death means hospital and a bill. NPC death is permanent, and newcomers move into empty homes.

**D17 · Hard content rules** (revised 2026-09-27 by the owner). There are **no children or
teenagers** in the game: every person is 18 or older. **No pregnancy or childbirth** (and no
adoption). No sexual-violence mechanics. Romance is in, and intimacy fades to black. Enforced by
data validation (the age minimum can't go below 18) and tests over every person the game
creates.

**D18 · Tickets live in the repo; one agent at a time.** Markdown tickets with front matter,
a branch per ticket, Opus reviews and merges to `main`. GitHub (private) is the backup and
history.

**D19 · Detailed character creation; appearance is sim state.** The player designs their
character: name, gender and pronouns, age, body, face, hair and outfit, and later
personality, background and attraction. The depth is inspired by Degrees of Lewdity's creator
and wardrobe, with none of its sexual content. Identity, appearance and outfit are saved sim
state on every Person (NPCs are generated from the same data) and validated by
`CharacterSpec`. Placeholders draw from appearance data now; the layered sprites chosen at the
art gate will use the same data.

**D20 · Data-only content packs; the core stays off-screen; an adult layer for the owner.**
The owner can add or override content with data-only packs (JSON and images, never code),
stored outside the repo in the game's user data folder. The core game presents intimacy
off-screen (a fade-to-black scene) and never contains explicit content; no agent writes any.
An "Adult content packs" setting (off by default, 18+ confirmation) lets the owner's own packs
replace that presentation. Engine-enforced rules (adults only, mutual consent, never tied to
crime, violence or incapacity) apply to all content, and no pack can change them. Details:
`docs/design/content-packs.md`.

**D21 · No bladder need.** The owner removed the bladder need and toilet gameplay from the
game and the plan. People have six needs (hunger, energy, hygiene, fun, social, comfort), and
the M1 flat has no toilet object. Saves from before the change load fine: `World.from_dict`
drops any need the content no longer defines, as it already fills in new ones.

**D22 · Content loading is split by kind; code files stay under 350 lines.** `ContentDB` holds
the loaded content and its queries. Each kind of content has a static `*Loader` in
`sim/content/` that reads through a `ContentReader` (which collects problems instead of
crashing), and `ContentDB.load_from()` calls the loaders in dependency order. Loaders never
touch `ContentDB`'s private fields; they use helpers like `add_terrain()`. A lint test fails
any file in `sim/`, `game/` or `tools/` over 350 lines, so big files are split before they get
hard for builders to work in (T-0022).

**D23 · Actions run before movement and needs.** Each step runs `ActionSystem`, then
`MovementSystem`, then `NeedsSystem` (T-0006). Actions go first so that a queued action can
start, or (T-0007) set the path to its slot, before anyone moves in the same step; they run
before needs so that one minute of an action nets its rate minus the normal decay. A running
action changes needs through its per-hour `need_rates` on top of decay, plus one-off
`finish_needs`; the queue (`Person.action_queue`, at most 6) is saved.

**D24 · M1 autonomy and home content.** Until lots and personalities exist (M2), autonomy
scores every interaction on objects within 12 cells (same level):
Σ urgency(need) × min(advertised gain, room left in the need) − 0.1 per cell of walking, adds
0..1 noise, ignores options under 3, and picks among the best three weighted by score
(T-0012). Capping the gain by the room left keeps a rested person from wanting a full night's
sleep. The idle player acts after 10 game minutes without input; free will is on by default
and switched in the Esc menu (T-0025). The flat gets a small bathroom and a desk with a
laptop whose video calls fill Social, the only social source until the phone (M3) and
neighbours (M2). An architect prototype of these rules kept every need above 40 for three
game days.

**D25 · M2 order: houses, people, social life, then scale.** M2 is planned as T-0030 to
T-0045: stairs and upper floors first (the ~30 residents need flats), then lots with access
rules and personality, generated residents and households, their free will and daily
routines, then relationships, memories, social interactions, bubbles and the inspector,
then simulation tiers (built once there is a real town to measure), scenes, personality in
the creator, and the 7-day acceptance run. Only the first three tickets are fully specified;
the rest are drafts detailed as their foundations land. Access rules are checked by free will
and routing, not baked into the pathfinding graph (one shared graph stays cheap); trespassing
is M4.

**D26 · Exact floats in saves.** Godot's JSON parser reads about one float in ten back a
little off (measured 9.5% of random values, at every precision we tried), which broke "save
mid-run equals uninterrupted run" once the town had 30 people. `Ser.to_json` now writes a
float that would not read back exactly as `"#f64:"` plus its 8 bytes in hex, and
`Ser.parse_json` turns it back. Floats that survive stay plain numbers, so saves remain
mostly readable and old saves load unchanged. Alternatives rejected: fixed-point needs and
positions (a large change for every system), and a binary save format (unreadable,
undiffable).

**D27 · A town of 30 must stay cheap.** Residents made a simulated day 27× slower, mostly
free will re-planning for content people every minute and per-step slot checks. Fixes:
free will that finds nothing waits five minutes (saved per person); a performing action
checks its slot and target fully once per personal minute, before benefits apply (input and
paths, the only ways to move, are still checked every step); `ContentDB.place_at` and
`Lots.by_place` use derived indexes. Real paths are still computed for every candidate slot,
so free will's choices keep using true walking distances.

**D28 · Simulation tiers v1 = update rates.** The design's background tier is event-driven
(next_wake_tick, travel estimates, encounters rolled per window). For a 72×44 town of 31
people, a much smaller change gives the same behaviour: background people keep all their
data and rules, and their action and movement steps run once per game minute instead of every
step. Aggregates match full detail within a few percent over 3 days (T-0042), and the cost
drops 37% at a 10-cell radius. Promotion and demotion need no placement logic. The event-driven
background comes back when a second district (M7) makes it worth its complexity.

**D29 · M3 order and the economy model.** M3 is planned as T-0054 to T-0076. Money comes
first (wallet, ledger), then prices with one shared check for what a person may do, the shops
and the fridge. Jobs follow (data, the work action, leaving on time, pay and performance),
then rent and benefit, the phone, applying for jobs, staffed counters and eviction. After
those come the discoveries the owner asked for, skills, clothes, backgrounds and the 30-day
acceptance run. The key choices:
- **Money is integer euro cents, per person**: cash in the pocket and a bank account.
  Households do not share money until joint accounts arrive with M6. The world's `Ledger`
  keeps totals by reason, split into sources (starting money, wages, benefit, pension, finds)
  and sinks (purchases, rent, bills). The money people hold always equals sources minus sinks,
  which makes "money is conserved" a cheap test. The full transaction stream is the
  `money_changed` event (output only). Each person also keeps their last 20 changes for the
  bank app.
- **The economy is open.** Employers, shops, landlords and the state are outside parties with
  no accounts, so the town cannot drain itself by simulating businesses' cash flow. Business
  accounts arrive with business ownership (backlog).
- **One requirements check.** `Requirements.check(sim, person, interaction, target)` returns
  "" or a reason (closed, not your home, not enough money, and later no food, nobody serving,
  not your shift, an unknown secret). The menu (greyed out, with the reason), commands, free
  will and the action system all use it, so a new rule is written once.
- **Work is an action.** Working is a `work` interaction on a workplace object, and the job's
  `WorkSession` drives it each minute (D10). In a rabbit-hole job the person is hidden: they
  went into the station, or took the tram from the stop. In an on-site job they stand behind
  the counter. Routing, slots, saving, tiers and cancelling (leaving work early) come from the
  action system.
- **Jobs are positions.** A position is one job plus one shift pattern (days and hours).
  Residents fill positions when the town is generated. Shop staff positions are always filled
  (shops sell only while staffed); the others are filled only partly, so there are vacancies.
- **The weekly cycle.** Benefit and pensions are paid on Monday at 06:00, rent and bills are
  due on Monday at 08:00, and wages are paid on Friday at 18:00. Unemployment benefit also
  covers the person's share of the rent (like German housing costs), so unemployment alone
  does not cause evictions. Eviction comes after three weeks behind on the rent.
- **Items: groceries only.** In M3 the only items are groceries: each household has a stock of
  portions in its fridge. A personal inventory comes with M4, when stolen goods, drugs and
  tools need one. Discoveries v1 have no `item` effect.

**D30 · A working day must leave room to live.** With 8–9 hour shifts (T-0060), residents
went to bed unwashed, went out hungry and hit zero fun and comfort, and `--check-m2` failed.
Fixes (measured on seeds 1–6, all passing a week):
- **Jobs look after people a little:** lunch and breaks at work cancel hunger's decay (+6 an
  hour) and soften fun and comfort (+4 and +6). Shop and bar staff work Mon–Thu or Fri–Sun,
  not every day. Shifts must leave an hour awake before them, and an `early_shift` routine
  (asleep 21–5, given only to people whose shift needs it) covers 06:00 starts.
- **One shower a day is enough:** a shower gives 85 hygiene (a day costs about 80), and
  hygiene weighs 1.2 in free will, like hunger.
- **Home needs come first:** before free will picks anything, someone with hygiene under 45,
  hunger under 35 or any other need under 30 goes and does the best thing for it at home
  (`Routines.home_needs`). A hungry person with no food at home goes to the shops or the
  Imbiss, and a fridge running low triggers a grocery run while the Späti is open. Hunger
  below its critical level wakes a sleeper. Free will still decides everything else, so
  evenings stay varied.
- **Colleagues** in the same job who work the same day get to know each other a little after
  each shift (+10 familiarity, +3 friendship). Workers chat less around town, and colleagues
  are where working people meet others.
- `TownCheck` counts a finished shift as a meal (lunch) and as social contact (colleagues).
Rejected: filtering free will to an urgent need's options (it got worse and twice as slow),
and dropping options under half the best score (it made the town much less sociable).

**D31 · Hardening after the October reviews (T-0077).** Nine external reviews found real
bugs in shifts and a town check bent to pass. Decided:
- **A shift is settled once.** It is identified by its scheduled start. Every stretch of work
  adds the minutes that fall inside its window (`Employment.shift_minutes`), and the shift is
  settled once after the window ends: pay (rounded once), one lateness judgement from the
  first arrival, `shifts_worked`, colleagues and the moodlet. "Left early" means the minutes
  worked plus lateness fall more than 30 short of the shift. Minutes before the window
  aren't attendance; a shift with none is missed.
- **The town check is honest** (supersedes the last point of D30). Lunch at work is a real
  meal (`meal_eaten`), not hunger +6 an hour: once a shift, after 3 hours of work, or sooner
  when hunger falls below the home "eat" level. Colleague days are reported apart and are
  not social exchanges. Acceptance rules are frozen per milestone (`docs/workflow.md`).
- **Critical needs come first** at home: any need below its `critical_below`, then hygiene,
  hunger and the rest.
- **Jobs differ, switchably** (the owner, 2 October). Each job has its own need profile;
  `World.work.gentle` (the Esc menu's "Work: varied / gentle") switches every job to the
  shared gentle profile. Varied is the default. Measured on seeds 1–6, the differences had
  to stay mild. Energy costs of −2 an hour, or comfort of +3 to +4 on a 9-hour shift, sent
  fun or comfort to 0 for many workers, because tired workers nap instead of living. So a
  desk is restful (comfort +7, energy +0.5) but dull (fun +2.5). Manual work is tiring
  (energy −1.5) and social (+5). Bar work is fun (+7) and the most tiring of the evening
  jobs (energy −1). Imbiss and police are harder on comfort (+5, +5.5). Care work is
  draining (energy −1, fun +3.5) and gives "helped someone" after each shift.
- **The honest check exposed lonely workers.** Without colleagues counting, a few people
  living alone had only 1–2 conversations a week, in both modes. Two causes, both fixed in
  the town: an evening shift that swallowed a person's whole going-out window (a 14–22
  police shift for an early bird), so new towns now give a worker the routine that leaves
  the most going-out hours free (`Jobs.routine_fit`); and friendly talk while out pulled
  less than a drink, so `Routines.SOCIAL_OUT_SHARE` went from 0.8 to 0.9 (about a third more
  conversations; 1.0 made five times as many and was rejected). Lowering the social rates
  at work was tried and rejected: comfort fell to 0 for others.
- **Conversations are judged over a full week** (the owner's approval, 2 October 2026, a
  change to a frozen acceptance rule). With honest counting, on the first two days (both
  workdays) one to four working loners per town hadn't talked to anyone yet, while over a
  week everyone passes. `TownCheck` applies the "talks with people" rule only from 7 days
  (`SOCIAL_MIN_DAYS`), so the suite's two-day check covers meals, sleep and needs. An
  evening-shift routine (out in the afternoon) was tried for it and rejected: it made
  two of the week-long runs fail.
- Balance numbers that were constants (home thresholds, leaving for work, pocket money,
  colleague changes, lunch) are in `data/needs.json` "home" and `data/economy.json`.

**D32 · Free will at scale: same choices, fewer walks (T-0078 A).** Measured first
(`tools/simrun.sh --profile --extra-residents=N`): at 28 people the biggest cost was
WorkSystem recomputing every worker's walk to work each minute for hours, and in big towns
free will's per-option work (who holds a slot, which objects stand in your home, A* per
slot). Rules that came out of it:
- **Noise per option is a hash**, not a draw per option: one draw per decision (a salt),
  then `Autonomy.noise(salt, target, interaction)`, plus the final pick. Adding an unrelated
  object no longer reshuffles everyone's dice. (Every town re-rolled once with this change.)
- **`Autonomy.decide` = `choose(candidates())`, exactly** (a test checks it on a whole town):
  options are tried by an upper bound (score without the walk, minus the straight-line
  distance, plus noise) and walks are worked out only while an option could still make the
  best three. `candidates()` stays the full list for tests and errands.
- **Derived indexes** in `World` and `ContentDB` (rebuilt from state, never saved): objects by
  tag and by lot, interactions per object def, def ids per interaction, taken slots per
  decision. `Pathfinder.path_length` counts a route without building it.
- **Supper before bed**: in their sleep window people eat first when hunger is below
  `eat_before_bed` (55; `data/needs.json`). With the new dice a worker who skipped supper
  woke up starving and the two-day check failed: the game was wrong, not the check.
Result on the cloud machine (about 2.5× slower than the Mac): 28 people 0.259 → 0.139 ms per
step, 148 people 1.755 → 1.328 ms (about 0.53 ms on the Mac, the target was 0.5).

**D33 · A video call is half a conversation (T-0079).** The town check's "talks with people"
rule (frozen, D31) kept failing on lone early-shift workers in some towns: out from 15 to
19 while the town works, they filled their social need with 45-minute video calls (+45
social) and never looked for company. Measured on seeds 1–12 in both work modes (24 weeks):
with calls at half strength (30 social per hour, advertising 25) the quietest resident of
any town talks 9 or more times a week (was 0–3 in four runs, two failing) and the average of
the towns' median counts moves from about 110 to 115. Rejected: small talk with every server
(T-0065; every purchase would count as a conversation), and changing the rule. Calls still
help a lonely evening; they just don't replace the town.
