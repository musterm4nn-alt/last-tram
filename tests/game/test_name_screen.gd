extends TestCase
## T-0020: the name screen starts empty and enables Start only for valid names (the look
## is checked with screenshots).


func test_starts_empty_with_start_disabled_and_a_hint() -> void:
	var screen := _make_screen()
	assert_eq(screen._first.text, "", "the player names their character: no pre-filled name")
	assert_eq(screen._last.text, "")
	assert_eq(screen._nick.text, "")
	assert_true(screen._start.disabled)
	assert_eq(screen._error.text, NameScreen.HINT, "an untouched form shows a hint, not errors")
	_drop(screen)


func test_typed_names_start_with_the_default_look() -> void:
	var screen := _make_screen()
	var started: Array[CharacterSpec] = []
	screen.start_pressed.connect(func(spec: CharacterSpec) -> void: started.append(spec))
	_type(screen, "Mira", "Jovanović", "")
	assert_false(screen._start.disabled, "valid names should allow Start: " + screen._error.text)
	assert_eq(screen._error.text, "")
	screen._try_start()
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0].first_name, "Mira")
		assert_eq(started[0].last_name, "Jovanović")
		var look := CharacterSpec.default_player(content())
		assert_eq(started[0].appearance.to_dict(), look.appearance.to_dict())
		assert_eq(started[0].outfit.to_dict(), look.outfit.to_dict())
	_drop(screen)


func test_bad_name_disables_start_and_shows_error() -> void:
	var screen := _make_screen()
	_type(screen, "Al3x", "Novak", "")
	assert_true(screen._start.disabled)
	assert_true(screen._error.text.begins_with("first name"), screen._error.text)
	assert_eq(screen._error.modulate, NameScreen.ERROR_COLOR)
	_drop(screen)


func test_empty_nickname_is_fine() -> void:
	var screen := _make_screen()
	_type(screen, "Mira", "Jovanović", "")
	assert_false(screen._start.disabled)
	_type(screen, "Mira", "Jovanović", "Mimi")
	assert_false(screen._start.disabled)
	_drop(screen)


func test_hidden_screen_ignores_enter() -> void:
	var screen := _make_screen()
	var started: Array[CharacterSpec] = []
	screen.start_pressed.connect(func(spec: CharacterSpec) -> void: started.append(spec))
	_type(screen, "Mira", "Jovanović", "")
	screen.visible = false
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	screen._unhandled_input(enter)
	assert_eq(started.size(), 0, "Enter on the main menu must not start a game from the hidden name screen")
	_drop(screen)


func test_esc_goes_back_even_while_typing() -> void:
	var screen := _make_screen()
	var backs: Array[bool] = []
	screen.back_pressed.connect(func() -> void: backs.append(true))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._input(esc)  # _input runs before the focused text field can take the key
	assert_eq(backs.size(), 1)
	screen.visible = false
	screen._input(esc)
	assert_eq(backs.size(), 1, "a hidden name screen must ignore Esc")
	_drop(screen)


func _type(screen: NameScreen, first: String, last: String, nick: String) -> void:
	screen._first.text = first
	screen._last.text = last
	screen._nick.text = nick
	screen._refresh()


func _make_screen() -> NameScreen:
	# _ready() is called directly: control building needs no tree, and this keeps the
	# test independent of main-loop init order. The Session autoload is not readied
	# before tests run, so its content is seeded from the shared test content.
	Session.content = content()
	var screen := NameScreen.new()
	screen._ready()
	return screen


func _drop(screen: NameScreen) -> void:
	screen.free()
