class_name World
extends RefCounted
## All mutable state of the town: the grid and every entity in it.
## Entities reference each other by integer id only (never by object), and ids are unique
## across all entity kinds.

var content: ContentDB
var grid: WorldGrid
var people: Dictionary[int, Person] = {}
## Id of the person the player controls (0 = none).
var player_id: int = 0

var _next_id: int = 1


func _init(p_content: ContentDB, p_grid: WorldGrid) -> void:
	content = p_content
	grid = p_grid


func new_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func get_person(id: int) -> Person:
	return people.get(id)


func player() -> Person:
	return get_person(player_id)


## Adds a person. Give them an id from new_id() first.
func add_person(person: Person) -> void:
	people[person.id] = person


func to_dict() -> Dictionary:
	var people_out: Array[Dictionary] = []
	for person: Person in people.values():
		people_out.append(person.to_dict())
	return {
		"next_id": _next_id,
		"player_id": player_id,
		"grid": grid.to_dict(),
		"people": people_out,
	}


static func from_dict(d: Dictionary, content: ContentDB) -> World:
	var world := World.new(content, WorldGrid.from_dict(d["grid"], content))
	world._next_id = int(d["next_id"])
	world.player_id = int(d["player_id"])
	for entry: Variant in d["people"]:
		world.add_person(Person.from_dict(entry))
	return world
