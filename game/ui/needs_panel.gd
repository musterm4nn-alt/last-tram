class_name NeedsPanel
extends PanelContainer
## HUD panel: one bar per need (data/needs.json order) and the mood label. Reads the
## player's needs from Session every frame; never writes sim state.

const GOOD_COLOR: Color = Color("#6fae5a")      # value >= 60
const OK_COLOR: Color = Color("#d6b545")        # 30 <= value < 60
const LOW_COLOR: Color = Color("#c8553d")       # value < 30
const BAR_BACKGROUND: Color = Color(1, 1, 1, 0.12)
const BAR_SIZE: Vector2 = Vector2(120, 10)

const LABEL_MIN_WIDTH: float = 74.0
const LABEL_FONT_SIZE: int = 13
const MOOD_FONT_SIZE: int = 14
const ROW_SEPARATION: int = 4

var _bars: Dictionary[String, ProgressBar] = {}   # need id -> bar, in data order
var _fills: Dictionary[String, StyleBoxFlat] = {} # need id -> the bar's fill style
var _mood_label: Label


## Bar colour for a need value 0..100.
static func bar_color(value: float) -> Color:
	if value >= 60.0:
		return GOOD_COLOR
	if value >= 30.0:
		return OK_COLOR
	return LOW_COLOR


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.78)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	build(Session.content)


## Builds one row per need (call once). Tests call this directly with test content.
func build(content: ContentDB) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(box)
	for need_def: NeedDef in content.needs:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = need_def.name
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.custom_minimum_size = Vector2(LABEL_MIN_WIDTH, 0)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = BAR_SIZE
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOOD_COLOR
		bar.add_theme_stylebox_override("fill", fill)
		var background := StyleBoxFlat.new()
		background.bg_color = BAR_BACKGROUND
		bar.add_theme_stylebox_override("background", background)
		row.add_child(bar)
		_bars[need_def.id] = bar
		_fills[need_def.id] = fill
	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", MOOD_FONT_SIZE)
	box.add_child(_mood_label)


## Shows `person`'s needs and mood.
func show_person(person: Person, content: ContentDB) -> void:
	for need_def: NeedDef in content.needs:
		var value: float = float(person.needs.get(need_def.id, need_def.start))
		_bars[need_def.id].value = value
		_fills[need_def.id].bg_color = bar_color(value)
	_mood_label.text = "Mood: %s" % Mood.label(Mood.compute(person, content))


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player != null:
		show_person(player, Session.content)
