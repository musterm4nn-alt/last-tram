class_name MainMenu
extends CanvasLayer
## Main menu: New game (opens the name screen), Continue (the quicksave) and Quit.
## Shown when no quickstart option is given. Closes itself when a game loads.

signal new_game_requested

var _continue_button: Button


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
	var new_button := _button(box, "New game")
	new_button.pressed.connect(func() -> void: new_game_requested.emit())
	_continue_button = _button(box, "Continue")
	_continue_button.disabled = not FileAccess.file_exists(Session.QUICKSAVE_PATH)
	_continue_button.pressed.connect(_on_continue)
	var quit_button := _button(box, "Quit")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	new_button.grab_focus()
	Session.game_loaded.connect(_on_game_loaded)


func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button


func _on_continue() -> void:
	Session.load_from(Session.QUICKSAVE_PATH)


func _on_game_loaded() -> void:
	queue_free()
