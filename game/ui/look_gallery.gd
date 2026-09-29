class_name LookGallery
extends CanvasLayer
## A checking screen (--screen=gallery): the default look changed one thing at a time, each
## as a small portrait over a top-down figure, labelled. Page 1: every hair style, build,
## facial hair, feature (alone and all together) and skin tone. Page 2: one outfit per
## starter item of every clothing slot. Screenshot it to see every option at once.

const COLUMNS: int = 13
const PORTRAIT_SIZE: Vector2 = Vector2(72, 86)
const FIGURE_PX: float = 34.0

var _page: int = 1


func _init(page: int = 1) -> void:
	_page = clampi(page, 1, 2)
	layer = 22


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.12, 0.14)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.position = Vector2(8, 8)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for entry: Dictionary in entries(Session.content, _page):
		grid.add_child(_cell(String(entry["label"]), entry["spec"]))


## The cells of a page: [{"label": String, "spec": CharacterSpec}], each the default look
## with one change.
static func entries(content: ContentDB, page: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var catalog: AppearanceCatalog = content.appearance
	if page == 2:
		for slot: String in ClothingDef.SLOTS:
			for item: ClothingDef in content.clothing.values():
				if item.slot == slot and item.starter:
					var spec := CharacterSpec.default_player(content)
					spec.outfit.put_on(slot, item.id, item.colours[0])
					out.append({"label": item.name, "spec": spec})
		return out
	for id: String in catalog.hair_styles:
		var spec := CharacterSpec.default_player(content)
		spec.appearance.hair_style = id
		out.append({"label": catalog.hair_styles[id].name, "spec": spec})
	for id: String in catalog.builds:
		var spec := CharacterSpec.default_player(content)
		spec.appearance.build = id
		out.append({"label": catalog.builds[id].name, "spec": spec})
	for id: String in catalog.facial_hair:
		var spec := CharacterSpec.default_player(content)
		spec.appearance.facial_hair = id
		out.append({"label": catalog.facial_hair[id].name, "spec": spec})
	for id: String in catalog.features:
		var spec := CharacterSpec.default_player(content)
		spec.appearance.features = PackedStringArray([id])
		out.append({"label": catalog.features[id].name, "spec": spec})
	var all := CharacterSpec.default_player(content)
	all.appearance.features = PackedStringArray(catalog.features.keys())
	out.append({"label": "All features", "spec": all})
	for id: String in catalog.skin_tones:
		var spec := CharacterSpec.default_player(content)
		spec.appearance.skin_tone = id
		out.append({"label": catalog.skin_tones[id].name, "spec": spec})
	return out


func _cell(label_text: String, spec: CharacterSpec) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var portrait := CharacterPortrait.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.show_look(spec.appearance, spec.outfit)
	box.add_child(portrait)
	var figure := Control.new()
	figure.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, FIGURE_PX * 1.6)
	figure.draw.connect(func() -> void:
		figure.draw_set_transform(Vector2(PORTRAIT_SIZE.x / 2.0, FIGURE_PX * 1.5))
		PersonDrawer2D.draw(figure, Session.content, spec.appearance, spec.outfit, Vector2.DOWN, FIGURE_PX, false))
	box.add_child(figure)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, 0)
	label.clip_text = true
	box.add_child(label)
	return box
