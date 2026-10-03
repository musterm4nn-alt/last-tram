extends TestCase
## T-0011: the furnished flat. Every object can be reached from the spawn, every interaction
## is on offer somewhere in the flat, and each home interaction does what its data says.

## The bathroom added to the entrance room (world coordinates; Altstadt's origin is 0,0).
const BATHROOM_FLOOR: Vector3i = Vector3i(48, 27, 0)
const BATHROOM_DOOR: Vector3i = Vector3i(50, 27, 0)
const BATHROOM_WALLS: Array[Vector3i] = [Vector3i(48, 26, 0), Vector3i(49, 26, 0), Vector3i(50, 28, 0)]


## The first placed object with this def id (fails the test if there is none).
func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	fail("no %s in the flat" % def_id)
	return null


## Stands the player on the object's first slot, sets every need to 50 (then `needs`), queues
## the interaction and runs `minutes` game minutes. Returns the player.
func _run(sim: Sim, def_id: String, interaction_id: String, needs: Dictionary, minutes: int) -> Person:
	var player := sim.world.player()
	# These tests check one action; free will would start another when it ends.
	player.free_will = false
	var obj := _object(sim, def_id)
	var cell := obj.slot_cell(sim.content, 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	for need_def: NeedDef in sim.content.needs:
		player.needs[need_def.id] = 50.0
	for need_id: String in needs:
		player.needs[need_id] = float(needs[need_id])
	sim.submit(QueueInteractionCommand.new(player.id, interaction_id, obj.id))
	sim.run_minutes(minutes)
	return player


func test_content_has_no_errors() -> void:
	var db := ContentDB.load_default()
	assert_true(db.is_valid(), "\n".join(db.errors))


func test_the_bathroom_is_on_the_map() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var grid := sim.world.grid
	assert_eq(grid.terrain_def_at(BATHROOM_FLOOR).id, "floor_tile")
	assert_eq(grid.terrain_def_at(BATHROOM_DOOR).id, "door")
	for wall: Vector3i in BATHROOM_WALLS:
		assert_eq(grid.terrain_def_at(wall).id, "wall", "%s should be a wall" % wall)
	assert_true(grid.is_walkable(content().districts["altstadt"].player_spawn))


func test_every_object_has_a_slot_reachable_from_the_spawn() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var spawn: Vector3i = content().districts["altstadt"].player_spawn
	for obj: WorldObject in sim.world.objects.values():
		var reachable := false
		for index: int in obj.slot_count(sim.content):
			var cell := obj.slot_cell(sim.content, index)
			if cell == spawn or not sim.nav.find_path(spawn, cell).is_empty():
				reachable = true
		assert_true(reachable, "%s at %s has no slot reachable from the spawn" % [obj.def_id, obj.origin])


func test_every_interaction_is_offered_in_the_flat() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var offered: Dictionary = {}
	for id: int in sim.world.objects:
		for def: InteractionDef in Interactions.offered_by(sim, id):
			offered[def.id] = true
	for interaction_id: String in content().interactions:
		if content().interaction(interaction_id).target != "object":
			continue  # person-targeted interactions are offered by people (T-0038)
		assert_true(offered.has(interaction_id), "nothing in the flat offers '%s'" % interaction_id)


func test_cook_meal_takes_half_an_hour_and_fills_hunger() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _run(sim, "stove", "cook_meal", {"hunger": 20.0}, 29)
	assert_eq(player.action_queue.size(), 1, "still cooking after 29 minutes")
	sim.run_minutes(1)
	assert_true(player.action_queue.is_empty(), "cooking should end after 30 minutes")
	assert_near(player.needs["hunger"], 20.0 - 30.0 * 6.0 / 60.0 + 60.0, 0.001)


func test_take_shower_and_wash_hands_fill_hygiene() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _run(sim, "shower", "take_shower", {"hygiene": 10.0}, 15)
	assert_true(player.action_queue.is_empty(), "a shower takes 15 minutes")
	assert_near(player.needs["hygiene"], 10.0 - 15.0 * 4.0 / 60.0 + 85.0, 0.001, "one shower a day is enough (T-0060)")
	var sim2 := SimFactory.new_game(content(), 1)
	var washer := _run(sim2, "sink", "wash_hands", {}, 2)
	assert_true(washer.action_queue.is_empty(), "washing hands takes 2 minutes")
	assert_near(washer.needs["hygiene"], 50.0 - 2.0 * 4.0 / 60.0 + 10.0, 0.001)


func test_nap_on_the_sofa_rests_and_comforts() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _run(sim, "sofa", "nap", {}, 45)
	assert_true(player.action_queue.is_empty(), "a nap takes 45 minutes")
	assert_near(player.needs["energy"], 50.0 + 45.0 * (12.0 - 4.5) / 60.0, 0.001)
	assert_near(player.needs["comfort"], 50.0 + 45.0 * (20.0 - 8.0) / 60.0, 0.001)


func test_the_laptop_offers_browsing_and_video_calls() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _run(sim, "desk", "browse_web", {}, 30)
	assert_true(player.action_queue.is_empty(), "browsing takes 30 minutes")
	assert_near(player.needs["fun"], 50.0 + 30.0 * (20.0 - 6.0) / 60.0, 0.001)
	var sim2 := SimFactory.new_game(content(), 1)
	var caller := _run(sim2, "desk", "video_call", {}, 45)
	assert_true(caller.action_queue.is_empty(), "a video call takes 45 minutes")
	assert_near(caller.needs["social"], 50.0 + 45.0 * (30.0 - 4.0) / 60.0, 0.001, "half a real conversation's worth (T-0079)")


func test_sleep_is_comfortable() -> void:
	var sim := SimFactory.new_game(content(), 1)
	# Nearly rested: sleep runs its minimum 60 minutes.
	var player := _run(sim, "bed_double", "sleep", {"energy": 99.0}, 60)
	assert_true(player.action_queue.is_empty(), "sleep ends at min_minutes once rested")
	assert_near(player.needs["comfort"], 50.0 + 60.0 * (10.0 - 8.0) / 60.0, 0.001)
