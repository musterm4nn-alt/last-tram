class_name ActionQueuePanel
extends PanelContainer
## HUD panel at the bottom centre: what the player is doing (with a progress bar) and what
## is queued after it, each with a × button that cancels it. Hidden while the queue is
## empty. Reads sim state; cancelling submits CancelActionCommand.

const BAR_SIZE: Vector2 = Vector2(160, 8)
const FONT_SIZE: int = 13

var _rows: VBoxContainer
var _bar: ProgressBar
var _signature: String = ""


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.78)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the key-hint line, level with the needs panel.
	offset_top = -56
	offset_bottom = -56
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)
	visible = false


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player != null:
		show_person(player, Session.content)


## Shows `person`'s queue: rebuilds the rows when it changed, else updates the bar.
func show_person(person: Person, content: ContentDB) -> void:
	visible = not person.action_queue.is_empty()
	var now := signature(person)
	if now != _signature:
		_signature = now
		_rebuild(person, content)
	if _bar != null and not person.action_queue.is_empty():
		_bar.value = progress(person.action_queue[0], person, content)


## "Grab a snack · walking there" (front, QUEUED or ROUTING), "Grab a snack" (front,
## PERFORMING), "Then: Watch TV" (every other row). Unknown interaction ids show the id.
static func row_text(action: Action, index: int, content: ContentDB) -> String:
	var def := content.interaction(action.interaction_id)
	var name := def.name if def != null else action.interaction_id
	if index > 0:
		return "Then: %s" % name
	if action.state == Action.PERFORMING:
		return name
	return "%s · walking there" % name


## 0..1 for the front action: minutes_done / duration_minutes for fixed-length ones; the
## need's value / 100 for until_need ones (e.g. energy while sleeping); 0 unless PERFORMING.
static func progress(action: Action, person: Person, content: ContentDB) -> float:
	if action.state != Action.PERFORMING:
		return 0.0
	var def := content.interaction(action.interaction_id)
	if def == null:
		return 0.0
	if not def.until_need.is_empty():
		return clampf(float(person.needs.get(def.until_need, 0.0)) / 100.0, 0.0, 1.0)
	if def.duration_minutes <= 0:
		return 0.0
	return clampf(float(action.minutes_done) / float(def.duration_minutes), 0.0, 1.0)


## Changes whenever rows must be rebuilt: "<id>:<state>" for each action, joined by "|".
static func signature(person: Person) -> String:
	var parts := PackedStringArray()
	for action: Action in person.action_queue:
		parts.append("%s:%s" % [action.interaction_id, action.state])
	return "|".join(parts)


func _rebuild(person: Person, content: ContentDB) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_bar = null
	for index: int in person.action_queue.size():
		var action: Action = person.action_queue[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)
		var label := Label.new()
		label.text = row_text(action, index, content)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		# Fill the row so every × lines up on the right.
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if index == 0:
			_bar = ProgressBar.new()
			_bar.min_value = 0.0
			_bar.max_value = 1.0
			_bar.show_percentage = false
			_bar.custom_minimum_size = BAR_SIZE
			_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(_bar)
		var cancel := Button.new()
		cancel.text = "×"
		cancel.tooltip_text = "Cancel"
		cancel.flat = true
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.pressed.connect(_on_cancel.bind(person.id, index))
		row.add_child(cancel)


func _on_cancel(person_id: int, index: int) -> void:
	Session.submit(CancelActionCommand.new(person_id, index))
