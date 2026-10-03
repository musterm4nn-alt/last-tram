class_name ShopScreen
extends CanvasLayer
## The second-hand rail and the barber chair at Waschsalon Blitz (T-0073): opened when the
## player's "Browse the clothes" or "Get a haircut" finishes (&"screen_requested"
## "clothes_shop" / "barber"). The rail lists every item with its price, a colour choice and
## Buy (BuyClothesCommand); the barber steps through hair styles and colours, then Done
## (ChangeHairCommand). Pauses the game while open. View only.

## True while shown (the rest of the game ignores input then).
var is_open: bool = false
## "clothes_shop" or "barber" while open.
var mode: String = ""
## The barber's choice so far.
var hair_style: String = ""
var hair_colour: String = ""

var _speed_before: int = 1
var _body: VBoxContainer


func _init() -> void:
	layer = 15
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	visible = false


func _ready() -> void:
	Session.sim_event.connect(func(event: Dictionary) -> void:
		var data: Dictionary = event.get("data", {})
		if event.get("type") == &"screen_requested" and data.get("screen") in ["clothes_shop", "barber"] and Session.sim != null \
				and int(data.get("person_id", -1)) == Session.sim.world.player_id:
			open(String(data["screen"])))
	Session.game_loaded.connect(func() -> void:
		if is_open:
			close())


## Shows the rail or the barber and pauses the game.
func open(screen: String) -> void:
	var player := Session.sim.world.player()
	if player == null:
		return
	mode = screen
	hair_style = player.appearance.hair_style
	hair_colour = player.appearance.hair_colour
	if not is_open:
		_speed_before = Session.speed
		Session.set_speed(0)
	is_open = true
	visible = true
	_rebuild()


func close() -> void:
	is_open = false
	visible = false
	Session.set_speed(_speed_before)


## "Hoodie (outer) · €35.00" for the rail.
static func item_text(def: ClothingDef) -> String:
	return "%s (%s) · %s" % [def.name, def.slot, Money.format(def.price)]


## The next (direction 1) or previous (-1) id in `ids` after `current`, wrapping.
static func stepped(ids: PackedStringArray, current: String, direction: int) -> String:
	if ids.is_empty():
		return current
	return ids[posmod(ids.find(current) + direction, ids.size())]


func _rebuild() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	if mode == "barber":
		title.text = "Barber"
		var catalog := Session.content.appearance
		_stepper("Style", catalog.hair_styles, hair_style, func(id: String) -> void: hair_style = id)
		_stepper("Colour", catalog.hair_colours, hair_colour, func(id: String) -> void: hair_colour = id)
		_body.add_child(_button("Done", func() -> void:
			Session.submit(ChangeHairCommand.new(Session.sim.world.player_id, hair_style, hair_colour))
			close()))
	else:
		title.text = "Second-hand clothes"
		_label("Cash: %s" % Money.format(Session.sim.world.player().wallet.cash))
		for def: ClothingDef in Session.content.clothing.values():
			var row := HBoxContainer.new()
			var name := Label.new()
			name.text = item_text(def)
			name.custom_minimum_size = Vector2(240, 0)
			row.add_child(name)
			var colours := OptionButton.new()
			for colour: String in def.colours:
				colours.add_item(colour)
			row.add_child(colours)
			row.add_child(_button("Buy", func() -> void:
				Session.submit(BuyClothesCommand.new(Session.sim.world.player_id, def.id, def.colours[colours.selected]))))
			_body.add_child(row)
	_body.add_child(_button("Close", close))


func _stepper(label: String, options: Dictionary, current: String, chosen: Callable) -> void:
	var ids := PackedStringArray(options.keys())
	var row := HBoxContainer.new()
	var shown := Label.new()
	shown.text = "%s: %s" % [label, current]
	shown.custom_minimum_size = Vector2(220, 0)
	row.add_child(_button("◀", func() -> void:
		chosen.call(stepped(ids, current, -1))
		_rebuild()))
	row.add_child(shown)
	row.add_child(_button("▶", func() -> void:
		chosen.call(stepped(ids, current, 1))
		_rebuild()))
	_body.add_child(row)


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	_body.add_child(label)


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	return button
