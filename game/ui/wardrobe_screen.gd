class_name WardrobeScreen
extends CanvasLayer
## The wardrobe (T-0072): opened when the player's "Change clothes" finishes
## (&"screen_requested" "wardrobe"). The creator's clothes rows, limited to what the player
## owns, plus their saved outfits. "Put it on" and "Save as …" send a ChangeOutfitCommand.
## Pauses the game while open, like the scene popup. View only.

## True while shown (the rest of the game ignores input then).
var is_open: bool = false
## The outfit being put together (only owned clothes).
var model: CreatorModel

var _speed_before: int = 1
var _body: VBoxContainer
## Saved outfits as the screen knows them (the commands apply when the game runs again).
var _saved: Dictionary[String, Outfit] = {}


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
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	panel.add_child(_body)
	visible = false


func _ready() -> void:
	Session.sim_event.connect(func(event: Dictionary) -> void:
		var data: Dictionary = event.get("data", {})
		if event.get("type") == &"screen_requested" and data.get("screen") == "wardrobe" and Session.sim != null \
				and int(data.get("person_id", -1)) == Session.sim.world.player_id:
			open())
	Session.game_loaded.connect(func() -> void:
		if is_open:
			close())


## Shows the player's wardrobe and pauses the game.
func open() -> void:
	var player := Session.sim.world.player()
	if player == null:
		return
	var spec := CharacterSpec.new()
	spec.outfit = player.outfit.copy()
	model = CreatorModel.new(Session.content, spec)
	model.owned = player.wardrobe.duplicate()
	model.only_owned = true
	_saved = {}
	for name: String in player.outfits:
		_saved[name] = player.outfits[name].copy()
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


## Puts the outfit on (and saves it under `save_as` unless "").
func wear(save_as: String = "") -> void:
	var player_id := Session.sim.world.player_id
	Session.submit(ChangeOutfitCommand.new(player_id, model.spec.outfit.to_dict(), save_as))
	if not save_as.is_empty():
		_saved[save_as] = model.spec.outfit.copy()


func _rebuild() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Wardrobe"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var tab := CreatorClothesTab.new()
	tab.build(model)
	tab.sync(model)
	tab.changed.connect(func() -> void: tab.sync(model))
	_body.add_child(tab)
	var saved_row := HBoxContainer.new()
	for name: String in Wardrobe.OUTFIT_NAMES:
		if _saved.has(name):
			saved_row.add_child(_button("Pick " + name, func() -> void:
				model.spec.outfit = _saved[name].copy()
				_rebuild()))
	_body.add_child(saved_row)
	var save_row := HBoxContainer.new()
	for name: String in Wardrobe.OUTFIT_NAMES:
		save_row.add_child(_button("Save as " + name, func() -> void:
			wear(name)
			_rebuild()))
	_body.add_child(save_row)
	var end_row := HBoxContainer.new()
	end_row.add_child(_button("Put it on", func() -> void:
		wear()
		close()))
	end_row.add_child(_button("Close", close))
	_body.add_child(end_row)


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	return button
