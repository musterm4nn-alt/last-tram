class_name FigurePreview
extends Control
## The character creator's live preview: the top-down figure four times, facing down,
## left, up and right, drawn with PersonDrawer2D (the same drawing the game uses).

## Pixels per cell for the preview figures.
const PREVIEW_PX: float = 96.0
const FACINGS: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
const VIEW_NAMES: PackedStringArray = ["Front", "Left", "Back", "Right"]
## A mid-grey floor, so black and white clothes both show.
const FLOOR_COLOR: Color = Color("#8e8f91")
const LABEL_COLOR: Color = Color(1, 1, 1, 0.7)

var _spec: CharacterSpec


func _init() -> void:
	custom_minimum_size = Vector2(FACINGS.size() * PREVIEW_PX * 1.1, 2.2 * PREVIEW_PX + 24)


## Shows this character (call again after every change).
func show_spec(spec: CharacterSpec) -> void:
	_spec = spec
	queue_redraw()


func _draw() -> void:
	if _spec == null or Session.content == null:
		return
	var floor := StyleBoxFlat.new()
	floor.bg_color = FLOOR_COLOR
	floor.set_corner_radius_all(6)
	draw_style_box(floor, Rect2(Vector2.ZERO, Vector2(size.x, 2.2 * PREVIEW_PX)))
	for index: int in FACINGS.size():
		# Feet near the bottom, one figure per column.
		var feet := Vector2((index + 0.5) * PREVIEW_PX * 1.1, 2.0 * PREVIEW_PX)
		draw_set_transform(feet)
		PersonDrawer2D.draw(self, Session.content, _spec.appearance, _spec.outfit, FACINGS[index], PREVIEW_PX, false)
	draw_set_transform(Vector2.ZERO)
	var column := PREVIEW_PX * 1.1
	for index: int in VIEW_NAMES.size():
		draw_string(ThemeDB.fallback_font, Vector2(index * column, 2.2 * PREVIEW_PX + 18), VIEW_NAMES[index],
			HORIZONTAL_ALIGNMENT_CENTER, column, 13, LABEL_COLOR)
