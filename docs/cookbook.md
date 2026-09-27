# Cookbook

Step-by-step recipes for common changes. They follow the existing code; when in doubt, copy
the pattern of the nearest existing example. Run `tools/check.sh` at the end of every recipe.

---

### Add a terrain type

1. Add an entry to `data/terrain.json` with a unique `id`, a unique one-character `glyph`, and
   all fields (`walkable`, `blocks_sight`, `indoor`, `surface`, `path_cost`, `debug_color`).
   `path_cost` (at least 1.0) is how much people avoid walking on it: pavements and floors 1,
   grass 1.5, road and tram tracks 4. Non-walkable terrain uses 1.0.
2. Use the glyph in a district map.
3. If it needs a special placeholder look, add a case in
   `game/view2d/placeholder_tiles.gd::_paint`.

### Edit the town map or add a place

- Maps are `data/world/districts/<id>/level_<n>.txt`. Every row must be the same length.
  Replace characters; don't insert or delete them.
- Places (named areas) are in that district's `district.json` → `places`, with local
  coordinates `rect: [x, y, width, height]`. Put small places before big overlapping ones.
- Check it: `tools/check.sh`, then `tools/screenshot.sh out/map.png --zoom=0` and look.

### Add a Command (a new way for the outside to change the sim)

1. Create `sim/commands/<verb>_<thing>_command.gd`:
   ```gdscript
   class_name WalkToCommand
   extends Command
   ## Command mode: walk the person to a cell using pathfinding.

   var person_id: int = 0
   var target: Vector3i = Vector3i.ZERO

   func _init(p_person_id: int = 0, p_target: Vector3i = Vector3i.ZERO) -> void:
       person_id = p_person_id
       target = p_target

   func type_id() -> String:
       return "walk_to"

   func apply(sim: Sim) -> void:
       var person := sim.world.get_person(person_id)
       if person == null:
           return  # invalid commands are ignored
       ...

   func to_dict() -> Dictionary:
       return {"person_id": person_id, "target": Ser.cell(target)}

   func load_dict(d: Dictionary) -> void:
       person_id = int(d["person_id"])
       target = Ser.to_cell(d["target"])
   ```
2. Add `"walk_to": return WalkToCommand.new()` to `CommandRegistry.create()`.
   (`tests/sim/test_commands.gd` fails until you do.)
3. Send it from game code: `Session.submit(WalkToCommand.new(player.id, cell))`.

### Add a system

1. Create `sim/systems/<name>_system.gd` extending `SimSystem`; override `step()` (every
   3 game seconds, keep it cheap) and/or `on_minute()`.
2. Add it to `Sim.default_systems()` in the right order, and explain the order in a comment if
   it matters.
3. Keep no state in the system; put state on the entities (and save it).
4. Randomness: `var r := sim.rng.stream("<name>")`.

### Add a field to Person (or any saved entity)

1. Declare it with a type and default, plus a `##` comment (units!).
2. Add it to `to_dict()` and `from_dict()` (convert types on load: `int()`, `Ser.to_vec2()`).
3. Is it a new *shape* of save data that old saves don't have? Then either read it with a
   default (`d.get("stress", 0.0)`) **or** bump the save version (next recipe). Prefer the
   version bump when the meaning of existing data changes.
4. `tests/sim/test_save.gd` must still pass. It will catch a field you forgot to save.

### Change the save format

1. Bump `SaveCodec.SAVE_VERSION` (for example 1 → 2).
2. In `SaveMigrations`, write `static func _v1_to_v2(d: Dictionary) -> Dictionary` that
   upgrades the dictionary, and add `1: d = _v1_to_v2(d)` to the `match` in `migrate()`.
3. `tools/make_fixture_save.sh` writes `tests/fixtures/saves/v2_basic.json`. Commit it.
   Never edit or delete old fixtures.

### Add a new kind of content (objects, interactions, jobs...)

1. `sim/content/<thing>_def.gd` with typed fields and `##` docs.
2. `data/<things>.json` (or a folder of files) with a `"_doc"` key.
3. `sim/content/<thing>_loader.gd`: a `<Thing>Loader` (RefCounted, static functions only)
   with `static func load(db: ContentDB, reader: ContentReader, path: String) -> void`.
   Read every field through the reader (`reader.read_str/read_num/read_bool/read_arr/
   read_obj/read_str_array`), report problems with
   `reader.error("<file>: <thing> '<id>': <problem>")`, validate every reference (for
   example, an interaction's `object_tags` must exist on some object) and store the results
   in `db`. Copy `sim/content/needs_loader.gd`. Never touch `ContentDB`'s `_private` fields:
   if it keeps an index, give it a helper like `add_terrain()`.
4. In `ContentDB`: a field `things: Dictionary[String, ThingDef]`, a query
   `thing(id) -> ThingDef` (null if unknown), and one line in `load_from()` that calls the
   loader after everything it references.
5. Tests: the real data loads without errors (`test_content.gd`), and a broken example in
   `tests/fixtures/content_broken/` is reported with a clear message.

### Tell the view something happened (events)

1. In the sim: `sim.emit_event(&"object_placed", {"object_id": obj.id})`.
2. In a view: connect `Session.sim_event` and `match event["type"]`. Also handle the full
   rebuild in the `Session.game_loaded` handler, because events are not replayed after
   loading.

### Add something to the screen

- World things: a `Node2D` class in `game/view2d/`, created in code, positioned at
  `cell_or_pos * ViewConfig.TILE_PX`, drawing placeholders in `_draw()`.
- UI: a `CanvasLayer` or `Control` class in `game/ui/`, created in `game/main.gd`, built in code
  (see `Hud`). Read sim state in `_process`; send Commands on clicks.
- Prove it: `tools/screenshot.sh out/<name>.png [--debug] [--zoom=N]`, then open the PNG
  and check it. Mention the path in the ticket.

### Add a key binding

Add `"action_name": [KEY_X]` to `InputActions.KEYS`, then use
`event.is_action_pressed("action_name")` in `_unhandled_input`. Add it to the HUD hint line if
the player should know about it.

### Write a sim test

```gdscript
extends TestCase

func test_person_cannot_walk_through_a_wall() -> void:
    var sim := SimFactory.from_rows(content(), [
        "#####",
        "#@#.#",
        "#####",
    ])
    sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.RIGHT))
    sim.run_minutes(1)
    assert_true(sim.world.player().pos.x < 2.0 - Person.RADIUS)
```

Run only your file while working: `tools/test.sh --filter=movement`. Then run the full
`tools/check.sh`.

### Watch a system over time

Add a line for your system to `_report()` in `tools/sim_runner.gd`, then run
`tools/simrun.sh --days=3 --report-every=120`. Add a line to `game/ui/debug_overlay.gd`
for live play.
