class_name Autonomy
extends RefCounted
## What a person could do now, and picking one of the best (utility AI, D24): every
## interaction on an object within reach is scored by Utility.need_score minus the walk,
## then one of the best few is picked with a little randomness. Static, no state.

## Each step of distance to a slot costs this much score.
const TRAVEL_COST_PER_CELL: float = 0.1
## Options scoring below this are ignored (the person is content and does nothing).
const MIN_SCORE: float = 3.0
## Random noise added to each score before picking, 0..NOISE.
const NOISE: float = 1.0
## How many of the best options the final pick chooses among.
const TOP_N: int = 3
## Objects whose origin is within this many cells (Chebyshev distance, same level) count.
## M2 replaces this with the person's lot and its access rules.
const SEARCH_RADIUS: int = 12


## Every option the person could take now, in object id order, then content order:
## [{"object_id": int, "interaction_id": String, "score": float, "cells": int}].
## `cells` is the path length to the object's nearest free, walkable slot (0 when the person
## stands on one); objects with no reachable free slot give no options.
static func candidates(sim: Sim, person: Person) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var here := person.cell()
	var ids: Array = sim.world.objects.keys()
	ids.sort()
	for id: int in ids:
		var obj: WorldObject = sim.world.objects[id]
		if obj.origin.z != here.z:
			continue
		if maxi(absi(obj.origin.x - here.x), absi(obj.origin.y - here.y)) > SEARCH_RADIUS:
			continue
		var cells := _cells_to_free_slot(sim, person, obj)
		if cells < 0:
			continue
		for def: InteractionDef in Interactions.offered_by(sim, id):
			out.append({
				"object_id": id,
				"interaction_id": def.id,
				"score": Utility.need_score(person, def, sim.content) - TRAVEL_COST_PER_CELL * cells,
				"cells": cells,
			})
	return out


## Adds rng.randf() × NOISE to each score (in list order), drops options below MIN_SCORE,
## keeps the TOP_N best (ties: earlier in the list), and picks one with probability
## proportional to its noisy score. Returns {} when nothing is left. Uses `rng` only.
static func choose(options: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var kept: Array[Dictionary] = []
	for index: int in options.size():
		var option := options[index].duplicate()
		option["score"] = float(option["score"]) + rng.randf() * NOISE
		option["_order"] = index
		if float(option["score"]) >= MIN_SCORE:
			kept.append(option)
	if kept.is_empty():
		return {}
	kept.sort_custom(_better)
	kept = kept.slice(0, TOP_N)
	var total := 0.0
	for option: Dictionary in kept:
		total += float(option["score"])
	var pick := rng.randf() * total
	var chosen: Dictionary = kept[kept.size() - 1]
	for option: Dictionary in kept:
		pick -= float(option["score"])
		if pick <= 0.0:
			chosen = option
			break
	chosen.erase("_order")
	return chosen


## Sort order for choose(): higher score first, then earlier in the list.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if float(a["score"]) != float(b["score"]):
		return float(a["score"]) > float(b["score"])
	return int(a["_order"]) < int(b["_order"])


## Path length to the object's nearest free, walkable slot: 0 when the person stands on one,
## -1 when none can be reached.
static func _cells_to_free_slot(sim: Sim, person: Person, obj: WorldObject) -> int:
	var here := person.cell()
	var best := -1
	for index: int in obj.slot_count(sim.content):
		if Interactions.slot_taken(sim, obj.id, index, person.id):
			continue
		var cell := obj.slot_cell(sim.content, index)
		if not sim.world.grid.is_walkable(cell):
			continue
		if cell == here:
			return 0
		var path := sim.nav.find_path(here, cell)
		if path.is_empty():
			continue
		if best < 0 or path.size() < best:
			best = path.size()
	return best
