class_name ObjectView2D
extends Node2D
## Draws one world object: its sprite from the active art set (WorldView2D.art), or else a
## placeholder (a coloured block over its footprint with a short label), plus a dot on each
## use slot while the F3 debug overlay is open.
## The node stays at the origin and draws with absolute cell coordinates, so objects
## (which never move) need no per-frame repositioning. Visibility follows
## Session.viewed_level; slot dots follow the static show_slots flag.

## True while the F3 debug overlay is visible: use-slot dots are drawn. A static on
## this view (not Session state) so the ticket stays inside game/main.gd plus these
## two view files; game/main.gd syncs it from the overlay every frame.
static var show_slots: bool = false

const LABEL_FONT_SIZE: int = 8
const SLOT_DOT_OUTER: float = 3.0
const SLOT_DOT_INNER: float = 2.0
const SLOT_DOT_LIGHT: Color = Color(1.0, 0.96, 0.65)

var object_id: int = 0
var _last_show_slots: bool = false


## Up to 3 characters from the last word of a display name ("Double bed" -> "Bed").
static func short_label(display_name: String) -> String:
	var trimmed: String = display_name.strip_edges()
	if trimmed.is_empty():
		return ""
	var parts: PackedStringArray = trimmed.split(" ", false)
	var word: String = parts[parts.size() - 1]
	var short: String = word.substr(0, mini(3, word.length()))
	return short.substr(0, 1).to_upper() + short.substr(1)


## Readable label colour for a placeholder fill: white on dark fills, near-black on
## light ones (e.g. white on the dark TV, dark on the pale fridge).
static func label_color(bg: Color) -> Color:
	if bg.get_luminance() < 0.5:
		return Color.WHITE
	return ViewConfig.OUTLINE_COLOR


## Pixel rect covering absolute footprint cells.
static func footprint_rect(cells: Array[Vector3i], px: int) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var min_x: int = cells[0].x
	var min_y: int = cells[0].y
	var max_x: int = cells[0].x
	var max_y: int = cells[0].y
	for cell: Vector3i in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2(float(min_x * px), float(min_y * px), float((max_x - min_x + 1) * px), float((max_y - min_y + 1) * px))


## Where a sprite of `sprite_size` pixels draws for a footprint: its bottom edge on the
## footprint's bottom edge, centred horizontally (whole pixels), so tall sprites rise above.
static func sprite_rect(footprint: Rect2, sprite_size: Vector2i) -> Rect2:
	var x: float = footprint.position.x + floorf((footprint.size.x - float(sprite_size.x)) / 2.0)
	return Rect2(x, footprint.end.y - float(sprite_size.y), float(sprite_size.x), float(sprite_size.y))


func _process(_delta: float) -> void:
	if Session.sim == null:
		visible = false
		return
	var obj: WorldObject = Session.sim.world.get_object(object_id)
	visible = obj != null and obj.origin.z == Session.viewed_level
	if show_slots != _last_show_slots:
		_last_show_slots = show_slots
		queue_redraw()


func _draw() -> void:
	if Session.sim == null:
		return
	var obj: WorldObject = Session.sim.world.get_object(object_id)
	if obj == null:
		return
	var def: ObjectDef = Session.content.object_def(obj.def_id)
	if def == null:
		return
	var cells: Array[Vector3i] = obj.cells(Session.content)
	if cells.is_empty():
		return
	var px: int = ViewConfig.TILE_PX
	var rect: Rect2 = footprint_rect(cells, px)
	var sprite: Dictionary = WorldView2D.art.object_sprite(obj.def_id, obj.rotation)
	if sprite.is_empty():
		_draw_placeholder(rect, def)
	else:
		var region: Rect2i = sprite["region"]
		draw_texture_rect_region(sprite["texture"], sprite_rect(rect, region.size), Rect2(region))
	if show_slots:
		for i: int in obj.slot_count(Session.content):
			var slot_cell: Vector3i = obj.slot_cell(Session.content, i)
			var dot: Vector2 = (Vector2(slot_cell.x, slot_cell.y) + Vector2(0.5, 0.5)) * float(px)
			draw_circle(dot, SLOT_DOT_OUTER, ViewConfig.OUTLINE_COLOR)
			draw_circle(dot, SLOT_DOT_INNER, SLOT_DOT_LIGHT)


func _draw_placeholder(rect: Rect2, def: ObjectDef) -> void:
	draw_rect(rect, def.debug_color, true)
	draw_rect(rect, def.debug_color.darkened(0.35), false, 1.0)
	var label: String = short_label(def.name)
	if not label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var center: Vector2 = rect.get_center()
		var baseline: float = center.y + (font.get_ascent(LABEL_FONT_SIZE) - font.get_descent(LABEL_FONT_SIZE)) / 2.0
		draw_string(font, Vector2(center.x - text_size.x / 2.0, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE, label_color(def.debug_color))
