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

**D17 · Hard content rules.** Children are never targets of violence, crime interactions,
romance or sexual content; no sexual-violence mechanics; romance is adults-only and
fade-to-black. Enforced by data validation and tests once those systems exist.

**D18 · Tickets live in the repo; one agent at a time.** Markdown tickets with front matter,
a branch per ticket, Opus reviews and merges to `main`. GitHub (private) is the backup and
history.
