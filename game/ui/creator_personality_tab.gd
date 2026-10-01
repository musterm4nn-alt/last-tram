class_name CreatorPersonalityTab
extends VBoxContainer
## The character creator's Personality tab: one slider per Personality axis (−100..100),
## with plain words for each end. Emits `changed` after every move.

## The model changed; the creator refreshes the preview and Start.
signal changed

## Axis -> [word for the low end, word for the high end].
const WORDS: Dictionary = {
	"kindness": ["cruel", "caring"],
	"honesty": ["deceitful", "principled"],
	"sociability": ["loner", "outgoing"],
	"ambition": ["idle", "driven"],
	"temper": ["calm", "hot-headed"],
	"vice": ["restrained", "indulgent"],
	"bravery": ["timid", "bold"],
}
const AXIS_WIDTH: float = 90.0
const WORD_WIDTH: float = 80.0
const SLIDER_WIDTH: float = 150.0
## Whole steps, so random personalities show exactly.
const STEP: float = 1.0

var _model: CreatorModel
## Axis -> its slider.
var _sliders: Dictionary[String, HSlider] = {}


## Builds one row per axis for `model` (call once).
func build(model: CreatorModel) -> void:
	_model = model
	add_theme_constant_override("separation", 8)
	for axis: String in Personality.AXES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		row.add_child(_label(axis.capitalize(), AXIS_WIDTH, HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(_label(WORDS[axis][0], WORD_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT))
		var slider := HSlider.new()
		slider.min_value = Personality.MIN_VALUE
		slider.max_value = Personality.MAX_VALUE
		slider.step = STEP
		slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slide.bind(axis))
		row.add_child(slider)
		row.add_child(_label(WORDS[axis][1], WORD_WIDTH, HORIZONTAL_ALIGNMENT_LEFT))
		_sliders[axis] = slider


## Shows `model`'s personality (it may be a new model, e.g. after a seeded start).
func sync(model: CreatorModel) -> void:
	_model = model
	for axis: String in _sliders:
		_sliders[axis].set_value_no_signal(model.spec.personality.get_axis(axis))


func _on_slide(value: float, axis: String) -> void:
	_model.set_trait(axis, int(value))
	changed.emit()


func _label(text: String, width: float, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.horizontal_alignment = align
	return label
