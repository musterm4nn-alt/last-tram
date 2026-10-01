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
