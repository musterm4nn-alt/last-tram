class_name CreatorClothesTab
extends VBoxContainer
## The character creator's Clothes tab: one row per clothing slot with starter items. Each
## row steps through the items (or "None" for optional slots) and offers the item's colours
## as swatches; the chosen colour has a light border. Emits `changed` after every choice.

## The model changed; the creator refreshes the preview and Start.
signal changed

const SWATCH_SIZE: Vector2 = Vector2(22, 22)
const SLOT_WIDTH: float = 64.0
const ITEM_WIDTH: float = 120.0
const CHOSEN_BORDER: Color = Color(0.95, 0.95, 0.95)
## A thin outline on every swatch, so black shows on the dark panel.
const SWATCH_BORDER: Color = Color(1, 1, 1, 0.35)

var _model: CreatorModel
## Slot -> the label showing the worn item.
var _items: Dictionary[String, Label] = {}
## Slot -> the row of colour swatches.
var _swatches: Dictionary[String, HBoxContainer] = {}


## Builds one row per slot for `model` (call once).
func build(model: CreatorModel) -> void:
	_model = model
	add_theme_constant_override("separation", 6)
	for slot: String in ClothingDef.SLOTS:
		var options := model.clothing_options(slot)
		if options.is_empty() or (options.size() == 1 and options[0] == ""):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var label := Label.new()
		label.text = slot.capitalize()
		label.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
		row.add_child(label)
		row.add_child(_arrow("◀", _on_step.bind(slot, -1)))
		var shown := Label.new()
		shown.custom_minimum_size = Vector2(ITEM_WIDTH, 0)
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(shown)
		row.add_child(_arrow("▶", _on_step.bind(slot, 1)))
		var swatches := HBoxContainer.new()
		swatches.add_theme_constant_override("separation", 2)
		row.add_child(swatches)
		_items[slot] = shown
		_swatches[slot] = swatches


## Shows `model`'s outfit (it may be a new model, e.g. after a seeded start).
func sync(model: CreatorModel) -> void:
	_model = model
	for slot: String in _items:
		var def := Session.content.clothing_def(model.clothing(slot))
		_items[slot].text = def.name if def != null else "None"
		_rebuild_swatches(slot)


func _rebuild_swatches(slot: String) -> void:
	var row := _swatches[slot]
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var worn := _model.spec.outfit.get_item(slot)
	for colour_id: String in _model.colour_options(slot):
		var option: ColorOption = Session.content.clothing_colours.get(colour_id)
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = option.name if option != null else colour_id
		var style := StyleBoxFlat.new()
		style.bg_color = option.color if option != null else ViewConfig.UNKNOWN_ID_COLOR
		style.set_corner_radius_all(3)
		style.set_border_width_all(1)
		style.border_color = SWATCH_BORDER
		if worn != null and worn.colour == colour_id:
			style.set_border_width_all(2)
			style.border_color = CHOSEN_BORDER
		for state: String in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(_on_colour.bind(slot, colour_id))
		row.add_child(swatch)


func _arrow(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _on_step(slot: String, direction: int) -> void:
	if direction > 0:
		_model.next_clothing(slot)
	else:
		_model.previous_clothing(slot)
	changed.emit()


func _on_colour(slot: String, colour_id: String) -> void:
	_model.set_colour(slot, colour_id)
	changed.emit()
