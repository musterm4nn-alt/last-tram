class_name InteractionMenu
extends PopupMenu
## The small menu of what an object or a person offers ("Grab a snack", "Chat"...). Opened by
## a click on an object or person in command mode or by E in direct mode (PlayerController);
## choosing an entry queues it for the player with a QueueInteractionCommand. PopupMenu closes itself on
## a choice, on Esc and on a click outside.

## Shown when an object offers nothing.
const NOTHING: String = "Nothing to do here"

var _object_id: int = 0
## What each item id stands for: the interaction ids, in offered_by() order.
var _offered: Array[String] = []


func _init() -> void:
	id_pressed.connect(_on_id_pressed)


## Fills the menu for this object or person (no popup; tests call this): a header with its
## name, then one item per offered interaction (item id = its index in options()), or one
## disabled item "Nothing to do here".
func prepare(object_id: int) -> void:
	clear()
	_object_id = object_id
	_offered.clear()
	var labels := entries(Session.sim, object_id)
	if labels.is_empty():
		return
	add_separator(labels[0])
	for def: InteractionDef in options(Session.sim, object_id):
		add_item(def.name, _offered.size())
		_offered.append(def.id)
	if _offered.is_empty():
		add_item(NOTHING, 0)
		set_item_disabled(item_count - 1, true)


## prepare(), then pops up at `screen_pos`.
func open_for(object_id: int, screen_pos: Vector2) -> void:
	prepare(object_id)
	popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))


## What the player can do with this object or person (T-0053), in content order.
static func options(sim: Sim, target_id: int) -> Array[InteractionDef]:
	if sim.world.get_person(target_id) != null:
		return Interactions.offered_by_person(sim, sim.world.player_id, target_id)
	return Interactions.offered_by(sim, target_id)


## The labels prepare() shows, header first (pure, for tests). [] for an unknown target.
static func entries(sim: Sim, object_id: int) -> Array[String]:
	var out: Array[String] = []
	var person := sim.world.get_person(object_id)
	var obj := sim.world.get_object(object_id)
	if person != null:
		out.append(person.full_name())
	elif obj != null:
		var def := sim.content.object_def(obj.def_id)
		out.append(def.name if def != null else obj.def_id)
	else:
		return out
	var offered := options(sim, object_id)
	for interaction: InteractionDef in offered:
		out.append(interaction.name)
	if offered.is_empty():
		out.append(NOTHING)
	return out


func _on_id_pressed(id: int) -> void:
	if Session.sim == null or id < 0 or id >= _offered.size():
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	Session.submit(QueueInteractionCommand.new(player.id, _offered[id], _object_id))
