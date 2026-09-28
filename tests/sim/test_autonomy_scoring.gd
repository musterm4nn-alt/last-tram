extends TestCase
## T-0012: autonomy scoring. Urgency and need scores, the options a person has, and picking
## one of the best.

const KITCHEN: PackedStringArray = [
	"#########",
	"#.......#",
	"#.......#",
	"#...@...#",
	"#.......#",
	"#########",
]


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	assert_true(sim.world.add_object(obj), "could not place %s at %s" % [def_id, cell])
	return obj


## Every need at 100, then `needs`.
func _set_needs(person: Person, needs: Dictionary) -> void:
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 100.0
	for need_id: String in needs:
		person.needs[need_id] = float(needs[need_id])


func _option(options: Array[Dictionary], interaction_id: String) -> Dictionary:
	for option: Dictionary in options:
		if option["interaction_id"] == interaction_id:
			return option
	return {}


func test_urgency_grows_steeply_as_a_need_empties() -> void:
	assert_near(Utility.urgency(100.0, 1.0), 0.0)
	assert_near(Utility.urgency(0.0, 1.2), 1.2)
	assert_near(Utility.urgency(50.0, 1.2), 0.3)
	assert_near(Utility.urgency(-10.0, 1.0), 1.0, 0.0001, "below 0 counts as 0")
	assert_near(Utility.urgency(150.0, 1.0), 0.0, 0.0001, "above 100 counts as 100")


func test_need_score_is_capped_by_the_room_left() -> void:
	var db := content()
	var person := Person.new()
	_set_needs(person, {"energy": 70.0})
	assert_near(Utility.need_score(person, db.interaction("sleep"), db), 0.09 * 30.0)
	_set_needs(person, {"energy": 20.0})
	assert_near(Utility.need_score(person, db.interaction("sleep"), db), 0.64 * 80.0)
	_set_needs(person, {"hunger": 50.0})
	assert_near(Utility.need_score(person, db.interaction("grab_snack"), db), 0.3 * 25.0)
	var nobody := Person.new()
	assert_near(Utility.need_score(nobody, db.interaction("grab_snack"), db), 0.0, 0.0001, "missing needs count as full")


func test_candidates_in_the_flat_score_food_by_need_and_distance() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_set_needs(player, {"hunger": 30.0})
	var options := Autonomy.candidates(sim, player)
	for interaction_id: String in ["grab_snack", "cook_meal"]:
		var option := _option(options, interaction_id)
		assert_false(option.is_empty(), "%s should be an option" % interaction_id)
		if option.is_empty():
			continue
		var obj := sim.world.get_object(int(option["object_id"]))
		var path := sim.nav.find_path(player.cell(), obj.slot_cell(sim.content, 0))
		assert_eq(int(option["cells"]), path.size())
		var expected := Utility.need_score(player, sim.content.interaction(interaction_id), sim.content) - 0.1 * path.size()
		assert_near(float(option["score"]), expected)


func test_objects_out_of_reach_give_no_options() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var street_fridge := _place(sim, "fridge", Vector3i(36, 22, 0))
	var player := sim.world.player()
	for option: Dictionary in Autonomy.candidates(sim, player):
		assert_ne(int(option["object_id"]), street_fridge.id, "13+ cells away is out of reach")


func test_a_taken_or_blocked_slot_gives_no_option() -> void:
	var sim := SimFactory.from_rows(content(), KITCHEN)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	assert_false(_option(Autonomy.candidates(sim, player), "grab_snack").is_empty())
	# Someone else is walking to the fridge's only slot.
	var other := Person.new()
	other.id = sim.world.new_id()
	other.pos = Vector2(1.5, 1.5)
	var action := Action.new("grab_snack", fridge.id)
	action.state = Action.ROUTING
	action.slot_index = 0
	other.action_queue.append(action)
	sim.world.add_person(other)
	assert_true(_option(Autonomy.candidates(sim, player), "grab_snack").is_empty(), "the slot is taken")
	other.action_queue.clear()
	# Something stands on the fridge's only slot.
	_place(sim, "stove", fridge.slot_cell(sim.content, 0))
	assert_true(_option(Autonomy.candidates(sim, player), "grab_snack").is_empty(), "the slot is blocked")


func test_choose_returns_nothing_when_everything_is_below_the_minimum() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var options: Array[Dictionary] = [
		{"object_id": 1, "interaction_id": "a", "score": 1.0, "cells": 0},
		{"object_id": 2, "interaction_id": "b", "score": -4.0, "cells": 0},
	]
	for i: int in 50:
		assert_eq(Autonomy.choose(options, rng), {})


func test_choose_picks_among_the_best_three_mostly_the_best() -> void:
	var options: Array[Dictionary] = []
	for score: float in [20.0, 5.0, 40.0, 4.0, 12.0]:
		options.append({"object_id": 1, "interaction_id": "s%d" % int(score), "score": score, "cells": 0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary = {}
	var sequence: Array[String] = []
	for i: int in 1000:
		var pick := Autonomy.choose(options, rng)
		var id := String(pick["interaction_id"])
		counts[id] = int(counts.get(id, 0)) + 1
		sequence.append(id)
	for id: String in counts:
		assert_has(["s40", "s20", "s12"], id, "only the three best can be picked")
	assert_true(int(counts.get("s40", 0)) > int(counts.get("s20", 0)), "the best is picked most: %s" % [counts])
	assert_true(int(counts.get("s20", 0)) > int(counts.get("s12", 0)), "and the second more than the third: %s" % [counts])
	var again := RandomNumberGenerator.new()
	again.seed = 42
	for i: int in 20:
		assert_eq(String(Autonomy.choose(options, again)["interaction_id"]), sequence[i], "same seed, same picks")


func test_a_hungry_person_prefers_cooking_to_a_snack() -> void:
	var sim := SimFactory.from_rows(content(), KITCHEN)
	# The fridge and the stove are equally far from the person at (4, 3).
	_place(sim, "fridge", Vector3i(2, 1, 0))
	_place(sim, "stove", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_set_needs(player, {"hunger": 30.0})
	var options := Autonomy.candidates(sim, player)
	var cook := _option(options, "cook_meal")
	var snack := _option(options, "grab_snack")
	assert_eq(int(cook["cells"]), int(snack["cells"]), "the setup should be symmetric")
	assert_true(float(cook["score"]) > float(snack["score"]), "cooking advertises more hunger")


func test_with_only_a_fridge_a_hungry_person_grabs_a_snack() -> void:
	var sim := SimFactory.from_rows(content(), KITCHEN)
	_place(sim, "fridge", Vector3i(2, 1, 0))
	var player := sim.world.player()
	_set_needs(player, {"hunger": 30.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(String(Autonomy.choose(Autonomy.candidates(sim, player), rng).get("interaction_id", "")), "grab_snack")
