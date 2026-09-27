class_name ObjectsView2D
extends Node2D
## Holds one ObjectView2D per WorldObject. Rebuilds on load; follows sim events
## afterwards. Added after WorldView2D and before PeopleView2D so objects draw
## under people.

var _views: Dictionary[int, ObjectView2D] = {}


func _ready() -> void:
	Session.game_loaded.connect(rebuild)
	Session.sim_event.connect(_on_sim_event)


func rebuild() -> void:
	for view: ObjectView2D in _views.values():
		view.queue_free()
	_views.clear()
	if Session.sim == null:
		return
	for id: int in Session.sim.world.objects:
		_add(id)


func _on_sim_event(event: Dictionary) -> void:
	var data: Dictionary = event["data"]
	match event["type"]:
		&"object_added":
			_add(int(data["object_id"]))
		&"object_removed":
			var id: int = int(data["object_id"])
			if _views.has(id):
				_views[id].queue_free()
				_views.erase(id)


func _add(object_id: int) -> void:
	if _views.has(object_id):
		return
	var view := ObjectView2D.new()
	view.object_id = object_id
	add_child(view)
	_views[object_id] = view
