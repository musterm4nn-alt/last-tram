class_name NameScreen
extends CanvasLayer
## First step of the character creator (the full creator is T-0021): first name, last
## name and an optional nickname. Start puts the typed names on the default spec.
## Enter = Start (when valid), Esc = Back.

signal start_pressed(spec: CharacterSpec)
signal back_pressed

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
	var defaults := CharacterSpec.default_player(Session.content)
	_first.text = defaults.first_name
	_last.text = defaults.last_name
	_nick.text = defaults.nickname
	var random_button := Button.new()
	random_button.text = "Random name"
	random_button.pressed.connect(_on_random_name)
	box.add_child(random_button)
	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 14)
	_error.modulate = Color("#e06c6c")
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_try_start()
	elif event.is_action_pressed("ui_cancel"):
		back_pressed.emit()


func _field(parent: Control, label_text: String, max_length: int) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(320, 0)
	field.max_length = max_length
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
	var problems := PackedStringArray()
	for problem: String in spec.validate(Session.content):
		if problem.contains("name"):
			problems.append(problem)
	_error.text = "\n".join(problems)
	_start.disabled = not problems.is_empty()
	_spec = spec
