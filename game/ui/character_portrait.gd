class_name CharacterPortrait
extends Control
## A front-facing head-and-shoulders portrait ("paper doll") drawn from appearance and outfit
## data: skin, hair style and colour, eyes, facial hair, features, and the top, outer, neck,
## face and head items. Placeholder shapes until the art gate, sized from the control's size
## so the same drawing works large (creator) and small (look gallery). Hair never covers
## the face: the geometry comes from head_rect(), face_rect() and hair_front_rects().

const OUTLINE: Color = Color(0, 0, 0, 0.35)
const MOUTH_COLOR: Color = Color("#6b3a3a")
const PUPIL_COLOR: Color = Color("#1b1b1b")

var _appearance: Appearance
var _outfit: Outfit


func _init() -> void:
	custom_minimum_size = Vector2(200, 240)


## Shows this look (call again after every change). Not show(): that is Control's own.
func show_look(appearance: Appearance, outfit: Outfit) -> void:
	_appearance = appearance
	_outfit = outfit
	queue_redraw()


## The head's bounding box for a portrait of this size.
static func head_rect(area: Vector2) -> Rect2:
	var head_size := Vector2(area.x * 0.4, area.y * 0.4)
	return Rect2(Vector2(area.x * 0.5 - head_size.x / 2.0, area.y * 0.14), head_size)


## The face (eyes, nose, mouth) inside the head; hair must never cover it.
static func face_rect(head: Rect2) -> Rect2:
	return Rect2(head.position + Vector2(head.size.x * 0.2, head.size.y * 0.35),
		Vector2(head.size.x * 0.6, head.size.y * 0.5))


## The rectangles each hair shape is drawn inside, in front of the face layer (hair drawn
## behind the head, like the length of "long", is not included). Shapes come from
## ViewConfig.HAIR_SHAPE: none, thin, cap, sides, long, tail, bun, afro, mohawk.
static func hair_front_rects(shape: String, head: Rect2) -> Array[Rect2]:
	var x := head.position.x
	var y := head.position.y
	var w := head.size.x
	var h := head.size.y
	var cap := Rect2(x - 0.04 * w, y - 0.06 * h, 1.08 * w, 0.33 * h)
	var left_side := Rect2(x - 0.08 * w, y + 0.1 * h, 0.23 * w, 0.8 * h)
	var right_side := Rect2(x + 0.85 * w, y + 0.1 * h, 0.23 * w, 0.8 * h)
	match shape:
		"none":
			return []
		"thin":
			return [Rect2(x + 0.05 * w, y, 0.9 * w, 0.2 * h)]
		"sides", "long":
			return [cap, left_side, right_side]
		"bun":
			return [cap, Rect2(x + 0.3 * w, y - 0.28 * h, 0.4 * w, 0.3 * h)]
		"afro":
			return [Rect2(x - 0.2 * w, y - 0.28 * h, 1.4 * w, 0.55 * h)]
		"mohawk":
			return [Rect2(x + 0.4 * w, y - 0.22 * h, 0.2 * w, 0.47 * h)]
	# "cap" and "tail" (the tail itself hangs behind the head).
	return [cap]


func _draw() -> void:
	if _appearance == null or _outfit == null or Session.content == null:
		return
	var content := Session.content
	var head := head_rect(size)
	var face := face_rect(head)
	var skin := PersonDrawer2D.skin_color(content, _appearance.skin_tone)
	var hair := PersonDrawer2D.hair_color(content, _appearance.hair_colour)
	var shape := str(ViewConfig.HAIR_SHAPE.get(_appearance.hair_style, "cap"))
	_draw_hair_behind(shape, head, hair)
	_draw_body(content, head, skin)
	_rounded(head, skin, head.size.x * 0.45)
	_draw_face(content, face, hair)
	for rect: Rect2 in hair_front_rects(shape, head):
		_rounded(rect, hair, minf(rect.size.x, rect.size.y) * 0.45)
	_draw_head_items(content, head, face)


func _draw_hair_behind(shape: String, head: Rect2, hair: Color) -> void:
	var x := head.position.x
	var y := head.position.y
	var w := head.size.x
	var h := head.size.y
	match shape:
		"long":
			_rounded(Rect2(x - 0.12 * w, y + 0.1 * h, 1.24 * w, 1.3 * h), hair, 0.3 * w)
		"tail":
			_rounded(Rect2(x + 0.8 * w, y + 0.2 * h, 0.3 * w, 0.9 * h), hair, 0.14 * w)
		"afro":
			_rounded(Rect2(x - 0.25 * w, y - 0.25 * h, 1.5 * w, 1.1 * h), hair, 0.6 * w)


func _draw_body(content: ContentDB, head: Rect2, skin: Color) -> void:
	var width_cells: float = float(ViewConfig.BUILD_WIDTH.get(_appearance.build, ViewConfig.DEFAULT_BUILD_WIDTH))
	var shoulders := size.x * width_cells * 1.4
	var top_y := head.end.y + head.size.y * 0.05
	var body := Rect2(Vector2(size.x / 2.0 - shoulders / 2.0, top_y + head.size.y * 0.12), Vector2(shoulders, size.y - top_y))
	# Neck, then the top, then an open outer layer over it.
	draw_rect(Rect2(Vector2(size.x / 2.0 - head.size.x * 0.16, head.end.y - head.size.y * 0.1), Vector2(head.size.x * 0.32, head.size.y * 0.3)), skin)
	_rounded(body, PersonDrawer2D.worn_color(content, _outfit, "top"), shoulders * 0.18)
	var outer := _outfit.get_item("outer")
	if outer != null:
		var colour := PersonDrawer2D.worn_color(content, _outfit, "outer")
		var panel := Vector2(shoulders * 0.36, body.size.y)
		_rounded(Rect2(body.position, panel), colour, shoulders * 0.12)
		_rounded(Rect2(Vector2(body.end.x - panel.x, body.position.y), panel), colour, shoulders * 0.12)
	var neck_item := _outfit.get_item("neck")
	if neck_item != null:
		_rounded(Rect2(Vector2(size.x / 2.0 - head.size.x * 0.3, body.position.y - head.size.y * 0.08), Vector2(head.size.x * 0.6, head.size.y * 0.16)),
			PersonDrawer2D.worn_color(content, _outfit, "neck"), head.size.y * 0.06)


func _draw_face(content: ContentDB, face: Rect2, hair: Color) -> void:
	var eye_r := face.size.x * 0.09
	var eye_y := face.position.y + face.size.y * 0.25
	var eyes: Array[Vector2] = [
		Vector2(face.position.x + face.size.x * 0.25, eye_y),
		Vector2(face.position.x + face.size.x * 0.75, eye_y),
	]
	var eye_colour := PersonDrawer2D.eye_color(content, _appearance.eye_colour)
	for eye: Vector2 in eyes:
		draw_circle(eye, eye_r, Color.WHITE)
		draw_circle(eye, eye_r * 0.65, eye_colour)
		draw_circle(eye, eye_r * 0.3, PUPIL_COLOR)
	var mouth_y := face.position.y + face.size.y * 0.78
	draw_line(Vector2(face.position.x + face.size.x * 0.35, mouth_y), Vector2(face.position.x + face.size.x * 0.65, mouth_y), MOUTH_COLOR, maxf(1.0, face.size.y * 0.04))
	_draw_facial_hair(face, hair.darkened(0.2), mouth_y)
	if _appearance.features.has("freckles"):
		for i: int in 6:
			var side := -1.0 if i < 3 else 1.0
			var dot := Vector2(face.get_center().x + side * face.size.x * (0.2 + 0.07 * (i % 3)), eye_y + face.size.y * (0.22 + 0.06 * (i % 2)))
			draw_circle(dot, maxf(0.8, face.size.x * 0.02), Color("#8a4b2d"))
	if _appearance.features.has("beauty_mark"):
		draw_circle(Vector2(face.position.x + face.size.x * 0.8, mouth_y - face.size.y * 0.12), maxf(1.0, face.size.x * 0.025), PUPIL_COLOR)
	if _appearance.features.has("glasses"):
		for eye: Vector2 in eyes:
			draw_arc(eye, eye_r * 1.6, 0.0, TAU, 20, PUPIL_COLOR, maxf(1.0, eye_r * 0.3))
		draw_line(eyes[0] + Vector2(eye_r * 1.6, 0), eyes[1] - Vector2(eye_r * 1.6, 0), PUPIL_COLOR, maxf(1.0, eye_r * 0.3))


func _draw_facial_hair(face: Rect2, colour: Color, mouth_y: float) -> void:
	var fx := face.position.x
	var fw := face.size.x
	var fh := face.size.y
	match _appearance.facial_hair:
		"stubble":
			var tint := colour
			tint.a = 0.18
			_rounded(Rect2(fx + fw * 0.05, mouth_y + fh * 0.06, fw * 0.9, fh * 0.26), tint, fw * 0.3, false)
		"moustache":
			_rounded(Rect2(fx + fw * 0.28, mouth_y - fh * 0.14, fw * 0.44, fh * 0.1), colour, fh * 0.05)
		"goatee":
			_rounded(Rect2(fx + fw * 0.4, mouth_y + fh * 0.06, fw * 0.2, fh * 0.2), colour, fw * 0.08)
		"short_beard":
			_rounded(Rect2(fx, mouth_y + fh * 0.04, fw, fh * 0.26), colour, fw * 0.25)
			_rounded(Rect2(fx + fw * 0.28, mouth_y - fh * 0.14, fw * 0.44, fh * 0.1), colour, fh * 0.05)
		"full_beard":
			_rounded(Rect2(fx - fw * 0.08, mouth_y - fh * 0.3, fw * 1.16, fh * 0.62), colour, fw * 0.35)
			draw_line(Vector2(fx + fw * 0.35, mouth_y), Vector2(fx + fw * 0.65, mouth_y), MOUTH_COLOR, maxf(1.0, fh * 0.04))


func _draw_head_items(content: ContentDB, head: Rect2, face: Rect2) -> void:
	var worn := _outfit.get_item("head")
	if worn != null:
		var colour := PersonDrawer2D.worn_color(content, _outfit, "head")
		_rounded(Rect2(head.position + Vector2(-head.size.x * 0.05, -head.size.y * 0.08), Vector2(head.size.x * 1.1, head.size.y * 0.34)), colour, head.size.x * 0.3)
		if worn.clothing_id == "cap":
			_rounded(Rect2(Vector2(head.position.x + head.size.x * 0.1, head.position.y + head.size.y * 0.2), Vector2(head.size.x * 1.05, head.size.y * 0.08)), colour.darkened(0.2), head.size.y * 0.03)
	var face_item := _outfit.get_item("face")
	if face_item != null:
		var eye_y := face.position.y + face.size.y * 0.25
		_rounded(Rect2(Vector2(face.position.x - face.size.x * 0.05, eye_y - face.size.y * 0.12), Vector2(face.size.x * 1.1, face.size.y * 0.24)),
			PersonDrawer2D.worn_color(content, _outfit, "face").darkened(0.3), face.size.y * 0.08)


## A filled rounded rectangle, with a faint outline unless `outlined` is false.
func _rounded(rect: Rect2, colour: Color, radius: float, outlined: bool = true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(int(maxf(0.0, radius)))
	if outlined:
		style.set_border_width_all(1)
		style.border_color = OUTLINE
	draw_style_box(style, rect)
