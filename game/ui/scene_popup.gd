class_name ScenePopup
extends CanvasLayer
## Shows requested scenes (T-0043): one page at a time with Next, then Continue. Pauses the
## game while open and restores the speed after, like the Esc menu; further requests wait in
## a queue. View only: what was shown never matters to the sim.

## True while a scene is shown (the rest of the game ignores input then).
var is_open: bool = false
## Requests still to show ({scene_id, actor_id, target_id, place_id}).
var queue: Array[Dictionary] = []
## The current page index.
var page: int = 0

var _speed_before: int = 1
var _request: Dictionary = {}
var _text: Label
var _button: Button


func _init() -> void:
	layer = 16
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(520, 0)
	_text.add_theme_font_size_override("font_size", 18)
	box.add_child(_text)
	_button = Button.new()
	_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button.custom_minimum_size = Vector2(140, 36)
	_button.pressed.connect(next_page)
	box.add_child(_button)
	visible = false


func _ready() -> void:
	Session.sim_event.connect(func(event: Dictionary) -> void:
		if event.get("type") == &"scene_requested":
			request(event.get("data", {})))
	Session.game_loaded.connect(func() -> void:
		queue.clear()
		if is_open:
			_close())


## Shows `scene_request` now, or after the ones before it. Unknown scenes are ignored.
func request(scene_request: Dictionary) -> void:
	if Session.content.scenes.get(String(scene_request.get("scene_id", ""))) == null:
		return
	queue.append(scene_request)
	if not is_open:
		_open_next()


## Next page, or the next queued scene, or closes.
func next_page() -> void:
	var scene: SceneDef = Session.content.scenes.get(String(_request.get("scene_id", "")))
	page += 1
	if scene != null and page < scene.pages.size():
		_show_page()
	elif not queue.is_empty():
		_open_next(false)
	else:
		_close()


## The current page's text, filled in.
func text() -> String:
	return _text.text


func _open_next(pause: bool = true) -> void:
	_request = queue.pop_front()
	page = 0
	if pause and not is_open:
		_speed_before = Session.speed
		Session.set_speed(0)
	is_open = true
	visible = true
	_show_page()


func _show_page() -> void:
	var scene: SceneDef = Session.content.scenes[String(_request["scene_id"])]
	_text.text = SceneText.fill(scene.pages[page], _request, Session.sim)
	_button.text = "Next" if page + 1 < scene.pages.size() or not queue.is_empty() else "Continue"
	if _button.is_inside_tree():
		_button.grab_focus()


func _close() -> void:
	is_open = false
	visible = false
	_request = {}
	Session.set_speed(_speed_before)
