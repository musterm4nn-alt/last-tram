class_name BubblesLayer
extends CanvasLayer
## Speech and thought bubbles over people's heads (T-0040). A social exchange shows the
## actor's line (DialogueProvider), and a need going critical shows a thought. Bubbles last
## BUBBLE_SECONDS of real time and only show for people on the viewed floor. View only: reads
## events and positions, never changes the sim.

const BUBBLE_SECONDS: float = 3.5
const FONT_SIZE: int = 13
const PADDING: Vector2 = Vector2(6, 3)
## Above the feet, in cells (a figure is about 1.4 cells tall).
const HEAD_OFFSET: float = 1.7
const SPEECH_FILL: Color = Color(0.97, 0.97, 0.94, 0.95)
const THOUGHT_FILL: Color = Color(0.8, 0.84, 0.92, 0.92)
const TEXT_COLOR: Color = Color(0.08, 0.08, 0.1)

## Person id -> {"text": String, "thought": bool, "left": float (seconds)}.
var bubbles: Dictionary[int, Dictionary] = {}
var provider: DialogueProvider

var _canvas: Control


func _init() -> void:
	layer = 1
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bubbles)
	add_child(_canvas)


func _ready() -> void:
	Session.sim_event.connect(on_sim_event)
	Session.game_loaded.connect(func() -> void: bubbles.clear())
	if provider == null:
		provider = SystemicDialogue.new(Session.content)


## Adds a bubble for a sim event when it deserves one (public for tests).
func on_sim_event(event: Dictionary) -> void:
	var data: Dictionary = event.get("data", {})
	match event.get("type"):
		&"social_exchange":
			var exchange := data.duplicate()
			exchange["tick"] = event.get("tick", 0)
			var text := provider.line_for(exchange, Session.sim)
			if not text.is_empty():
				bubbles[int(data["actor_id"])] = {"text": text, "thought": false, "left": BUBBLE_SECONDS}
		&"need_critical":
			var thought := provider.thought_for(String(data.get("need", "")))
			if not thought.is_empty():
				bubbles[int(data["person_id"])] = {"text": thought, "thought": true, "left": BUBBLE_SECONDS}


func _process(delta: float) -> void:
	for id: int in bubbles.keys():
		bubbles[id]["left"] = float(bubbles[id]["left"]) - delta
		if float(bubbles[id]["left"]) <= 0.0:
			bubbles.erase(id)
	_canvas.queue_redraw()


func _draw_bubbles() -> void:
	if Session.sim == null or bubbles.is_empty():
		return
	var font := _canvas.get_theme_default_font()
	var to_screen := _canvas.get_viewport().get_canvas_transform()
	# Newest first; a bubble that would cover a newer one waits its turn.
	var order: Array = bubbles.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return float(bubbles[a]["left"]) > float(bubbles[b]["left"]))
	var drawn: Array[Rect2] = []
	for id: int in order:
		var person := Session.sim.world.get_person(id)
		if person == null or person.level != Session.viewed_level:
			continue
		var bubble: Dictionary = bubbles[id]
		var text: String = bubble["text"]
		var feet := person.prev_pos.lerp(person.pos, Session.alpha) - Vector2(0, HEAD_OFFSET)
		var anchor := to_screen * (feet * ViewConfig.TILE_PX)
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE) + PADDING * 2.0
		var box := Rect2(anchor - Vector2(size.x / 2.0, size.y), size)
		if drawn.any(func(other: Rect2) -> bool: return other.intersects(box)):
			continue
		drawn.append(box)
		var fill := THOUGHT_FILL if bubble["thought"] else SPEECH_FILL
		fill.a *= clampf(float(bubble["left"]), 0.0, 1.0)
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(int(size.y / 2.0) if bubble["thought"] else 4)
		_canvas.draw_style_box(style, box)
		if not bubble["thought"]:
			_canvas.draw_colored_polygon(PackedVector2Array([anchor + Vector2(-4, 0), anchor + Vector2(4, 0), anchor + Vector2(0, 6)]), fill)
		var ink := TEXT_COLOR
		ink.a = fill.a
		_canvas.draw_string(font, box.position + Vector2(PADDING.x, PADDING.y + FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
