extends TestCase
## T-0026: the character creator screen. The Name tab keeps every rule of the old name screen
## (T-0020, ported below), and the other tabs change the character through the model.

var _old_content: ContentDB


func before_each() -> void:
	_old_content = Session.content


func after_each() -> void:
	Session.content = _old_content


# --- Ported from test_name_screen.gd (T-0020) --------------------------------------------

func test_starts_empty_with_start_disabled_and_a_hint() -> void:
	var screen := _make_screen()
	assert_eq(screen._first.text, "", "the player names their character: no pre-filled name")
	assert_eq(screen._last.text, "")
	assert_eq(screen._nick.text, "")
	assert_true(screen._start.disabled)
	assert_eq(screen._error.text, CharacterCreator.HINT, "an untouched form shows a hint, not errors")
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
	assert_eq(screen._error.modulate, CharacterCreator.ERROR_COLOR)
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
	assert_eq(started.size(), 0, "Enter on the main menu must not start a game from the hidden creator")
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
	assert_eq(backs.size(), 1, "a hidden creator must ignore Esc")
	_drop(screen)


# --- The other tabs ----------------------------------------------------------------------

## The ▶ button of a picker row (the row holds: label, ◀, shown name, ▶).
func _forward(screen: CharacterCreator, field: String) -> Button:
	return screen._pickers[field].get_parent().get_child(3)


func test_a_picker_changes_the_model_and_the_shown_name() -> void:
	var screen := _make_screen()
	for field: String in ["gender", "build", "hair_style"]:
		var before := screen.model.value(field)
		_forward(screen, field).pressed.emit()
		var after := screen.model.value(field)
		assert_ne(after, before, "%s ▶ should change it" % field)
		assert_eq(screen._pickers[field].text, screen.model.option_name(field, after))
	_drop(screen)


func test_age_and_height_boxes_change_the_model_within_limits() -> void:
	var screen := _make_screen()
	# Ranges outside the tree don't emit value_changed, so send what a player's change sends.
	screen._age.value_changed.emit(44.0)
	assert_eq(screen.model.spec.age_years, 44)
	assert_eq(int(screen._age.value), 44, "the box shows the model's value")
	screen._age.value_changed.emit(12.0)
	assert_eq(screen.model.spec.age_years, 18, "never below 18")
	assert_eq(int(screen._age.value), 18)
	screen._height.value_changed.emit(190.0)
	assert_eq(screen.model.spec.appearance.height_cm, 190)
	_drop(screen)


func test_a_feature_checkbox_adds_and_removes_it() -> void:
	var screen := _make_screen()
	var id: String = screen.model.feature_options()[0]
	screen._feature_boxes[id].button_pressed = true
	assert_true(screen.model.spec.appearance.features.has(id))
	screen._feature_boxes[id].button_pressed = false
	assert_false(screen.model.spec.appearance.features.has(id))
	_drop(screen)


func test_start_sends_the_chosen_look() -> void:
	var screen := _make_screen()
	var started: Array[CharacterSpec] = []
	screen.start_pressed.connect(func(spec: CharacterSpec) -> void: started.append(spec))
	_forward(screen, "hair_style").pressed.emit()
	_type(screen, "Mira", "Jovanović", "")
	screen._try_start()
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0].appearance.hair_style, screen.model.value("hair_style"))
	_drop(screen)


func test_a_seeded_start_keeps_its_names() -> void:
	Session.content = content()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spec := CharacterSpec.random(content(), rng)
	var screen := CharacterCreator.new()
	screen.start_from(spec)
	screen._ready()
	assert_eq(screen._first.text, spec.first_name)
	assert_eq(screen.model.spec.first_name, spec.first_name)
	assert_false(screen._start.disabled, "a random character is ready to start")
	_drop(screen)


func _type(screen: CharacterCreator, first: String, last: String, nick: String) -> void:
	screen._first.text = first
	screen._last.text = last
	screen._nick.text = nick
	screen._refresh()


func _make_screen() -> CharacterCreator:
	# _ready() is called directly: control building needs no tree, and this keeps the test
	# independent of main-loop init order. The Session autoload is not readied before tests
	# run, so its content is seeded from the shared test content.
	Session.content = content()
	var screen := CharacterCreator.new()
	screen._ready()
	return screen


func _drop(screen: CharacterCreator) -> void:
	screen.free()
