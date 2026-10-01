extends TestCase
## T-0010: the interaction menu lists what an object offers and queues the choice; E picks
## the nearest object in front; failed actions get a readable notice.

const ROOM: PackedStringArray = [
	"##########",
	"#@.......#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]

var _old_content: ContentDB
var _old_sim: Sim


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	assert_true(sim.world.add_object(obj), "could not place %s at %s" % [def_id, cell])
	return obj


func test_entries_list_the_name_then_what_the_object_offers() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var bed := _place(sim, "bed_double", Vector3i(3, 3, 0))
	assert_eq(InteractionMenu.entries(sim, fridge.id), ["Fridge", "Grab a snack"])
	assert_eq(InteractionMenu.entries(sim, bed.id), ["Double bed", "Sleep", "Nap"])
	assert_eq(InteractionMenu.entries(sim, 9999), [])


func test_choosing_an_entry_queues_it_for_the_player() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	Session.content = content()
	Session.sim = sim
	var menu := InteractionMenu.new()
	menu.prepare(fridge.id)
	menu.id_pressed.emit(0)
	menu.free()
	var pending := sim.pending_commands()
	assert_eq(pending.size(), 1)
	if pending.size() == 1:
		var command := pending[0] as QueueInteractionCommand
		assert_true(command != null, "expected a QueueInteractionCommand")
		if command != null:
			assert_eq(command.person_id, sim.world.player_id)
			assert_eq(command.interaction_id, "grab_snack")
			assert_eq(command.target_id, fridge.id)


func test_prepare_fills_the_menu_and_leaves_it_empty_for_unknown_objects() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var table := _place(sim, "kitchen_table", Vector3i(5, 3, 0))
	Session.content = content()
	Session.sim = sim
	var menu := InteractionMenu.new()
	menu.prepare(9999)
	assert_eq(menu.item_count, 0)
	menu.prepare(table.id)
	assert_true(menu.item_count >= 2, "a header and at least one item")
	menu.free()


func test_e_prefers_the_object_in_front() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var ahead := _place(sim, "fridge", Vector3i(6, 2, 0))
	_place(sim, "fridge", Vector3i(4, 2, 0))
	var person := sim.world.player()
	person.pos = Vector2(5.5, 2.5)
	person.facing = Vector2.RIGHT
	assert_eq(PlayerController.nearest_object(sim, person), ahead.id, "1 cell ahead beats 1 cell behind")


func test_e_prefers_the_nearer_object_when_neither_is_in_front() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var side := _place(sim, "fridge", Vector3i(5, 3, 0))
	# Diagonally behind: 1.41 cells away, not in front.
	_place(sim, "fridge", Vector3i(4, 1, 0))
	var person := sim.world.player()
	person.pos = Vector2(5.5, 2.5)
	person.facing = Vector2.RIGHT
	assert_eq(PlayerController.nearest_object(sim, person), side.id, "1 cell to the side beats 1.41 cells behind")


func test_e_finds_nothing_out_of_reach() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	_place(sim, "fridge", Vector3i(8, 4, 0))
	var person := sim.world.player()
	person.pos = Vector2(5.5, 2.5)
	assert_eq(PlayerController.nearest_object(sim, person), 0)


func test_failed_actions_get_a_readable_notice() -> void:
	var failed := {"type": &"action_failed", "tick": 0, "data": {"person_id": 5, "interaction_id": "grab_snack", "reason": "no_path"}}
	assert_eq(Hud.notice_for_event(failed, 5, content()), "Grab a snack: can't get there")
	assert_eq(Hud.notice_for_event(failed, 6, content()), "", "someone else's failure")
	var taken := {"type": &"action_failed", "tick": 0, "data": {"person_id": 5, "interaction_id": "watch_tv", "reason": "no_free_slot"}}
	assert_eq(Hud.notice_for_event(taken, 5, content()), "Watch TV: someone is using it")
	var odd := {"type": &"action_failed", "tick": 0, "data": {"person_id": 5, "interaction_id": "sleep", "reason": "unknown_interaction"}}
	assert_eq(Hud.notice_for_event(odd, 5, content()), "")


func test_menu_shows_prices_and_reasons() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "bar_counter":
			counter = obj
	sim.clock.tick = SimClock.ticks_for(0, 20)
	assert_eq(InteractionMenu.entries(sim, counter.id), ["Bar", "Have a drink · €4.00"])
	sim.clock.tick = SimClock.ticks_for(0, 10)
	assert_eq(InteractionMenu.entries(sim, counter.id), ["Bar", "Have a drink · €4.00 (closed, opens 17:00)"])
	Session.content = content()
	Session.sim = sim
	var menu := InteractionMenu.new()
	menu.prepare(counter.id)
	assert_true(menu.is_item_disabled(1), "a closed bar's drink is greyed out")
	sim.clock.tick = SimClock.ticks_for(0, 20)
	menu.prepare(counter.id)
	assert_false(menu.is_item_disabled(1))
	var player := sim.world.player()
	Money.spend(sim, player, player.wallet.total(), "purchase")
	assert_eq(InteractionMenu.entries(sim, counter.id), ["Bar", "Have a drink · €4.00 (not enough money)"])
	menu.prepare(counter.id)
	assert_true(menu.is_item_disabled(1))
	menu.free()
