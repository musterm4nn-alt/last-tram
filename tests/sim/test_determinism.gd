extends TestCase
## T-0078 C: determinism you can trust. The full town saved at an odd tick continues exactly
## like the uninterrupted run; the conversation curve needs no exp(); every saved class saves
## every field it has (or says why not).

## Saved sim classes and a fresh instance of each (save-field coverage).
const SAVED_CLASSES: Array[String] = ["Person", "Employment", "Wallet", "Household", "Lot", "Action",
	"WorldObject", "Relationship", "Memory", "Moodlet", "WorkSettings", "TierSettings", "Ledger",
	"Incident", "PoliceTask"]


func test_the_full_town_saves_and_continues_identically() -> void:
	for seed_value: int in [1, 2, 3]:
		var sim := SimFactory.new_game(content(), seed_value)
		if seed_value == 3:
			sim.clock.tick = SimClock.ticks_for(4, 14)  # Friday afternoon: payday at 18:00
			for person: Person in sim.world.people.values():
				person.last_input_tick = sim.clock.tick
		sim.run_minutes(6 * 60)
		sim.run_steps(7)  # an odd tick, mid-minute
		var errors: Array[String] = []
		var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
		assert_true(loaded != null, "seed %d: %s" % [seed_value, errors])
		if loaded == null:
			continue
		sim.run_minutes(6 * 60)
		loaded.run_minutes(6 * 60)
		var difference := Replay.first_difference(SaveCodec.to_dict(sim), SaveCodec.to_dict(loaded))
		assert_eq(difference, "", "seed %d diverged after loading" % seed_value)


func test_the_logistic_table_matches_the_curve() -> void:
	for i: int in 201:
		var x := -10.0 + i * 0.1
		assert_near(Conversations.logistic(x), 1.0 / (1.0 + exp(-x)), 0.01, "x = %.1f" % x)
	assert_eq(Conversations.logistic(0.0), 0.5)


func test_every_saved_field_is_saved_or_excused() -> void:
	for name: String in SAVED_CLASSES:
		var script: GDScript = null
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if entry["class"] == name:
				script = load(entry["path"])
		assert_true(script != null, name)
		if script == null:
			continue
		var instance: Object = script.new()
		var saved: Dictionary = instance.call("to_dict")
		var excused: PackedStringArray = script.get_script_constant_map().get("NOT_SAVED", PackedStringArray())
		for property: Dictionary in instance.get_property_list():
			if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var field: String = property["name"]
			if field.begins_with("_") or excused.has(field):
				continue
			assert_true(saved.has(field), "%s.%s is neither in to_dict() nor in NOT_SAVED" % [name, field])
