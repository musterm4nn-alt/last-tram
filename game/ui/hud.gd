class_name Hud
extends CanvasLayer
## Always-visible info: clock and speed, where the player is, the control mode, key hints,
## short notices.

const NOTICE_SECONDS: float = 2.5

var _clock_label: Label
var _place_label: Label
var _mode_label: Label
var _hint_label: Label
var _notice_label: Label
var _notice_time_left: float = 0.0


## The key hints for the bottom line, by control mode.
static func hint_text(command_mode: bool) -> String:
	if command_mode:
		return "Click an object to use it, the ground to walk   WASD / right-drag pan   Tab direct mode   Space pause   1-3 speed   Wheel zoom"
	return "WASD move   E use   Tab command mode   Space pause   1-3 speed   Wheel zoom   F5 save   F8 load   F3 debug"


## Words for why the player's action failed (action_failed reasons); others show nothing.
const FAIL_REASONS: Dictionary = {
	"no_free_slot": "someone is using it",
	"no_path": "can't get there",
}


## The notice a sim event deserves for the player ("" for none). `content` names the
## interaction of a failed action (its id is used without it).
static func notice_for_event(event: Dictionary, player_id: int, content: ContentDB = null) -> String:
	var data: Dictionary = event.get("data", {})
	if int(data.get("person_id", -1)) != player_id:
		return ""
	if event.get("type") == &"path_failed":
		return "Can't get there"
	if event.get("type") == &"action_failed" and FAIL_REASONS.has(String(data.get("reason", ""))):
		var interaction_id := String(data.get("interaction_id", ""))
		var def: InteractionDef = content.interaction(interaction_id) if content != null else null
		var name := def.name if def != null else interaction_id
		return "%s: %s" % [name, FAIL_REASONS[String(data["reason"])]]
	return ""


func _ready() -> void:
	var top := _panel(Vector2(12, 12))
	var box := VBoxContainer.new()
	top.add_child(box)
	_clock_label = _label(box, 20)
	_place_label = _label(box, 14)
	_mode_label = _label(box, 14)
	_mode_label.text = "Command mode"
	_mode_label.modulate = ViewConfig.PLAYER_MARKER_COLOR
	_mode_label.visible = Session.command_mode

	var hints := _panel(Vector2(12, 0))
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.offset_top = -12
	hints.offset_bottom = -12
	_hint_label = _label(hints, 13)
	_hint_label.text = hint_text(Session.command_mode)
	_hint_label.modulate = Color(1, 1, 1, 0.75)

	var needs_panel := NeedsPanel.new()
	needs_panel.anchor_top = 1.0
	needs_panel.anchor_bottom = 1.0
	needs_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	needs_panel.offset_left = 12
	needs_panel.offset_top = -56
	needs_panel.offset_bottom = -56
	add_child(needs_panel)

	_notice_label = Label.new()
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_label.offset_top = 16
	_notice_label.add_theme_font_size_override("font_size", 18)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_notice_label)

	Session.notice.connect(_show_notice)
	Session.command_mode_changed.connect(_on_command_mode_changed)
	Session.sim_event.connect(_on_sim_event)


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


func _on_command_mode_changed(on: bool) -> void:
	_mode_label.visible = on
	_hint_label.text = hint_text(on)


func _on_sim_event(event: Dictionary) -> void:
	if Session.sim == null or Session.sim.world.player() == null:
		return
	var text := notice_for_event(event, Session.sim.world.player_id, Session.content)
	if not text.is_empty():
		_show_notice(text)


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
