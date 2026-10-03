extends TestCase
## T-0009: command mode (Tab): the flag and its signal, click-to-walk, camera panning, the
## destination ring and the HUD texts.

const ROOM: PackedStringArray = [
	"##########",
	"#@.......#",
	"#........#",
	"#........#",
	"##########",
]

var _old_content: ContentDB
var _old_sim: Sim
var _old_command_mode: bool = false
var _old_level: int = 0


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_command_mode = Session.command_mode
	_old_level = Session.viewed_level


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.command_mode = _old_command_mode
	Session.viewed_level = _old_level


func test_set_command_mode_emits_once_per_change() -> void:
	Session.command_mode = false
	var seen: Array[bool] = []
	var listener := func(on: bool) -> void: seen.append(on)
	Session.command_mode_changed.connect(listener)
	Session.set_command_mode(true)
	Session.set_command_mode(true)
	Session.set_command_mode(false)
	Session.command_mode_changed.disconnect(listener)
	assert_eq(seen, [true, false])
	assert_false(Session.command_mode)


func test_a_new_game_starts_in_direct_mode() -> void:
	Session.content = content()
	Session.set_command_mode(true)
	Session.new_game(1)
	assert_false(Session.command_mode, "new and loaded games start in direct mode")


func test_cell_at_floors_pixels_to_cells() -> void:
	assert_eq(ViewConfig.cell_at(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(ViewConfig.cell_at(Vector2(15.9, 15.9)), Vector2i(0, 0))
	assert_eq(ViewConfig.cell_at(Vector2(16, 32)), Vector2i(1, 2))
	assert_eq(ViewConfig.cell_at(Vector2(-0.1, -0.1)), Vector2i(-1, -1))


func test_walk_command_targets_the_clicked_cell_on_the_given_level() -> void:
	var person := Person.new()
	person.id = 7
	person.level = 0
	var command := PlayerController.walk_command(person, Vector2(37, 20), 0)
	assert_eq(command.person_id, 7)
	assert_eq(command.target, Vector3i(2, 1, 0))
	assert_eq(PlayerController.walk_command(person, Vector2(37, 20), 2).target, Vector3i(2, 1, 2))


func test_clicking_the_ground_walks_the_player_there() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	Session.content = content()
	Session.sim = sim
	var player := sim.world.player()
	var click := Vector2(6.5, 3.5) * ViewConfig.TILE_PX
	Session.submit(PlayerController.walk_command(player, click, player.level))
	sim.step()
	assert_false(player.path.is_empty(), "the click should start a walk")
	for i: int in 400:
		if player.path.is_empty():
			break
		sim.step()
	assert_eq(player.cell(), Vector3i(6, 3, 0))


func test_pan_step_moves_at_screen_speed() -> void:
	var start := Vector2(100, 100)
	assert_vec_near(CameraRig2D.pan_step(start, Vector2.RIGHT, 0.5, 1.0), Vector2(100 + ViewConfig.PAN_SPEED_PX * 0.5, 100))
	# Zoomed in 3x, the same screen speed covers a third of the world distance.
	assert_vec_near(CameraRig2D.pan_step(start, Vector2.UP, 0.5, 3.0), Vector2(100, 100 - ViewConfig.PAN_SPEED_PX * 0.5 / 3.0))
	assert_vec_near(CameraRig2D.pan_step(start, Vector2.ZERO, 0.5, 1.0), start)


func test_clamp_to_town_keeps_the_camera_inside() -> void:
	var grid := SimFactory.from_rows(content(), ROOM).world.grid
	var far := Vector2(grid.width * ViewConfig.TILE_PX, grid.height * ViewConfig.TILE_PX)
	assert_vec_near(CameraRig2D.clamp_to_town(Vector2(-50, -50), grid), Vector2.ZERO)
	assert_vec_near(CameraRig2D.clamp_to_town(far + Vector2(99, 99), grid), far)
	assert_vec_near(CameraRig2D.clamp_to_town(Vector2(40, 30), grid), Vector2(40, 30))


func test_marker_shows_the_end_of_the_path_on_the_viewed_level() -> void:
	var person := Person.new()
	assert_eq(PathMarker2D.marker_centre(person, 0), null, "no path, no ring")
	person.path = [Vector3i(2, 1, 0), Vector3i(3, 2, 0)]
	assert_eq(PathMarker2D.marker_centre(person, 0), Vector2(3.5, 2.5) * ViewConfig.TILE_PX)
	assert_eq(PathMarker2D.marker_centre(person, 1), null, "the destination is on another level")


func test_hint_text_depends_on_the_mode() -> void:
	var direct := Hud.hint_text(false)
	var command := Hud.hint_text(true)
	assert_ne(direct, command)
	assert_true(direct.contains("Tab"), direct)
	assert_true(command.contains("Tab"), command)
	assert_true(command.contains("Click"), command)


func test_notice_for_the_players_failed_walk_only() -> void:
	var failed := {"type": &"path_failed", "tick": 0, "data": {"person_id": 5, "target": [1, 1, 0]}}
	assert_eq(Hud.notice_for_event(failed, 5), "Can't get there")
	assert_eq(Hud.notice_for_event(failed, 6), "", "someone else's failed walk")
	var other := {"type": &"path_blocked", "tick": 0, "data": {"person_id": 5}}
	assert_eq(Hud.notice_for_event(other, 5), "")


## T-0084
func test_look_at_cell() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	Session.content = sim.content
	Session.sim = sim
	Session.command_mode = false
	var grid := sim.world.grid
	assert_vec_near(CameraRig2D.cell_centre(Vector2i(3, 2), grid), Vector2(3.5, 2.5) * ViewConfig.TILE_PX)
	assert_vec_near(CameraRig2D.cell_centre(Vector2i(40, -9), grid), Vector2(grid.width * ViewConfig.TILE_PX, 0), 0.0001, "clamped to the town")
	var camera := CameraRig2D.new()
	camera.look_at_cell(Vector2i(6, 3))
	assert_true(Session.command_mode, "command mode, so the camera stays put")
	assert_vec_near(camera.position, Vector2(6.5, 3.5) * ViewConfig.TILE_PX)
	camera.free()


## T-0086
func test_hidden_people_cannot_be_clicked() -> void:
	var rows: PackedStringArray = [
		"::::::::::",
		":#####:::@",
		":#...#::::",
		":#...D::::",
		":#####::::",
	]
	var sim := SimFactory.from_rows(content(), rows)
	var someone := SimFactory.spawn_person(sim, Vector3i(3, 2, 0), CharacterSpec.default_player(sim.content))
	var point := someone.pos + Vector2(0, -0.5)
	var old := Interiors.current
	Interiors.current = Interiors.build(sim.world.grid)
	assert_eq(PlayerController.person_at(sim, point, 0, -1), 0, "inside a closed building")
	Interiors.current.revealed = Interiors.current.reveal_for(Vector3i(3, 2, 0), 0)
	assert_eq(PlayerController.person_at(sim, point, 0, -1), someone.id, "once it's open")
	Interiors.current = old
