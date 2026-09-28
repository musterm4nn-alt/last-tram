class_name InputActions
extends RefCounted
## All input actions, registered in code at startup (keeps project.godot free of
## hand-edited input blobs). To add a binding, add a line to KEYS or MOUSE_BUTTONS.
## Keys are physical positions (US layout names), so WASD works on QWERTZ/AZERTY too.

const KEYS: Dictionary = {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"pause": [KEY_SPACE],
	"speed_1": [KEY_1],
	"speed_2": [KEY_2],
	"speed_3": [KEY_3],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"toggle_debug": [KEY_F3],
	"quicksave": [KEY_F5],
	"quickload": [KEY_F8],
	"toggle_command_mode": [KEY_TAB],
	"interact": [KEY_E],
	"menu": [KEY_ESCAPE],
	"bug_report": [KEY_F9],
}

const MOUSE_BUTTONS: Dictionary = {
	"zoom_in": [MOUSE_BUTTON_WHEEL_UP],
	"zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
	"walk_click": [MOUSE_BUTTON_LEFT],
	"pan_drag": [MOUSE_BUTTON_RIGHT],
}


static func register() -> void:
	for action: String in KEYS:
		_ensure(action)
		for key: int in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)
	for action: String in MOUSE_BUTTONS:
		_ensure(action)
		for button: int in MOUSE_BUTTONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button as MouseButton
			InputMap.action_add_event(action, event)


static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
