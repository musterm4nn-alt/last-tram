# Architecture

How Last Tram is put together, and the rules that keep it changeable. **Only the architect
(Claude Code / Opus) edits this file.** Builders who think something here is wrong write that
in their ticket's notes.

## The one big idea: a pure simulation with a replaceable view

```mermaid
flowchart LR
    subgraph game["game/ (Godot nodes)"]
        input["Input<br/>PlayerController"] -->|Commands| session
        session["Session (autoload)<br/>steps the sim in real time"]
        view["view2d/ (later view3d/)<br/>WorldView, PeopleView, Camera"]
        ui["ui/<br/>HUD, menus, debug overlay"]
    end
    subgraph sim["sim/ (pure logic, RefCounted only)"]
        simcore["Sim<br/>clock · rng · world · systems"]
        content["ContentDB<br/>(data/*.json)"]
    end
    session -->|"submit(Command)"| simcore
    session -->|"step()"| simcore
    simcore -->|"events"| session
    session -->|"sim_event / game_loaded"| view
    session --> ui
    view -.->|"reads state"| simcore
    ui -.->|"reads state"| simcore
    content --> simcore
```

- **`sim/`** is the game. It holds all state and rules: time, the town grid, people, and later
  objects, needs, jobs, crime and so on. It is plain GDScript (`RefCounted`): no nodes, no
  scenes, no input, no rendering, no real time, no global randomness. It runs identically
  with or without graphics, which is why tests and `tools/simrun.sh` can run it headless.
- **`game/`** is a window onto the sim. It draws the state, turns input into **Commands**, and
  never writes sim state directly. The 2D view lives in `game/view2d/`; a future 3D isometric
  view would be a sibling `game/view3d/` reading the same sim.
- **`data/`** is content (terrain, districts, and later objects, interactions, jobs, names),
  loaded and validated by `ContentDB`.

These rules are enforced by lint tests (`tests/lint/`), not just by convention.

## Folder map

```
sim/                      pure simulation (no Nodes)
  sim.gd                  Sim: the root. step(), submit(), systems list
  sim_factory.gd          new games and ASCII test worlds
  core/                   SimClock, SimRng, EventLog, Command, CommandRegistry, Ser
  commands/               one file per Command subclass
  content/                ContentDB, ContentReader, one *Loader per kind of content, *Def
                          classes (the only sim code allowed to read files)
  world/                  World (all entities), WorldGrid (cells, levels, terrain)
  people/                 Person (later: needs, personality, skills, memory...)
  systems/                SimSystem subclasses (MovementSystem, later NeedsSystem...)
  save/                   SaveCodec, SaveMigrations
game/                     Godot side
  session.gd              autoload "Session": owns the Sim, runs it, loads and saves
  main.tscn / main.gd     entry point; builds views and UI; command-line options
  input/                  InputActions (bindings in code), PlayerController
  view2d/                 WorldView2D, PeopleView2D, PersonView2D, CameraRig2D, placeholder tiles
  ui/                     Hud, DebugOverlay
data/                     content JSON + district ASCII maps
tests/                    runner, TestCase base, sim tests, lint tests, fixtures
tools/                    check/test/run/simrun/screenshot/tickets scripts
docs/                     vision, roadmap, architecture, design/, conventions, cookbook, workflow
tickets/                  one markdown file per ticket
art/                      art sources and exports (after the art gate)
```

## The sim

### Time: fixed steps

- `SimClock.tick` counts steps. **20 steps = 1 game minute** (one step = 3 game seconds).
- `Sim.step()`: apply pending commands → every system's `step()` → `tick += 1` → if a minute
  just completed, every system's `on_minute()`.
- Fast per-step work (movement) goes in `step()`; everything else (needs, AI, schedules,
  economy) goes in `on_minute()` or on a coarser cadence checked inside it.
- `Session` runs `20 × speed` steps per real second (speed 0–3) and gives the view `alpha`
  (0..1) to interpolate between the last two steps. Game speed is a view setting, not sim
  state.

### State: World and entities

- `World` owns everything that changes: `grid`, `people`, and later `objects`, `lots`,
  `households`, `vehicles`...
- **Entities reference each other by integer id**, never by object reference, in anything that
  is saved. Ids come from `World.new_id()` and are unique across all kinds of entity.
- Derived caches (walkability, pathfinding graphs, spatial indexes) are allowed, but must be
  rebuildable from saved state and are never saved themselves. `WorldGrid.revision` tells
  caches when to rebuild.

### Systems

- A `SimSystem` has `step(sim)` and `on_minute(sim)` and **no state of its own**. The order is
  defined in one place: `Sim.default_systems()`.
- Planned order (grows milestone by milestone): commands → movement → actions → needs →
  autonomy → schedules → social → economy → crime/police → tiers.

### Input: Commands

- Everything that changes the sim from outside is a `Command` (in `sim/commands/`), queued with
  `Sim.submit()` and applied at the start of the next step. Commands validate themselves and
  are ignored if invalid.
- Commands serialize (`CommandRegistry`), so they can be saved (pending ones), logged, and
  **replayed**: the M1 bug-report tool reproduces a session from a save plus the command log.
- The same commands serve direct control, command mode and (later) scripted tests. Direct and
  Sims-style control are two front ends to one system.

### Output: Events

- `sim.emit_event(type, data)` records what happened ("person_spawned", later "action_started",
  "crime_witnessed" and so on). `Session` drains the queue every frame and re-emits each event
  as the `sim_event` signal.
- Events are output only: the sim never reads them, and they are not saved. After a load,
  views rebuild from state (`game_loaded`), then follow events.

### Determinism

Same content + same seed + same commands at the same ticks = **bit-identical state**. It is
tested (`test_save_and_continue_equals_uninterrupted_run`) and it is what makes replays, bug
reports and "run 30 days headless" tests trustworthy. To keep it:
- All randomness comes from `sim.rng.stream("<system name>")`, one stream per system.
- No real time, no frame time, no iteration over unordered collections whose order could vary
  (GDScript dictionaries keep insertion order, which is fine).
- Floats are fine (same machine, same results); saves store them at full precision.

### Content: data-driven, validated

- Content is JSON in `data/` plus ASCII maps for districts. `ContentDB` loads it once, checks
  every field and every cross-reference, and collects errors instead of crashing. A test
  requires zero errors. Each kind of content has its own static `*Loader` (terrain, needs,
  names, appearance, clothing, world...) that reads through `ContentReader`; `load_from()`
  calls them in dependency order.
- Saves store **ids**, not indices (the grid saves a terrain palette), so adding or reordering
  content never breaks saves.
- `debug_color` is the only view-related field allowed in content. Real art is mapped by id in
  separate art data (see [art.md](art.md)).

### Saving

- `SaveCodec` turns the Sim into a JSON-safe Dictionary and back. It is pure: `Session` does
  the file IO.
- `SAVE_VERSION` + `SaveMigrations` (one step per version) + a **fixture save per version** in
  `tests/fixtures/saves/`, which must always still load. Old saves survive updates.
- Every state field must be in the save. The "save mid-run equals uninterrupted run" test
  fails if something is missing.

## The game layer

- **Session (autoload)** is the only bridge: it owns `content` and `sim`, steps the sim,
  forwards events, and handles speed, save/load and the command log. Only Session advances
  time (lint-enforced).
- **Views** (`game/view2d/`) read state every frame and rebuild on `game_loaded`. They convert
  cells to pixels (`ViewConfig.TILE_PX`); the sim never knows about pixels.
- **UI** (`game/ui/`) is built in code (no hand-edited scene files) and reads state; buttons
  submit commands through `Session.submit()`.
- **Input** bindings are registered in code (`InputActions`), using physical keys so WASD works
  on QWERTZ.

## Verification (for an owner who doesn't read code)

| Tool | Proves |
|---|---|
| `tools/check.sh` | Everything compiles, all tests pass, and architecture rules hold. Runs on every commit (pre-commit hook). |
| `tests/lint/*` | sim/ purity, the game/sim boundary, and every script compiling. |
| `tools/simrun.sh` | The sim behaves over hours or days without graphics (reports grow with each system). |
| `tools/screenshot.sh` | What it looks like: agents open the PNG and check it. |
| F3 overlay | Live internals while playtesting. |
| F9 bug report + replay (M1) | Any bug the owner hits can be reproduced headless. |

## Built to be replaced

Each placeholder has a seam, so the real thing can replace it without touching the rest:

| Today | Later | The seam |
|---|---|---|
| 2D top-down view | 3D low-poly isometric view | The sim knows nothing about rendering. The grid already has levels. A `view3d/` reads the same state and events. |
| Tiered NPC simulation | "Full lives for everyone" | One Person model; a tier is just how often and how precisely a person is updated. Tier radius and intervals are settings (the fidelity dial). |
| Rabbit-hole jobs | Playable jobs | A `WorkSession` interface. Each job id maps to an implementation; the default is the rabbit hole. |
| Systemic social actions | LLM-written dialogue | Every social action produces a `SocialExchange` record; a `DialogueProvider` turns it into text. The LLM version only writes text and never changes sim state. |
| Walking and transit | Bikes, scooters, cars | Movement modes, surfaces (sidewalk, road, rail) in terrain data, and a generic Vehicle entity. |
| One district | Many districts | Districts are data with an origin; the world is their union. |
| Placeholder art | Real sprites or tiles | Art is looked up by content id with a fallback to the placeholder. `TILE_PX` is one constant. |
| Placeholder figures | Layered character sprites and portraits | Appearance and outfit are sim data (ids); the view maps ids to simple shapes now and to sprite layers later. |
| Core content only | The owner's own content packs, adult ones included | Packs are data-only folders loaded after `data/` through the same validators. Presentation goes through scene ids; packs add scene variants, and adult ones are used only when the adult setting is on. The guardrails live in sim code and validation, never in data ([design/content-packs.md](design/content-packs.md)). |

## Performance budget

- Target: 60 FPS at 3x speed with ~150 residents on an M-series Mac. Sim cost at most
  ~4 ms per frame.
- The F3 overlay shows sim ms per frame; `tools/simrun.sh` prints ms per step.
- If GDScript becomes the bottleneck, hot paths can move to C# or GDExtension later, behind the
  same classes. Profile first; the tiers exist to make this unlikely.

## Module plan (where upcoming systems will live)

| Milestone | Module | Location |
|---|---|---|
| M1 | Object defs, world objects, spatial index | `sim/content/object_def.gd`, `sim/world/world_object.gd` |
| M1 | Pathfinding (AStarGrid2D per level, derived cache) | `sim/world/pathfinder.gd` |
| M1 | Needs, mood | `sim/people/needs.gd`, `sim/systems/needs_system.gd` |
| M1 | Interactions and actions | `sim/content/interaction_def.gd`, `sim/actions/`, `sim/systems/action_system.gd` |
| M1 | Autonomy (utility AI) | `sim/ai/`, `sim/systems/autonomy_system.gd` |
| M1 | Identity, appearance, outfits, character specs | `sim/people/appearance.gd`, `outfit.gd`, `worn_item.gd`, `character_spec.gd`; `sim/content/appearance_catalog.gd`, `clothing_def.gd` |
| M1 | Main menu, character creator, portrait | `game/launch_options.gd`, `game/ui/main_menu.gd`, `name_screen.gd`, `character_creator.gd`, `character_portrait.gd` |
| M2 | Lots, households, residents | `sim/world/lot.gd`, `sim/people/household.gd`, `sim/people/generator.gd` |
| M2 | Relationships, memories | `sim/social/` |
| M2 | Simulation tiers | `sim/systems/tier_system.gd` |
| M2 | Scenes (presentation only) | `sim/content/scene_def.gd`, `data/scenes/`, `game/ui/scene_popup.gd` |
| M3 | Money, items, shops, jobs | `sim/economy/`, `sim/jobs/` (with `WorkSession`) |
| M4 | Health, crime, witnesses, police | `sim/crime/`, `sim/health/` |
| M5 | Build mode rules | `sim/build/` (commands + validation) |
| M5 | Content packs, settings | `sim/content/pack_loader.gd`, `game/settings.gd`, `game/ui/packs_screen.gd`, `examples/packs/` |
| M6 | Intimacy rules (consent, capacity, no crime) | `sim/social/intimacy_rules.gd` |
| M7 | Transit, vehicles | `sim/transport/` |
