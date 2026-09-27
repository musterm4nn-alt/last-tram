class_name Command
extends RefCounted
## A request to change the sim, usually from player input. Commands are the ONLY way
## code outside sim/ may change sim state. Sim.submit() queues them; they are applied
## in order at the start of the next step. Invalid commands are ignored in apply().
##
## Every subclass must:
##   - live in sim/commands/, have a class_name, and an _init() whose args all have defaults
##   - return a unique type_id() and be listed in CommandRegistry.create()
##   - save all its fields in to_dict() and restore them in load_dict()
## (tests/sim/test_commands.gd checks all of this.)


func type_id() -> String:
	return ""


func apply(_sim: Sim) -> void:
	pass


func to_dict() -> Dictionary:
	return {}


func load_dict(_d: Dictionary) -> void:
	pass
