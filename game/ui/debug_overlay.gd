class_name DebugOverlay
extends CanvasLayer
## F3: technical readout for playtesting and screenshots (time, performance, player state,
## recent sim events). Add a line here whenever a new system has state worth watching.

var _label: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -12
	_panel.offset_top = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_label)
	add_child(_panel)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or Session.sim == null:
		return
	var sim := Session.sim
	var lines: PackedStringArray = []
	lines.append("FPS %d   speed %d   steps/frame %d   sim %.2f ms" % [
		Engine.get_frames_per_second(), Session.speed, Session.steps_last_frame, Session.sim_usec_last_frame / 1000.0])
	lines.append("tick %d   day %d   %s" % [sim.clock.tick, sim.clock.day(), sim.clock.format()])
	lines.append("people %d   commands logged %d" % [sim.world.people.size(), Session.command_log.size()])
	var player := sim.world.player()
	if player != null:
		var cell := player.cell()
		lines.append("player #%d %s (%d)" % [player.id, player.display_name(), player.age_years])
		lines.append("  pos (%.2f, %.2f)  cell (%d, %d, %d)" % [player.pos.x, player.pos.y, cell.x, cell.y, cell.z])
		lines.append("  terrain %s   intent (%.2f, %.2f)" % [
			sim.world.grid.terrain_def_at(cell).id, player.move_intent.x, player.move_intent.y])
		var need_parts: PackedStringArray = []
		for need_def: NeedDef in sim.content.needs:
			need_parts.append("%s %.0f" % [need_def.id, float(player.needs.get(need_def.id, need_def.start))])
		var mood_value: float = Mood.compute(player, sim.content)
		lines.append("  needs %s   mood %.0f (%s)" % [" ".join(need_parts), mood_value, Mood.label(mood_value)])
		if player.free_will:
			var idle_minutes := (sim.clock.tick - player.last_input_tick) / SimClock.STEPS_PER_GAME_MINUTE
			lines.append("  free will on (idle %d min)" % idle_minutes)
		else:
			lines.append("  free will off")
		if player.action_queue.is_empty():
			lines.append("  actions: (empty)")
		else:
			var queue_parts: PackedStringArray = []
			for action: Action in player.action_queue:
				queue_parts.append("%s [%s]" % [action.interaction_id, action.state])
			lines.append("  actions: %s" % [" <- ".join(queue_parts)])
	lines.append("recent events:")
	var recent := sim.events.recent
	for i: int in range(maxi(0, recent.size() - 6), recent.size()):
		lines.append("  %d %s %s" % [recent[i]["tick"], recent[i]["type"], recent[i]["data"]])
	_label.text = "\n".join(lines)
