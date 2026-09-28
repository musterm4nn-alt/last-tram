class_name InteractionMenu
extends PopupMenu
## The small menu of what an object offers ("Grab a snack", "Cook a meal"...). Opened by a
## click on an object in command mode or by E in direct mode (PlayerController); choosing an
## entry queues it for the player with a QueueInteractionCommand. PopupMenu closes itself on
## a choice, on Esc and on a click outside.

## Shown when an object offers nothing.
const NOTHING: String = "Nothing to do here"

var _object_id: int = 0
## What each item id stands for: the interaction ids, in offered_by() order.
var _offered: Array[String] = []


func _init() -> void:
	id_pressed.connect(_on_id_pressed)


## Fills the menu for this object (no popup; tests call this): a header with the object's
## name, then one item per offered interaction (item id = its index in offered_by()), or
## one disabled item "Nothing to do here".
func prepare(object_id: int) -> void:
	clear()
	_object_id = object_id
	_offered.clear()
	var labels := entries(Session.sim, object_id)
	if labels.is_empty():
		return
	add_separator(labels[0])
	for def: InteractionDef in Interactions.offered_by(Session.sim, object_id):
		add_item(def.name, _offered.size())
		_offered.append(def.id)
	if _offered.is_empty():
		add_item(NOTHING, 0)
		set_item_disabled(item_count - 1, true)


## prepare(), then pops up at `screen_pos`.
func open_for(object_id: int, screen_pos: Vector2) -> void:
	prepare(object_id)
	popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))


## The labels prepare() shows, header first (pure, for tests). [] for an unknown object.
static func entries(sim: Sim, object_id: int) -> Array[String]:
	var out: Array[String] = []
	var obj := sim.world.get_object(object_id)
	if obj == null:
		return out
	var def := sim.content.object_def(obj.def_id)
	out.append(def.name if def != null else obj.def_id)
	var offered := Interactions.offered_by(sim, object_id)
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
