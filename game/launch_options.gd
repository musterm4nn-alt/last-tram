class_name LaunchOptions
extends RefCounted
## Command-line options for tools/run.sh and tools/screenshot.sh (everything main.gd
## understands). Tools start straight into the game; the menu shows only when no
## quickstart option is given (see skip_menu()).

## walk_to when --walk-to was not given.
const NO_CELL: Vector2i = Vector2i(-1, -1)

var seed_value: int = 1
var seed_given: bool = false
var load_path: String = ""
var advance_minutes: int = 0
var walk: Vector2 = Vector2.ZERO
var debug: bool = false
var zoom: int = -1
var screenshot_path: String = ""
var screenshot_frames: int = 20
var random_character: bool = false
var quickstart: bool = false
var menu: bool = false
## "" or a screen to open directly: "creator" (or "name") and "load" (main menu screens),
## "pause" (the Esc menu, after the quick start).
var screen: String = ""
## The creator's tab to show (--creator-tab=body); "" = the first.
var creator_tab: String = ""
## Start the creator from CharacterSpec.random with this seed (--creator-seed=7); -1 = no.
var creator_seed: int = -1
## Start in command mode (--command).
var command_mode: bool = false
## Walk the player to this cell at the start (--walk-to=X,Y); NO_CELL = none.
var walk_to: Vector2i = NO_CELL
## Open the interaction menu on the first object with this def id (--interact=fridge).
var interact: String = ""
## Actions to queue at the start (--queue=fridge:grab_snack,tv:watch_tv): [def_id, interaction_id].
var queue: Array[PackedStringArray] = []


## Parses "--seed=5 --debug" style arguments (unknown ones are ignored).
static func parse(args: PackedStringArray) -> LaunchOptions:
	var out := LaunchOptions.new()
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var key := arg.substr(2)
		var value := ""
		var eq := key.find("=")
		if eq >= 0:
			value = key.substr(eq + 1)
			key = key.substr(0, eq)
		match key:
			"seed":
				out.seed_value = value.to_int()
				out.seed_given = true
			"load":
				out.load_path = value
			"advance":
				out.advance_minutes = value.to_int()
			"walk":
				out.walk = _parse_walk(value)
			"debug":
				out.debug = true
			"zoom":
				out.zoom = value.to_int()
			"screenshot":
				out.screenshot_path = value
			"frames":
				out.screenshot_frames = value.to_int()
			"random-character":
				out.random_character = true
			"quickstart":
				out.quickstart = true
			"menu":
				out.menu = true
			"screen":
				out.screen = value
			"creator-tab":
				out.creator_tab = value
			"creator-seed":
				out.creator_seed = value.to_int()
			"command":
				out.command_mode = true
			"walk-to":
				var cell := _parse_walk(value)
				out.walk_to = Vector2i(int(cell.x), int(cell.y))
			"interact":
				out.interact = value
			"queue":
				for pair: String in value.split(",", false):
					var parts := pair.split(":")
					if parts.size() == 2:
						out.queue.append(parts)
	return out


## True when the game should start immediately, without the menu.
func skip_menu() -> bool:
	if menu or screen == "name" or screen == "creator" or screen == "load":
		return false
	return quickstart or not screenshot_path.is_empty() or not load_path.is_empty() or advance_minutes > 0 \
			or walk != Vector2.ZERO or random_character or seed_given or command_mode or walk_to != NO_CELL \
			or not interact.is_empty() or not queue.is_empty()


static func _parse_walk(value: String) -> Vector2:
	var parts := value.split(",")
	if parts.size() == 2:
		return Vector2(parts[0].to_float(), parts[1].to_float())
	return Vector2.ZERO
