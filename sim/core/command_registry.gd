class_name CommandRegistry
extends RefCounted
## Turns commands into dictionaries and back, for saves, bug reports and replays.
## When you add a Command subclass, add a line to create().


static func create(type_id: String) -> Command:
	match type_id:
		"set_move_intent":
			return SetMoveIntentCommand.new()
		"walk_to":
			return WalkToCommand.new()
		"queue_interaction":
			return QueueInteractionCommand.new()
		"cancel_action":
			return CancelActionCommand.new()
		"set_free_will":
			return SetFreeWillCommand.new()
		"set_running":
			return SetRunningCommand.new()
		"set_tier_mode":
			return SetTierModeCommand.new()
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
