class_name SkipOverlay
extends CanvasLayer
## "Skipping… 03:40 (Esc to stop)" across the top while time is skipped (T-0078). View only.

var _label: Label


func _init() -> void:
	layer = 11
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_top = 56
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_label)
	visible = false


func _process(_delta: float) -> void:
	visible = Session.sim != null and Session.skipping
	if visible:
		_label.text = text(Session.sim)


## The overlay's words for the clock now.
static func text(sim: Sim) -> String:
	return "Skipping… %s (Esc to stop)" % sim.clock.format()
