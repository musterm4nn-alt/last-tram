class_name CreatorRows
extends RefCounted
## Row builders shared by the character creator's tabs: a labelled ◀ option ▶ picker and a
## labelled number box.

const LABEL_WIDTH: float = 110.0
const OPTION_WIDTH: float = 170.0


## Adds "label ◀ option ▶" to `page`; returns the label that shows the option's name.
static func picker(page: VBoxContainer, label_text: String, on_back: Callable, on_forward: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	row.add_child(_name(label_text))
	var back := Button.new()
	back.text = "◀"
	back.pressed.connect(on_back)
	row.add_child(back)
	var shown := Label.new()
	shown.custom_minimum_size = Vector2(OPTION_WIDTH, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(shown)
	var forward := Button.new()
	forward.text = "▶"
	forward.pressed.connect(on_forward)
	row.add_child(forward)
	return shown


## Adds "label [number]" to `page` and returns the number box.
static func spin(page: VBoxContainer, label_text: String, low: int, high: int, suffix: String) -> SpinBox:
	var row := HBoxContainer.new()
	page.add_child(row)
	row.add_child(_name(label_text))
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = 1
	box.suffix = suffix
	row.add_child(box)
	return box


static func _name(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	return label
