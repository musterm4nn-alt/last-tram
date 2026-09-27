class_name CommandRegistry
extends RefCounted
## Turns commands into dictionaries and back, for saves, bug reports and replays.
## When you add a Command subclass, add a line to create().


static func create(type_id: String) -> Command:
	match type_id:
		"set_move_intent":
			return SetMoveIntentCommand.new()
	return null


static func encode(cmd: Command) -> Dictionary:
	var d := cmd.to_dict()
	d["type"] = cmd.type_id()
	return d


## Returns null if the type is unknown.
static func decode(d: Dictionary) -> Command:
	var cmd := create(String(d.get("type", "")))
	if cmd != null:
		cmd.load_dict(d)
	return cmd
