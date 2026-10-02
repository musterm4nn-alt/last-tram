class_name Phone
extends CanvasLayer
## The player's phone (P, T-0063): a panel at the bottom right with apps: Bank, Contacts (with
## calls) and Map. The game keeps running while it is open. Reads sim state; calls go through
## CallCommand.

const WIDTH: float = 320.0
const APPS: PackedStringArray = ["Bank", "Contacts", "Map"]

## True while the phone is shown.
var is_open: bool = false
## The app on screen ("" = the home screen).
var app: String = ""
## Opens the full town map (set by main).
var town_map: TownMap

var _title: Label
var _body: VBoxContainer
var _refresh_left: float = 0.0


func _init() -> void:
	layer = 12
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -12
	panel.offset_bottom = -48
	panel.custom_minimum_size = Vector2(WIDTH, 420)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH - 20, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	visible = false


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	visible = true
	show_app("")


func close() -> void:
	is_open = false
	visible = false


## Shows an app by name ("" = home); "Map" opens the town map instead.
func show_app(name: String) -> void:
	if name == "Map" and town_map != null:
		close()
		town_map.open()
		return
	app = name
	_rebuild()


func _process(delta: float) -> void:
	if not is_open:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_rebuild()


func _rebuild() -> void:
	if Session.sim == null:
		return
	for child: Node in _body.get_children():
		child.queue_free()
	_title.text = "Phone" if app.is_empty() else app
	var player_id := Session.sim.world.player_id
	match app:
		"":
			for name: String in APPS:
				_button(name, show_app.bind(name))
		"Bank":
			for text: String in BankApp.lines(Session.sim, player_id):
				_label(text)
		"Contacts":
			var known := ContactsApp.contacts(Session.sim, player_id)
			if known.is_empty():
				_label("Nobody's number yet. Get to know people first.")
			for other_id: int in known:
				_label(ContactsApp.line(Session.sim, player_id, other_id))
				_button("Call", func() -> void: Session.submit(CallCommand.new(player_id, other_id)))
	if not app.is_empty():
		_button("Back", show_app.bind(""))


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 30, 0)
	_body.add_child(label)


func _button(text: String, pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	_body.add_child(button)
