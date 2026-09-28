class_name CharacterCreator
extends CanvasLayer
## The character creator (New game): tabs for Name, Identity, Body and Face & hair, a live
## preview from all four sides, and Start / Back. Every choice goes through a CreatorModel.
## Enter = Start (when valid), Esc = Back, even while typing a name.

## Start was pressed with a valid character.
signal start_pressed(spec: CharacterSpec)
signal back_pressed

const HINT: String = "Type a first and last name, or press Random name."
const HINT_COLOR: Color = Color(1, 1, 1, 0.6)
const ERROR_COLOR: Color = Color("#e06c6c")
## Tab ids in order, and their titles.
const TABS: PackedStringArray = ["name", "identity", "body", "face"]
const TAB_TITLES: PackedStringArray = ["Name", "Identity", "Body", "Face & hair"]
const LABEL_WIDTH: float = 110.0

var model: CreatorModel

var _tabs: TabContainer
var _preview: FigurePreview
var _first: LineEdit
var _last: LineEdit
var _nick: LineEdit
var _error: Label
var _start: Button
## List field -> the label showing its current option.
var _pickers: Dictionary[String, Label] = {}
var _age: SpinBox
var _height: SpinBox
## Feature id -> its checkbox.
var _feature_boxes: Dictionary[String, CheckBox] = {}


func _ready() -> void:
	layer = 21
	if model == null:
		model = CreatorModel.new(Session.content)
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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Your character"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	box.add_child(columns)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(430, 300)
	columns.add_child(_tabs)
	_build_name_tab(_tab("Name"))
	_build_identity_tab(_tab("Identity"))
	_build_body_tab(_tab("Body"))
	_build_face_tab(_tab("Face & hair"))
	_preview = FigurePreview.new()
	columns.add_child(_preview)
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
	_sync_from_model()


## Starts over from a copy of `spec` (for --creator-seed); call before or after _ready().
func start_from(spec: CharacterSpec) -> void:
	model = CreatorModel.new(Session.content, spec)
	if _first != null:
		_first.text = model.spec.first_name
		_last.text = model.spec.last_name
		_nick.text = model.spec.nickname
		_sync_from_model()


## Shows the tab with this id ("name", "identity", "body", "face"); unknown ids are ignored.
func show_tab(id: String) -> void:
	var index := TABS.find(id)
	if index >= 0:
		_tabs.current_tab = index


## Puts the keyboard cursor in the first name field (call when the screen is shown).
func focus_first_field() -> void:
	_tabs.current_tab = 0
	if _first.is_inside_tree():
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


# --- Tabs --------------------------------------------------------------------------------

func _tab(title_text: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title_text
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	return page


func _build_name_tab(page: VBoxContainer) -> void:
	_first = _field(page, "First name", 24)
	_last = _field(page, "Last name", 24)
	_nick = _field(page, "Nickname (optional)", 16)
	_first.text = model.spec.first_name
	_last.text = model.spec.last_name
	_nick.text = model.spec.nickname
	var random_button := Button.new()
	random_button.text = "Random name"
	random_button.pressed.connect(_on_random_name)
	page.add_child(random_button)


func _build_identity_tab(page: VBoxContainer) -> void:
	_picker(page, "Gender", "gender")
	_picker(page, "Pronouns", "pronouns")
	_age = _spin(page, "Age", CreatorModel.AGE_MIN, CreatorModel.AGE_MAX, "")
	_age.value_changed.connect(func(value: float) -> void:
		model.set_age(int(value))
		_sync_from_model())


func _build_body_tab(page: VBoxContainer) -> void:
	_height = _spin(page, "Height", CreatorModel.HEIGHT_MIN, CreatorModel.HEIGHT_MAX, "cm")
	_height.value_changed.connect(func(value: float) -> void:
		model.set_height(int(value))
		_sync_from_model())
	_picker(page, "Build", "build")
	_picker(page, "Skin tone", "skin_tone")


func _build_face_tab(page: VBoxContainer) -> void:
	_picker(page, "Hair", "hair_style")
	_picker(page, "Hair colour", "hair_colour")
	_picker(page, "Eyes", "eye_colour")
	_picker(page, "Facial hair", "facial_hair")
	var features := HBoxContainer.new()
	features.add_theme_constant_override("separation", 12)
	page.add_child(features)
	for id: String in model.feature_options():
		var check := CheckBox.new()
		var option: NamedOption = Session.content.appearance.features[id]
		check.text = option.name
		check.toggled.connect(func(on: bool) -> void:
			if on != model.spec.appearance.features.has(id):
				model.toggle_feature(id)
			_sync_from_model())
		features.add_child(check)
		_feature_boxes[id] = check


## One row: a label, ◀, the current option's name, ▶ (the same for every list field).
func _picker(page: VBoxContainer, label_text: String, field: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	var back := Button.new()
	back.text = "◀"
	back.pressed.connect(func() -> void:
		model.previous(field)
		_sync_from_model())
	row.add_child(back)
	var shown := Label.new()
	shown.custom_minimum_size = Vector2(170, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(shown)
	var forward := Button.new()
	forward.text = "▶"
	forward.pressed.connect(func() -> void:
		model.next(field)
		_sync_from_model())
	row.add_child(forward)
	_pickers[field] = shown


func _spin(page: VBoxContainer, label_text: String, low: int, high: int, suffix: String) -> SpinBox:
	var row := HBoxContainer.new()
	page.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.suffix = suffix
	row.add_child(spin)
	return spin


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


# --- Model <-> controls --------------------------------------------------------------------

## Shows the model's current values in every control, the preview and the Start button.
func _sync_from_model() -> void:
	for field: String in _pickers:
		_pickers[field].text = model.option_name(field, model.value(field))
	_age.set_value_no_signal(model.spec.age_years)
	_height.set_value_no_signal(model.spec.appearance.height_cm)
	for id: String in _feature_boxes:
		_feature_boxes[id].set_pressed_no_signal(model.spec.appearance.features.has(id))
	_refresh()


func _on_random_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	model.randomise("name", rng)
	_first.text = model.spec.first_name
	_last.text = model.spec.last_name
	_nick.text = model.spec.nickname
	_refresh()


func _try_start() -> void:
	_refresh()
	if _start.disabled:
		return
	start_pressed.emit(model.spec)


## Copies the typed names into the model, then updates the hint or errors, the Start button
## and the preview.
func _refresh() -> void:
	model.spec.first_name = _first.text.strip_edges()
	model.spec.last_name = _last.text.strip_edges()
	model.spec.nickname = _nick.text.strip_edges()
	var problems := model.errors()
	# Explain names the player typed that don't work; empty fields only get a hint.
	var shown := PackedStringArray()
	for problem: String in problems:
		if (problem.begins_with("first name") and not model.spec.first_name.is_empty()) \
				or (problem.begins_with("last name") and not model.spec.last_name.is_empty()) \
				or problem.begins_with("nickname"):
			shown.append(problem)
	if shown.is_empty() and (model.spec.first_name.is_empty() or model.spec.last_name.is_empty()):
		_error.text = HINT
		_error.modulate = HINT_COLOR
	else:
		_error.text = "\n".join(shown)
		_error.modulate = ERROR_COLOR
	_start.disabled = not problems.is_empty()
	_preview.show_spec(model.spec)
