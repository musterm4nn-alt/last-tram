class_name Hud
extends CanvasLayer
## Always-visible info: clock and speed, where the player is, key hints, short notices.

const NOTICE_SECONDS: float = 2.5

var _clock_label: Label
var _place_label: Label
var _notice_label: Label
var _notice_time_left: float = 0.0


func _ready() -> void:
	var top := _panel(Vector2(12, 12))
	var box := VBoxContainer.new()
	top.add_child(box)
	_clock_label = _label(box, 20)
	_place_label = _label(box, 14)

	var hints := _panel(Vector2(12, 0))
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.offset_top = -12
	hints.offset_bottom = -12
	var hint_label := _label(hints, 13)
	hint_label.text = "WASD move   Space pause   1-3 speed   Wheel zoom   F5 save   F8 load   F3 debug"
	hint_label.modulate = Color(1, 1, 1, 0.75)

	_notice_label = Label.new()
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_label.offset_top = 16
	_notice_label.add_theme_font_size_override("font_size", 18)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_notice_label)

	Session.notice.connect(_show_notice)


func _process(delta: float) -> void:
	if Session.sim == null:
		return
	var speed_text := "PAUSED" if Session.speed == 0 else "%dx" % Session.speed
	_clock_label.text = "Day %d   %s   %s" % [Session.sim.clock.day() + 1, Session.sim.clock.format(), speed_text]
	var player := Session.sim.world.player()
	var place: PlaceDef = Session.content.place_at(player.cell()) if player != null else null
	_place_label.text = place.name if place != null else "Altstadt"
	if _notice_time_left > 0.0:
		_notice_time_left -= delta
		_notice_label.modulate.a = clampf(_notice_time_left, 0.0, 1.0)


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_time_left = NOTICE_SECONDS


func _panel(at: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.78)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label
