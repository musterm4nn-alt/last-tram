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


## Every option the person could take now (AutonomyOption), in object id order, then content
## order, then the social options.
## `cells` is the path length to the object's nearest free, walkable slot (0 when the person
## stands on one); objects with no reachable free slot give no options.
static func candidates(sim: Sim, person: Person) -> Array[AutonomyOption]:
	var out: Array[AutonomyOption] = []
	var cells_of: Dictionary = {}
	for entry: Dictionary in _unwalked(sim, person):
		var cells := _cells(sim, person, entry, cells_of)
		if cells >= 0:
			var option := AutonomyOption.new(int(entry["object_id"]), String(entry["interaction_id"]),
				float(entry["base"]) - TRAVEL_COST_PER_CELL * cells, cells, AutonomyOption.PERSON if entry["person"] else AutonomyOption.OBJECT)
			option.order = out.size()
			out.append(option)
	return out


## What free will picks now (T-0078): exactly choose(candidates(sim, person), rng), but walks
## are worked out only for options that could still make the best TOP_N. Each option's
## score without the walk, minus the walk's lower bound (straight-line distance), plus its
## noise, is an upper bound; options are tried best bound first, and once the TOP_N-th best
## real score beats every remaining bound, the rest are skipped.
static func decide(sim: Sim, person: Person, rng: RandomNumberGenerator) -> AutonomyOption:
	var salt := rng.randi()
	var pending := _unwalked(sim, person)
	for entry: Dictionary in pending:
		entry["noise"] = noise(salt, int(entry["object_id"]), String(entry["interaction_id"]))
		entry["bound_score"] = float(entry["base"]) - TRAVEL_COST_PER_CELL * int(entry["bound"]) + float(entry["noise"])
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["bound_score"]) > float(b["bound_score"]) or (float(a["bound_score"]) == float(b["bound_score"]) and int(a["order"]) < int(b["order"])))
	var kept: Array[AutonomyOption] = []
	var cells_of: Dictionary = {}
	for entry: Dictionary in pending:
		if float(entry["bound_score"]) < MIN_SCORE:
			break
		if kept.size() >= TOP_N and float(entry["bound_score"]) < kept[TOP_N - 1].score:
			break
		var cells := _cells(sim, person, entry, cells_of)
		if cells < 0:
			continue
		var noisy := float(entry["base"]) - TRAVEL_COST_PER_CELL * cells + float(entry["noise"])
		if noisy < MIN_SCORE:
			continue
		var option := AutonomyOption.new(int(entry["object_id"]), String(entry["interaction_id"]), noisy, cells,
			AutonomyOption.PERSON if entry["person"] else AutonomyOption.OBJECT)
		option.order = int(entry["order"])
		kept.append(option)
		kept.sort_custom(_better)
		kept = kept.slice(0, TOP_N)
	return _pick(kept, rng)


## Options before the walk (shared by candidates and decide): {object_id, interaction_id,
## base: the score without the walk, bound: a lower bound of the walk's cells, near: bool,
## person: bool, order: the option's place in candidates()' order}.
static func _unwalked(sim: Sim, person: Person) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var here := person.cell()
	var ids: Array = sim.world.objects.keys()
	ids.sort()
	var going_out := Routines.going_out_time(sim, person)
	var far_defs := _outing_objects(sim) if going_out else {}
	far_defs.merge(_errand_objects(sim, person))
	var taken := Interactions.taken_slots(sim)
	for id: int in ids:
		var obj: WorldObject = sim.world.objects[id]
		var near := obj.origin.z == here.z and maxi(absi(obj.origin.x - here.x), absi(obj.origin.y - here.y)) <= SEARCH_RADIUS
		if (not near and not far_defs.has(obj.def_id)) or not sim.content.free_will_objects().has(obj.def_id):
			continue
		var lot := Lots.lot_at(sim, obj.origin)
		if lot != null and not Lots.may_enter(sim, person, lot):
			continue
		var bound := _slot_bound(sim, person, obj, taken)
		if bound < 0:
			continue
		for def: InteractionDef in Interactions.offered_by(sim, id):
			if not near and not (going_out and def.routine == "out") and not errand(sim, person, def):
				continue
			if def.adds_groceries > 0 and not restock_needed(sim, person):
				continue
			if not Requirements.check(sim, person, def, id).is_empty():
				continue
			out.append({
				"object_id": id, "interaction_id": def.id, "near": near, "person": false, "bound": bound, "order": out.size(),
				"base": Utility.need_score(person, def, sim.content) * Routines.score_factor(sim, person, def)
					+ Routines.score_bonus(sim, person, def) - Utility.price_cost(person, def, sim.content)
					+ (sim.content.economy.restock_bonus if def.adds_groceries > 0 else 0.0)
					+ (sim.content.economy.cash_errand_score if def.cash_out > 0 and errand(sim, person, def) else 0.0)
					+ (sim.content.economy.laundry_errand_score if def.launders and errand(sim, person, def) else 0.0),
			})
	for other: Person in _nearby_people(sim, person):
		var bound := 0 if Conversations.adjacent(person, other) else maxi(0, _chebyshev(here, other.cell()) - 1)
		for def: InteractionDef in Interactions.offered_by_person(sim, person.id, other.id):
			out.append({
				"object_id": other.id, "interaction_id": def.id, "near": true, "person": true, "bound": bound, "order": out.size(),
				"base": Utility.need_score(person, def, sim.content) * Routines.score_factor(sim, person, def)
					+ Utility.social_bias(person, other, def) + Routines.social_out_bonus(sim, person, def),
			})
	return out


## The walk for an option, worked out once per target (`cache`): an object's
## cells_to_free_slot (the first reachable slot for far objects), or a person's path length
## minus one (0 when next to them). -1 when it can't be reached.
static func _cells(sim: Sim, person: Person, entry: Dictionary, cache: Dictionary) -> int:
	var key := int(entry["object_id"])
	if not cache.has(key):
		if entry["person"]:
			var other := sim.world.get_person(key)
			var length := sim.nav.path_length(person.cell(), other.cell())
			cache[key] = 0 if Conversations.adjacent(person, other) else (length - 1 if length >= 0 else -1)
		else:
			if not cache.has("taken"):
				cache["taken"] = Interactions.taken_slots(sim)
			cache[key] = cells_to_free_slot(sim, person, sim.world.get_object(key), not entry["near"], cache["taken"])
	return int(cache[key])


## A lower bound of cells_to_free_slot without pathfinding: the smallest straight-line
## (Chebyshev) distance to a free, walkable customer slot on the same level (0 across
## levels); -1 when there is no such slot at all.
static func _slot_bound(sim: Sim, person: Person, obj: WorldObject, taken: Dictionary) -> int:
	var here := person.cell()
	var best := -1
	var def := sim.content.object_def(obj.def_id)
	for index: int in obj.slot_count(sim.content):
		if def.use_slots[index].role != "customer" or Interactions.taken_in(taken, obj.id, index, person.id):
			continue
		var cell := obj.slot_cell(sim.content, index)
		if not sim.world.grid.is_walkable(cell):
			continue
		var distance := _chebyshev(here, cell) if cell.z == here.z else 0
		if best < 0 or distance < best:
			best = distance
	return best


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Social options (T-0039): the PEOPLE_CONSIDERED nearest available people within
## SEARCH_RADIUS on the same level whose spot the person may enter (nearest first, then id).
## Their options are scored by need × routine factor + Social bias − travel.
static func _nearby_people(sim: Sim, person: Person) -> Array[Person]:
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
	return nearby.slice(0, PEOPLE_CONSIDERED)


## True for errands worth crossing town for (T-0057): a grocery run while the home stock is
## below restock_below, and food for sale (a price, advertises hunger) while hunger is below
## hungry_below and the home has fewer than 2 portions, and the ATM while the pocket holds
## less than pocket_money (T-0064 playtest: pockets ran empty; data/economy.json), and a bench
## to sleep on for someone with no home (T-0066), and a wash for dirty clothes (T-0074).
static func errand(sim: Sim, person: Person, def: InteractionDef) -> bool:
	if def.homeless_only:
		return person.home_lot_id <= 0
	if def.launders:
		return Laundry.dirty(sim, person)
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
		for def_id: String in sim.content.defs_offering(interaction.id):
			out[def_id] = true
	return out


## Object def ids offering at least one routine "out" interaction.
static func _outing_objects(sim: Sim) -> Dictionary:
	var out: Dictionary = {}
	for interaction: InteractionDef in sim.content.interactions.values():
		if interaction.routine == "out":
			for def_id: String in sim.content.defs_offering(interaction.id):
				out[def_id] = true
	return out


## Adds each option's noise (noise(): 0..NOISE, from one rng draw per pick and the option
## itself, so an unrelated new option doesn't change the others'; T-0078), drops options below
## MIN_SCORE, keeps the TOP_N best (ties: earlier in the list), and picks one with probability
## proportional to its noisy score. Returns null when nothing is left. Uses `rng` only.
static func choose(options: Array[AutonomyOption], rng: RandomNumberGenerator) -> AutonomyOption:
	var salt := rng.randi()
	var kept: Array[AutonomyOption] = []
	for index: int in options.size():
		var option := options[index].copy()
		option.score += noise(salt, option.target_id, option.interaction_id)
		option.order = index
		if option.score >= MIN_SCORE:
			kept.append(option)
	kept.sort_custom(_better)
	return _pick(kept.slice(0, TOP_N), rng)


## One of `kept` (the best first), with probability proportional to its score; null for none.
static func _pick(kept: Array[AutonomyOption], rng: RandomNumberGenerator) -> AutonomyOption:
	if kept.is_empty():
		return null
	var total := 0.0
	for option: AutonomyOption in kept:
		total += option.score
	var pick := rng.randf() * total
	var chosen: AutonomyOption = kept[kept.size() - 1]
	for option: AutonomyOption in kept:
		pick -= option.score
		if pick <= 0.0:
			chosen = option
			break
	return chosen


## An option's noise, 0..NOISE: a hash of the pick's `salt`, the target and the interaction
## (integer maths only, the same on every machine).
static func noise(salt: int, target_id: int, interaction_id: String) -> float:
	var h := (salt ^ ((target_id * 0x9E3779B1) & 0xFFFFFFFF)) & 0xFFFFFFFF
	for byte: int in interaction_id.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
	h ^= h >> 12
	return float(h) / 4294967296.0 * NOISE


## Sort order for choose(): higher score first, then earlier in the list.
static func _better(a: AutonomyOption, b: AutonomyOption) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return a.order < b.order


## Path length to the object's nearest free, walkable customer slot (free will never works): 0 when the person stands on one,
## -1 when none can be reached. With `first_only` (far objects), the first reachable free slot
## stands in for the nearest, saving a route per slot.
static func cells_to_free_slot(sim: Sim, person: Person, obj: WorldObject, first_only: bool = false, taken: Variant = null) -> int:
	var here := person.cell()
	var best := -1
	var def := sim.content.object_def(obj.def_id)
	for index: int in obj.slot_count(sim.content):
		if def.use_slots[index].role != "customer":
			continue
		if Interactions.taken_in(taken, obj.id, index, person.id) if taken is Dictionary else Interactions.slot_taken(sim, obj.id, index, person.id):
			continue
		var cell := obj.slot_cell(sim.content, index)
		if not sim.world.grid.is_walkable(cell):
			continue
		if cell == here:
			return 0
		var length := sim.nav.path_length(here, cell)
		if length < 0:
			continue
		if best < 0 or length < best:
			best = length
		if first_only:
			break
	return best
