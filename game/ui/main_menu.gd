class_name MainMenu
extends CanvasLayer
## Main menu: New game (opens the name screen), Continue (the newest save of any kind:
## quicksave, slots or autosaves), Load game (a list of every save) and Quit. Shown when no
## quickstart option is given. Closes itself when a game loads.

signal new_game_requested

var _new_button: Button
var _continue_button: Button
## Under Continue: when the newest save is from, in game and in real time.
var _continue_info: Label
## The buttons, hidden while the Load list is shown.
var _buttons: VBoxContainer
var _load_list: SaveList


func _ready() -> void:
	layer = 20
	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "LAST TRAM"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "\"Miss the last tram and the night decides what happens next.\""
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(1, 1, 1, 0.7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 12)
	box.add_child(spacer)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	_new_button = _button(_buttons, "New game")
	_new_button.pressed.connect(func() -> void: new_game_requested.emit())
	_continue_button = _button(_buttons, "Continue")
	_continue_button.pressed.connect(_on_continue)
	_continue_info = Label.new()
	_continue_info.add_theme_font_size_override("font_size", 13)
	_continue_info.modulate = Color(1, 1, 1, 0.55)
	_continue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buttons.add_child(_continue_info)
	refresh_continue()
	var load_button := _button(_buttons, "Load game")
	load_button.pressed.connect(show_load_list)
	var quit_button := _button(_buttons, "Quit")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_load_list = SaveList.new()
	_load_list.add_theme_constant_override("separation", 8)
	_load_list.visible = false
	_load_list.chosen.connect(func(path: String) -> void: Session.load_from(path))
	_load_list.back_pressed.connect(_show_buttons)
	box.add_child(_load_list)
	focus_new_game()
	Session.game_loaded.connect(_on_game_loaded)


## Shows every save as a list in place of the buttons (Back returns).
func show_load_list() -> void:
	_load_list.show_rows(Session.saves, false)
	_buttons.visible = false
	_load_list.visible = true
	var first := _load_list.first_button()
	if first != null and first.is_inside_tree():
		first.grab_focus()


func _show_buttons() -> void:
	_load_list.visible = false
	_buttons.visible = true
	focus_new_game()


## Enables Continue when there is a save, and shows when the newest one is from.
func refresh_continue() -> void:
	var newest := Session.saves.newest_save()
	_continue_button.disabled = newest.is_empty()
	_continue_info.visible = not newest.is_empty()
	if not newest.is_empty():
		_continue_info.text = "%s · saved %s" % [SaveSlots.describe_game_time(newest), SaveSlots.describe_real_time(newest)]


## Selects New game, so Enter works right away (also after coming back from the name
## screen, where the keyboard focus was in a text field).
func focus_new_game() -> void:
	if _new_button.is_inside_tree():
		_new_button.grab_focus()


func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button


func _on_continue() -> void:
	var newest := Session.saves.newest_save()
	if not newest.is_empty():
		Session.load_from(newest)


func _on_game_loaded() -> void:
	queue_free()
