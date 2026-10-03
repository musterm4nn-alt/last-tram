class_name DepthLayer2D
extends Node2D
## Holds the objects and the people in one y-sorted layer, so in the 3/4 view whatever stands
## lower on the screen draws in front: a person north of a wardrobe is hidden behind it, a
## person south of it stands in front. Object views sit on their footprint's bottom edge,
## person views on their feet and roofs on their building's lowest edge, so their positions
## are their depth.

var objects: ObjectsView2D
var people: PeopleView2D
## Roofs of closed buildings (T-0086), sorted with the rest.
var roofs: RoofsView2D


func _init() -> void:
	name = "Depth"
	y_sort_enabled = true
	objects = ObjectsView2D.new()
	add_child(objects)
	people = PeopleView2D.new()
	add_child(people)
	roofs = RoofsView2D.new()
	add_child(roofs)
