class_name PauseMenu
extends CanvasLayer
## The Esc menu during a game: pauses, and offers Resume, Save game (one of three slots),
## Load game (any save) and Quit game. Closing it restores the speed it had before.

## True while the menu is shown (the rest of the game ignores input then).
var is_open: bool = false

var _speed_before: int = 1
var _page: VBoxContainer
var _list: SaveList
## "save" or "load" while the list is shown.
var _list_mode: String = ""


func _init() -> void:
	layer = 15
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
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
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	box.add_child(_page)
	_page_button("Resume", close)
	_page_button("Save game", _show_list.bind("save"))
	_page_button("Load game", _show_list.bind("load"))
	_page_button("Quit game", func() -> void: get_tree().quit())
	_list = SaveList.new()
	_list.add_theme_constant_override("separation", 8)
	_list.visible = false
	_list.chosen.connect(_on_chosen)
	_list.back_pressed.connect(_show_page)
	box.add_child(_list)
	visible = false


## Pauses (remembers Session.speed, then speed 0) and shows the main page.
func open() -> void:
	if is_open:
		return
	is_open = true
	_speed_before = Session.speed
	Session.set_speed(0)
	_show_page()
	visible = true


## Hides the menu and restores the speed it had before open().
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Session.set_speed(_speed_before)


func _show_page() -> void:
	_list.visible = false
	_list_mode = ""
	_page.visible = true
	if _page.is_inside_tree():
		(_page.get_child(0) as Button).grab_focus()


func _show_list(mode: String) -> void:
	_list_mode = mode
	_list.show_rows(Session.saves, mode == "save")
	_page.visible = false
	_list.visible = true
	var first := _list.first_button()
	if first != null and first.is_inside_tree():
		first.grab_focus()


func _on_chosen(path: String) -> void:
	if _list_mode == "save":
		var saved := Session.save_to(path) == OK
		Session.notice.emit("Saved to %s" % _slot_name(path) if saved else "Saving failed")
		_list.show_rows(Session.saves, true)
	elif _list_mode == "load":
		close()
		if not Session.load_from(path):
			Session.notice.emit("Could not load that save")


## "slot 2" for <dir>/slot_2.json.
static func _slot_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ")


func _page_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	_page.add_child(button)
