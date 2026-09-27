class_name PersonDrawer2D
extends RefCounted
## Draws a top-down placeholder person (readable until the art gate): skin tone, hair
## style and colour, build and height, facial hair, glasses, and clothes in their
## colours. The player gets a small yellow marker instead of a yellow body. All person
## drawing lives here so the character creator preview (T-0021) can reuse it.


## Draws a top-down placeholder person with their feet at (0, 0) on `canvas`.
## `px` is pixels per cell. Unknown content ids draw magenta so mistakes show up.
static func draw(canvas: CanvasItem, content: ContentDB, appearance: Appearance, outfit: Outfit, facing: Vector2, px: float, is_player: bool) -> void:
	var half_w: float = float(ViewConfig.BUILD_WIDTH.get(appearance.build, ViewConfig.DEFAULT_BUILD_WIDTH)) / 2.0
	var height: float = 0.9 * float(appearance.height_cm) / 175.0
	var skin := _skin_color(content, appearance.skin_tone)
	var hair_color := _hair_color(content, appearance.hair_colour)
	var top := _worn_color(content, outfit, "top")
	var bottom := _worn_color(content, outfit, "bottom")
	var feet := _worn_color(content, outfit, "feet")
	var facing_down := facing.y > 0.5
	var facing_up := facing.y < -0.5
	# Shadow, legs (lower ~45% of the body) and shoes.
	canvas.draw_circle(Vector2(0, -0.02) * px, 0.28 * px, Color(0, 0, 0, 0.3))
	canvas.draw_rect(Rect2(Vector2(-half_w, -0.45 * height) * px, Vector2(half_w * 2.0, 0.45 * height) * px), bottom)
	var shoe_w: float = half_w * 0.92
	var shoe_h: float = minf(0.12, 0.2 * height)
	canvas.draw_rect(Rect2(Vector2(-half_w, -shoe_h) * px, Vector2(shoe_w, shoe_h) * px), feet)
	canvas.draw_rect(Rect2(Vector2(half_w - shoe_w, -shoe_h) * px, Vector2(shoe_w, shoe_h) * px), feet)
	# Torso, then the outer layer (open jacket: a 2 px stripe of top stays visible).
	canvas.draw_rect(Rect2(Vector2(-half_w, -height) * px, Vector2(half_w * 2.0, 0.55 * height) * px), top)
	var outer := outfit.get_item("outer")
	if outer != null:
		var pad: float = 0.03
		canvas.draw_rect(Rect2(Vector2(-half_w - pad, -height) * px, Vector2((half_w + pad) * 2.0, 0.62 * height) * px), _clothing_color(content, outer.colour))
		if facing_down:
			var stripe: float = 2.0 / px
			canvas.draw_rect(Rect2(Vector2(-stripe / 2.0, -height) * px, Vector2(stripe, 0.62 * height) * px), top)
	canvas.draw_rect(Rect2(Vector2(-half_w, -height) * px, Vector2(half_w * 2.0, height) * px), ViewConfig.OUTLINE_COLOR, false, 1.0)
	# Head, then hair, face and headwear back to front.
	var head_r: float = 0.24
	var head := Vector2(0, -height - head_r * 0.75) * px
	canvas.draw_circle(head, head_r * px, skin)
	var shape := str(ViewConfig.HAIR_SHAPE.get(appearance.hair_style, "cap"))
	if facing_up:
		if shape != "none":
			canvas.draw_circle(head, head_r * px, hair_color)
	else:
		_draw_hair(canvas, head, head_r * px, skin, hair_color, shape, facing)
		_draw_facial_hair(canvas, content, appearance, head, head_r * px, hair_color)
		_draw_glasses(canvas, appearance, head, head_r * px, facing, facing_down)
	_draw_head_item(canvas, content, outfit, head, head_r * px)
	canvas.draw_circle(head, head_r * px, ViewConfig.OUTLINE_COLOR, false, 1.0)
	if is_player:
		var marker_top: float = head.y - head_r * px - 0.05 * px - 0.14 * px
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(-0.08 * px, marker_top),
			Vector2(0.08 * px, marker_top),
			Vector2(0, marker_top + 0.14 * px),
		]), ViewConfig.PLAYER_MARKER_COLOR)


## Hair seen from the front or side. Facing up is handled in draw(): the back of the
## head covers the whole head circle.
static func _draw_hair(canvas: CanvasItem, head: Vector2, r: float, skin: Color, hair_color: Color, shape: String, facing: Vector2) -> void:
	match shape:
		"none":
			pass
		"thin":
			_fan(canvas, head, r * 0.98, PI + 0.6, TAU - 0.6, hair_color)
		"sides":
			_fan(canvas, head, r, PI, TAU, hair_color)
			var side_w: float = r * 0.35
			for side: float in [-1.0, 1.0]:
				canvas.draw_rect(Rect2(head + Vector2(side * r - side_w / 2.0, -r * 0.2), Vector2(side_w, r * 1.4)), hair_color)
		"long":
			_fan(canvas, head, r, PI, TAU, hair_color)
			canvas.draw_rect(Rect2(head + Vector2(-r * 1.1, -r * 0.2), Vector2(r * 2.2, r * 1.8)), hair_color)
		"tail":
			_fan(canvas, head, r, PI, TAU, hair_color)
			var side := signf(facing.x) if absf(facing.x) > 0.5 else 1.0
			canvas.draw_circle(head + Vector2(side * r * 0.95, r * 0.85), r * 0.35, hair_color)
		"bun":
			_fan(canvas, head, r, PI, TAU, hair_color)
			canvas.draw_circle(head + Vector2(0, -r * 1.1), r * 0.42, hair_color)
		"afro":
			canvas.draw_circle(head + Vector2(0, -r * 0.15), r * 1.45, hair_color)
			canvas.draw_circle(head + Vector2(0, r * 0.3), r * 0.8, skin)
		"mohawk":
			canvas.draw_rect(Rect2(head + Vector2(-r * 0.28, -r * 1.05), Vector2(r * 0.56, r * 1.6)), hair_color)
		_:
			_fan(canvas, head, r, PI, TAU, hair_color)


## A darker arc on the lower head, never when facing up (handled by the caller).
static func _draw_facial_hair(canvas: CanvasItem, content: ContentDB, appearance: Appearance, head: Vector2, r: float, hair_color: Color) -> void:
	if appearance.facial_hair.is_empty() or appearance.facial_hair == "none":
		return
	if not content.appearance.facial_hair.has(appearance.facial_hair):
		return
	canvas.draw_arc(head, r * 0.7, PI * 0.15, PI * 0.85, 12, hair_color.darkened(0.4), 2.0)


## The `glasses` feature: two tiny dark squares facing down, one at the side.
static func _draw_glasses(canvas: CanvasItem, appearance: Appearance, head: Vector2, r: float, facing: Vector2, facing_down: bool) -> void:
	if not appearance.features.has("glasses"):
		return
	var dark := Color("#1a1a1a")
	var size: float = 2.0
	if facing_down:
		for side: float in [-1.0, 1.0]:
			var at := head + Vector2(side * r * 0.45, 0)
			canvas.draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), dark)
	else:
		var side := signf(facing.x) if absf(facing.x) > 0.5 else 1.0
		var at := head + Vector2(side * r * 0.55, 0)
		canvas.draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), dark)


## Headwear (cap, beanie): a band in its colour across the head.
static func _draw_head_item(canvas: CanvasItem, content: ContentDB, outfit: Outfit, head: Vector2, r: float) -> void:
	var worn := outfit.get_item("head")
	if worn == null:
		return
	var band_h: float = maxf(2.0, 0.1 * r)
	canvas.draw_rect(Rect2(Vector2(head.x - r, head.y - r * 0.75 - band_h / 2.0), Vector2(r * 2.0, band_h)), _clothing_color(content, worn.colour))


static func _worn_color(content: ContentDB, outfit: Outfit, slot: String) -> Color:
	var worn := outfit.get_item(slot)
	if worn == null:
		return ViewConfig.UNKNOWN_ID_COLOR
	return _clothing_color(content, worn.colour)


static func _skin_color(content: ContentDB, id: String) -> Color:
	if content.appearance.skin_tones.has(id):
		return (content.appearance.skin_tones[id] as ColorOption).color
	return ViewConfig.UNKNOWN_ID_COLOR


static func _hair_color(content: ContentDB, id: String) -> Color:
	if content.appearance.hair_colours.has(id):
		return (content.appearance.hair_colours[id] as ColorOption).color
	return ViewConfig.UNKNOWN_ID_COLOR


static func _clothing_color(content: ContentDB, id: String) -> Color:
	if content.clothing_colours.has(id):
		return (content.clothing_colours[id] as ColorOption).color
	return ViewConfig.UNKNOWN_ID_COLOR


## A filled disc segment (e.g. the cap of hair over the top of the head).
static func _fan(canvas: CanvasItem, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var steps: int = 16
	for i: int in range(steps + 1):
		var angle: float = lerpf(from_angle, to_angle, float(i) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, color)
