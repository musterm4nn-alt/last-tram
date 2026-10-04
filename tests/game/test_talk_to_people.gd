extends TestCase
## T-0053: clicking or pressing E next to a person opens their menu of social interactions.

const ROOM: PackedStringArray = [
	"########",
	"#@.....#",
	"#......#",
	"########",
]

var _old_sim: Sim
var _old_content: ContentDB


func before_each() -> void:
	_old_sim = Session.sim
	_old_content = Session.content
	Session.content = content()


func after_each() -> void:
	Session.sim = _old_sim
	Session.content = _old_content


func _pair(cell: Vector3i) -> Array:
	var sim := SimFactory.from_rows(content(), ROOM)
	var spec := CharacterSpec.default_player(content())
	spec.first_name = "Mira"
	spec.last_name = "Kovač"
	var other := SimFactory.spawn_person(sim, cell, spec)
	Session.sim = sim
	return [sim, sim.world.player(), other]


func test_a_person_menu_lists_the_social_interactions() -> void:
	var setup := _pair(Vector3i(3, 1, 0))
	var other: Person = setup[2]
	assert_eq(InteractionMenu.entries(setup[0], other.id),
		["Mira Kovač", "Chat", "Tell a joke", "Compliment", "Insult", "Argue", "Flirt", "Pick their pocket"] as Array[String])


func test_choosing_from_a_person_menu_queues_it_on_them() -> void:
	var setup := _pair(Vector3i(3, 1, 0))
	var sim: Sim = setup[0]
	var menu := InteractionMenu.new()
	menu.prepare(setup[2].id)
	menu.id_pressed.emit(1)  # Tell a joke
	sim.step()
	var player: Person = setup[1]
	assert_eq(player.action_queue.size(), 1)
	assert_eq(player.action_queue[0].interaction_id, "joke")
	assert_eq(player.action_queue[0].target_id, setup[2].id)
	menu.free()


func test_clicking_finds_the_person_under_the_mouse() -> void:
	var setup := _pair(Vector3i(4, 2, 0))
	var sim: Sim = setup[0]
	var other: Person = setup[2]
	assert_eq(PlayerController.person_at(sim, other.pos + Vector2(0.1, -0.8), 0, setup[1].id), other.id, "the body counts")
	assert_eq(PlayerController.person_at(sim, other.pos + Vector2(1.0, 0.0), 0, setup[1].id), 0)
	assert_eq(PlayerController.person_at(sim, other.pos, 1, setup[1].id), 0, "another floor")
	assert_eq(PlayerController.person_at(sim, setup[1].pos, 0, setup[1].id), 0, "never yourself")


func test_e_picks_the_person_in_front_over_an_object_behind() -> void:
	var setup := _pair(Vector3i(2, 1, 0))
	var sim: Sim = setup[0]
	var player: Person = setup[1]
	player.facing = Vector2.RIGHT
	var fridge := WorldObject.new()
	fridge.id = sim.world.new_id()
	fridge.def_id = "fridge"
	fridge.origin = Vector3i(1, 2, 0)
	assert_true(sim.world.add_object(fridge))
	assert_eq(PlayerController.nearest_target(sim, player), setup[2].id)
	player.facing = Vector2.DOWN
	assert_eq(PlayerController.nearest_target(sim, player), fridge.id, "now the fridge is in front")


func test_the_hud_says_how_it_went() -> void:
	var setup := _pair(Vector3i(2, 1, 0))
	var sim: Sim = setup[0]
	var player: Person = setup[1]
	var other: Person = setup[2]
	var event := {"type": &"social_exchange", "data": {"actor_id": player.id, "target_id": other.id, "interaction_id": "chat", "outcome": "success"}}
	assert_eq(Hud.notice_for_event(event, player.id, content(), sim), "Chat with Mira Kovač: went well")
	event["data"]["outcome"] = "fail"
	assert_eq(Hud.notice_for_event(event, player.id, content(), sim), "Chat with Mira Kovač: didn't go well")
	var to_me := {"type": &"social_exchange", "data": {"actor_id": other.id, "target_id": player.id, "interaction_id": "joke", "outcome": "success"}}
	assert_eq(Hud.notice_for_event(to_me, player.id, content(), sim), "Mira Kovač: Tell a joke")
	var others := {"type": &"social_exchange", "data": {"actor_id": other.id, "target_id": 999, "interaction_id": "joke"}}
	assert_eq(Hud.notice_for_event(others, player.id, content(), sim), "")
	var busy := {"type": &"action_failed", "data": {"person_id": player.id, "interaction_id": "chat", "reason": "target_busy"}}
	assert_eq(Hud.notice_for_event(busy, player.id, content(), sim), "Chat: they're busy")
