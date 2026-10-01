class_name Hud
extends CanvasLayer
## Always-visible info: clock and speed, where the player is, the control mode, the
## minimap (top right), key hints, short notices.

const NOTICE_SECONDS: float = 2.5
## The minimap's size on screen and its scale.
const MINIMAP_SIZE: Vector2 = Vector2(224, 144)
const MINIMAP_PX_PER_CELL: float = 4.0

var _clock_label: Label
var _money_label: Label
var _place_label: Label
var _mode_label: Label
var _hint_label: Label
var _notice_label: Label
var _notice_time_left: float = 0.0
## The person inspector panel (T-0041; PlayerController selects who it shows).
var inspector: PersonInspector


## The key hints for the bottom line, by control mode.
static func hint_text(command_mode: bool) -> String:
	if command_mode:
		return "Click an object to use it, the ground to walk   Shift run   WASD / right-drag pan   R/F floors   Tab direct mode   M map   Space pause   1-3 speed   Wheel zoom   Esc menu   F9 report a bug"
	return "WASD move   Shift run   E use   R/F stairs   Tab command mode   M map   Space pause   1-3 speed   Wheel zoom   F5 save   F8 load   Esc menu   F9 report a bug"


## The command-mode label: "Command mode", plus " · floor N" while viewing another floor
## than the player's.
static func mode_text(viewed_level: int, player: Person) -> String:
	if player != null and viewed_level != player.level:
		return "Command mode · floor %d" % viewed_level
	return "Command mode"


## The player's money for the HUD: "Cash €40.00 · Bank €300.00" ("" for nobody).
static func money_text(person: Person) -> String:
	if person == null:
		return ""
	return "Cash %s · Bank %s" % [Money.format(person.wallet.cash), Money.format(person.wallet.bank)]


## Where `person` is: the place's name, plus " (closed, opens 17:00)" while its lot is closed for
## opening hours; "Altstadt" outside every place.
static func place_text(sim: Sim, person: Person) -> String:
	var place: PlaceDef = sim.content.place_at(person.cell()) if person != null else null
	if place == null:
		return "Altstadt"
	var lot := Lots.by_place(sim.world, place.id)
	if lot != null and not Lots.is_open(lot, sim.clock):
		return "%s (closed, %s)" % [place.name, Lots.opening_text(lot, sim.clock)]
	return place.name


## Words for why the player's action failed (action_failed reasons; Requirements.TEXT adds
## the reasons an action can be refused or fail for); others show nothing.
const FAIL_REASONS: Dictionary = {
	"no_free_slot": "someone is using it",
	"no_path": "can't get there",
	"target_busy": "they're busy",
	"target_left": "they walked away",
}


## The notice a sim event deserves for the player ("" for none). `content` names the
## interaction of a failed action (its id is used without it).
static func notice_for_event(event: Dictionary, player_id: int, content: ContentDB = null, sim: Sim = null) -> String:
	var data: Dictionary = event.get("data", {})
	if event.get("type") == &"social_exchange":
		return social_notice(data, player_id, content, sim)
	if int(data.get("person_id", -1)) != player_id:
		return ""
	if event.get("type") == &"path_failed":
		return "Can't get there"
	var reason := String(data.get("reason", ""))
	if event.get("type") in [&"action_failed", &"action_refused"] and (FAIL_REASONS.has(reason) or Requirements.TEXT.has(reason)):
		var interaction_id := String(data.get("interaction_id", ""))
		var def: InteractionDef = content.interaction(interaction_id) if content != null else null
		var name := def.name if def != null else interaction_id
		var words: String = FAIL_REASONS[reason] if FAIL_REASONS.has(reason) else InteractionMenu.reason_text(sim, reason, int(data.get("target_id", 0))) if sim != null else Requirements.text(reason)
		return "%s: %s" % [name, words]
	if event.get("type") == &"action_cancelled" and data.get("performing", false):
		var paid: InteractionDef = content.interaction(String(data.get("interaction_id", ""))) if content != null else null
		if paid != null and paid.price > 0:
			return "%s: you left before finishing" % paid.name
	return ""


func _ready() -> void:
	var top := _panel(Vector2(12, 12))
	var box := VBoxContainer.new()
	top.add_child(box)
	_clock_label = _label(box, 20)
	_money_label = _label(box, 14)
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

	var minimap_panel := _panel(Vector2.ZERO)
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap_panel.offset_left = -12
	minimap_panel.offset_right = -12
	minimap_panel.offset_top = 12
	var minimap_box := VBoxContainer.new()
	minimap_panel.add_child(minimap_box)
	var minimap := MapView.new()
	minimap.follow = true
	minimap.px_per_cell = MINIMAP_PX_PER_CELL
	minimap.custom_minimum_size = MINIMAP_SIZE
	minimap_box.add_child(minimap)
	var caption := _label(minimap_box, 12)
	caption.text = "M map"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.modulate = Color(1, 1, 1, 0.75)

	var needs_panel := NeedsPanel.new()
	needs_panel.anchor_top = 1.0
	needs_panel.anchor_bottom = 1.0
	needs_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	needs_panel.offset_left = 12
	needs_panel.offset_top = -56
	needs_panel.offset_bottom = -56
	add_child(needs_panel)
	add_child(ActionQueuePanel.new())
	inspector = PersonInspector.new()
	add_child(inspector)

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
	if Session.skipping:
		speed_text = "▶▶ skipping"
	_clock_label.text = "Day %d   %s   %s" % [Session.sim.clock.day() + 1, Session.sim.clock.format(), speed_text]
	_money_label.text = money_text(Session.sim.world.player())
	_place_label.text = place_text(Session.sim, Session.sim.world.player())
	_mode_label.text = mode_text(Session.viewed_level, Session.sim.world.player())
	if _notice_time_left > 0.0:
		_notice_time_left -= delta
		_notice_label.modulate.a = clampf(_notice_time_left, 0.0, 1.0)


func _on_command_mode_changed(on: bool) -> void:
	_mode_label.visible = on
	_hint_label.text = hint_text(on)


## How a social exchange went, when the player took part: "Chat with Mira Kovač: went well",
## or "Mira Kovač: Tell a joke" when someone does it to the player (T-0053).
static func social_notice(data: Dictionary, player_id: int, content: ContentDB, sim: Sim) -> String:
	var interaction: InteractionDef = content.interaction(String(data.get("interaction_id", ""))) if content != null else null
	var label := interaction.name if interaction != null else String(data.get("interaction_id", ""))
	var actor_id := int(data.get("actor_id", 0))
	var target_id := int(data.get("target_id", 0))
	if actor_id == player_id:
		var other := sim.world.get_person(target_id) if sim != null else null
		var verdict := "went well" if data.get("outcome") == "success" else "didn't go well"
		return "%s with %s: %s" % [label, other.full_name() if other != null else "them", verdict]
	if target_id == player_id:
		var actor := sim.world.get_person(actor_id) if sim != null else null
		return "%s: %s" % [actor.full_name() if actor != null else "Someone", label]
	return ""


func _on_sim_event(event: Dictionary) -> void:
	if Session.sim == null or Session.sim.world.player() == null:
		return
	var text := notice_for_event(event, Session.sim.world.player_id, Session.content, Session.sim)
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
