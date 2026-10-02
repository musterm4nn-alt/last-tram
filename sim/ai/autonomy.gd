class_name Autonomy
extends RefCounted
## What a person could do now, and picking one of the best (utility AI, D24): every
## interaction on an object within reach is scored by Utility.need_score minus the walk,
## then one of the best few is picked with a little randomness. Static, no state.

## Each step of distance to a slot costs this much score.
const TRAVEL_COST_PER_CELL: float = 0.1
## Options scoring below this are ignored (the person is content and does nothing).
const MIN_SCORE: float = 3.0
## How many of the nearest available people free will considers talking to (T-0039).
const PEOPLE_CONSIDERED: int = 3
## Random noise added to each score before picking, 0..NOISE.
const NOISE: float = 1.0
## How many of the best options the final pick chooses among.
const TOP_N: int = 3
## Objects whose origin is within this many cells (Chebyshev distance, same level) count,
## if the person may enter the object's lot (Lots.may_enter; objects on no lot are public).
## In the person's out window, objects offering an "out" interaction count anywhere (T-0052),
## and so do errands (T-0057): a grocery run while the home fridge is low, and food for sale
## while hungry with (almost) nothing at home.
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
	var going_out := Routines.going_out_time(sim, person)
	var far_defs := _outing_objects(sim) if going_out else {}
	far_defs.merge(_errand_objects(sim, person))
	for id: int in ids:
		var obj: WorldObject = sim.world.objects[id]
		var near := obj.origin.z == here.z and maxi(absi(obj.origin.x - here.x), absi(obj.origin.y - here.y)) <= SEARCH_RADIUS
		if not near and not far_defs.has(obj.def_id):
			continue
		var lot := Lots.lot_at(sim, obj.origin)
		if lot != null and not Lots.may_enter(sim, person, lot):
			continue
		var cells := cells_to_free_slot(sim, person, obj, not near)
		if cells < 0:
			continue
		for def: InteractionDef in Interactions.offered_by(sim, id):
			if not near and not (going_out and def.routine == "out") and not errand(sim, person, def):
				continue
			if def.adds_groceries > 0 and not restock_needed(sim, person):
				continue
			if not Requirements.check(sim, person, def, id).is_empty():
				continue
			out.append({
				"object_id": id,
				"interaction_id": def.id,
				"score": Utility.need_score(person, def, sim.content) * Routines.score_factor(sim, person, def)
					+ Routines.score_bonus(sim, person, def) - Utility.price_cost(person, def, sim.content)
					- TRAVEL_COST_PER_CELL * cells
					+ (sim.content.economy.restock_bonus if def.adds_groceries > 0 else 0.0)
					+ (sim.content.economy.cash_errand_score if def.cash_out > 0 and errand(sim, person, def) else 0.0),
				"cells": cells,
			})
	out.append_array(_person_options(sim, person))
	return out


## Social options (T-0039): every person-targeted interaction with each of the
## PEOPLE_CONSIDERED nearest available people within SEARCH_RADIUS on the same level whose
## spot the person may enter. "object_id" holds the other person's id; "cells" is the walk to
## them. Scored by need × routine factor + Social bias − travel.
static func _person_options(sim: Sim, person: Person) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var here := person.cell()
	var nearby: Array[Person] = []
	for other: Person in sim.world.people.values():
		if other.id == person.id or other.level != here.z:
			continue
		if maxi(absi(other.cell().x - here.x), absi(other.cell().y - here.y)) > SEARCH_RADIUS:
			continue
		if not Conversations.available(sim, other):
			continue
		var lot := Lots.lot_at(sim, other.cell())
		if lot != null and not Lots.may_enter(sim, person, lot):
			continue
		nearby.append(other)
	nearby.sort_custom(func(a: Person, b: Person) -> bool:
		var da := a.pos.distance_squared_to(person.pos)
		var db := b.pos.distance_squared_to(person.pos)
		return da < db if da != db else a.id < b.id)
	for other: Person in nearby.slice(0, PEOPLE_CONSIDERED):
		var cells := 0
		if not Conversations.adjacent(person, other):
			var path := sim.nav.find_path(here, other.cell())
			if path.is_empty():
				continue
			cells = path.size() - 1
		for def: InteractionDef in Interactions.offered_by_person(sim, person.id, other.id):
			out.append({
				"object_id": other.id,
				"interaction_id": def.id,
				"score": Utility.need_score(person, def, sim.content) * Routines.score_factor(sim, person, def)
					+ Utility.social_bias(person, other, def) + Routines.social_out_bonus(sim, person, def)
					- TRAVEL_COST_PER_CELL * cells,
				"cells": cells,
			})
	return out


## True for errands worth crossing town for (T-0057): a grocery run while the home stock is
## below restock_below, and food for sale (a price, advertises hunger) while hunger is below
## hungry_below and the home has fewer than 2 portions, and the ATM while the pocket holds
## less than pocket_money (T-0064 playtest: pockets ran empty; data/economy.json), and a bench
## to sleep on for someone with no home (T-0066).
static func errand(sim: Sim, person: Person, def: InteractionDef) -> bool:
	if def.homeless_only:
		return person.home_lot_id <= 0
	if def.adds_groceries > 0:
		return restock_needed(sim, person)
	if def.cash_out > 0:
		var pocket := sim.content.economy.pocket_money
		return person.wallet.cash < pocket and person.wallet.bank >= def.cash_out + pocket
	if def.price <= 0 or not def.advertise.has("hunger"):
		return false
	if float(person.needs.get("hunger", 100.0)) >= sim.content.economy.hungry_below:
		return false
	var home := Groceries.home_household(sim, person)
	return home == null or home.groceries < 2


## True while the person's home fridge holds fewer than restock_below portions.
static func restock_needed(sim: Sim, person: Person) -> bool:
	var home := Groceries.home_household(sim, person)
	return home != null and home.groceries < sim.content.economy.restock_below


## Object def ids offering an errand for this person now (see errand()).
static func _errand_objects(sim: Sim, person: Person) -> Dictionary:
	var out: Dictionary = {}
	for interaction: InteractionDef in sim.content.interactions.values():
		if interaction.target != "object" or not errand(sim, person, interaction):
			continue
		for def: ObjectDef in sim.content.objects.values():
			if Array(interaction.object_tags).any(func(tag: String) -> bool: return tag in def.tags):
				out[def.id] = true
	return out


## Object def ids offering at least one routine "out" interaction.
static func _outing_objects(sim: Sim) -> Dictionary:
	var out: Dictionary = {}
	for def: ObjectDef in sim.content.objects.values():
		for interaction: InteractionDef in sim.content.interactions.values():
			if interaction.routine == "out" and Array(interaction.object_tags).any(func(tag: String) -> bool: return tag in def.tags):
				out[def.id] = true
				break
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


## Path length to the object's nearest free, walkable customer slot (free will never works): 0 when the person stands on one,
## -1 when none can be reached. With `first_only` (far objects), the first reachable free slot
## stands in for the nearest, saving a route per slot.
static func cells_to_free_slot(sim: Sim, person: Person, obj: WorldObject, first_only: bool = false) -> int:
	var here := person.cell()
	var best := -1
	var def := sim.content.object_def(obj.def_id)
	for index: int in obj.slot_count(sim.content):
		if def.use_slots[index].role != "customer" or Interactions.slot_taken(sim, obj.id, index, person.id):
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
		if first_only:
			break
	return best
