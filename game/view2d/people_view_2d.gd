class_name PeopleView2D
extends Node2D
## Holds one PersonView2D per Person. Rebuilds on load; follows sim events afterwards.

var _views: Dictionary[int, PersonView2D] = {}


func _ready() -> void:
	y_sort_enabled = true
	Session.game_loaded.connect(rebuild)
	Session.sim_event.connect(_on_sim_event)


func rebuild() -> void:
	for view: PersonView2D in _views.values():
		view.queue_free()
	_views.clear()
	for person_id: int in Session.sim.world.people:
		_add(person_id)


func _on_sim_event(event: Dictionary) -> void:
	var data: Dictionary = event["data"]
	match event["type"]:
		&"person_spawned":
			_add(int(data["person_id"]))
		&"person_removed":
			var id := int(data["person_id"])
			if _views.has(id):
				_views[id].queue_free()
				_views.erase(id)


func _add(person_id: int) -> void:
	if _views.has(person_id):
		return
	var view := PersonView2D.new()
	view.person_id = person_id
	add_child(view)
	_views[person_id] = view
