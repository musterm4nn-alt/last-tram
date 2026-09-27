class_name NameScreen
extends CanvasLayer
## First step of the character creator (the full creator is T-0021): first name, last
## name and an optional nickname. The fields start empty: the player names their
## character. Start puts the typed names on the default spec. Enter = Start (when valid),
## Esc = Back.

## Start was pressed with a valid spec (the default player with the typed names).
signal start_pressed(spec: CharacterSpec)
signal back_pressed

const HINT: String = "Type a first and last name, or press Random name."
const HINT_COLOR: Color = Color(1, 1, 1, 0.6)
const ERROR_COLOR: Color = Color("#e06c6c")

var _first: LineEdit
var _last: LineEdit
var _nick: LineEdit
var _error: Label
var _start: Button
var _spec: CharacterSpec


func _ready() -> void:
	layer = 21
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Your character"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_first = _field(box, "First name", 24)
	_last = _field(box, "Last name", 24)
	_nick = _field(box, "Nickname (optional)", 16)
	var random_button := Button.new()
	random_button.text = "Random name"
	random_button.pressed.connect(_on_random_name)
	box.add_child(random_button)
	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 14)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(320, 0)
	box.add_child(_error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_start = Button.new()
	_start.text = "Start"
	_start.custom_minimum_size = Vector2(140, 40)
	_start.pressed.connect(_try_start)
	row.add_child(_start)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, 40)
	back.pressed.connect(func() -> void: back_pressed.emit())
	row.add_child(back)
	_refresh()


## Puts the keyboard cursor in the first name field (call when the screen is shown).
func focus_first_field() -> void:
	_first.grab_focus()


## Esc = Back, even while a name field is being edited (the field would otherwise take
## the first Esc just to stop editing).
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		back_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_try_start()


func _field(parent: Control, label_text: String, max_length: int) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(320, 0)
	field.max_length = max_length
	# Enter on an unfinished form must not stop typing in the field.
	field.keep_editing_on_text_submit = true
	field.text_changed.connect(func(_new_text: String) -> void: _refresh())
	field.text_submitted.connect(func(_new_text: String) -> void: _try_start())
	parent.add_child(field)
	return field


func _on_random_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random_spec := CharacterSpec.random(Session.content, rng)
	_first.text = random_spec.first_name
	_last.text = random_spec.last_name
	_nick.text = random_spec.nickname
	_refresh()


func _try_start() -> void:
	_refresh()
	if _start.disabled:
		return
	start_pressed.emit(_spec)


func _refresh() -> void:
	var spec := CharacterSpec.default_player(Session.content)
	spec.first_name = _first.text.strip_edges()
	spec.last_name = _last.text.strip_edges()
	spec.nickname = _nick.text.strip_edges()
	var problems := spec.validate(Session.content)
	# Explain names the player typed that don't work; empty fields only get a hint.
	var shown := PackedStringArray()
	for problem: String in problems:
		if (problem.begins_with("first name") and not spec.first_name.is_empty()) \
				or (problem.begins_with("last name") and not spec.last_name.is_empty()) \
				or problem.begins_with("nickname"):
			shown.append(problem)
	if shown.is_empty() and (spec.first_name.is_empty() or spec.last_name.is_empty()):
		_error.text = HINT
		_error.modulate = HINT_COLOR
	else:
		_error.text = "\n".join(shown)
		_error.modulate = ERROR_COLOR
	_start.disabled = not problems.is_empty()
	_spec = spec
