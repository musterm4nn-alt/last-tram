class_name ResidentGenerator
extends RefCounted
## Fills a new game's empty homes with households of generated adults (static, no state).
## Every draw comes from the "generation" stream, so the same seed gives the same town.

## Household kinds by weight; flatmates are FLATMATES_MIN..FLATMATES_MAX people.
const KIND_WEIGHTS: Dictionary = {Household.SINGLE: 30, Household.COUPLE: 40, Household.FLATMATES: 30}
const FLATMATES_MIN: int = 2
## Two: the flats have one double bed (two sides). A third flatmate never got a bed (T-0045).
const FLATMATES_MAX: int = 2
## A partner's age is within this many years of the first member's.
const COUPLE_AGE_GAP: int = 8
## How often partners share a last name.
const SHARED_SURNAME_CHANCE: float = 0.5
## How household members see each other at the start (T-0037).
const BONDS: Dictionary = {
	Household.COUPLE: {"familiarity": 90.0, "friendship": 60.0, "romance": 70.0, "trust": 60.0},
	Household.FLATMATES: {"familiarity": 70.0, "friendship": 30.0, "trust": 25.0},
}


## One household in each private home lot (in id order) except `skip_lot_ids`.
static func populate(sim: Sim, skip_lot_ids: Array[int]) -> void:
	var rng := sim.rng.stream("generation")
	var lot_ids: Array = sim.world.lots.keys()
	lot_ids.sort()
	for lot_id: int in lot_ids:
		var lot: Lot = sim.world.lots[lot_id]
		var place := sim.content.place(lot.place_id)
		if place == null or place.kind != "home" or lot.access != Lot.PRIVATE or skip_lot_ids.has(lot_id):
			continue
		_move_in(sim, rng, lot, place)


## Newcomers for an empty flat (T-0066): a household made as in a new town (draws from the
## "generation" stream), with start money ("money"), groceries ("groceries") and benefit
## registration. Null (and nothing made) when nobody fits in the flat.
static func newcomers(sim: Sim, lot: Lot) -> Household:
	var place := sim.content.place(lot.place_id)
	if place == null:
		return null
	var household := _move_in(sim, sim.rng.stream("generation"), lot, place)
	if household.member_ids.is_empty():
		sim.world.households.erase(household.id)
		return null
	var money := sim.rng.stream("money")
	for member_id: int in household.member_ids:
		var person := sim.world.get_person(member_id)
		person.benefit_registered = true
		Money.give_resident_start(sim, person, money)
		Wardrobe.give_person_start(sim, person, sim.rng.stream("wardrobe"))
	var range_ := sim.content.economy.start_groceries
	household.groceries = sim.rng.stream("groceries").randi_range(range_.x, range_.y)
	return household


## A household for `lot`: picks its kind and size, then creates and places its members.
static func _move_in(sim: Sim, rng: RandomNumberGenerator, lot: Lot, place: PlaceDef) -> Household:
	var household := Household.new()
	household.id = sim.world.new_id()
	household.kind = _pick_kind(rng)
	if bed_places(sim, place) < 2:
		household.kind = Household.SINGLE  # one usable side of the bed: one sleeper (T-0045)
	household.home_lot_id = lot.id
	var size := 1
	if household.kind == Household.COUPLE:
		size = 2
	elif household.kind == Household.FLATMATES:
		size = rng.randi_range(FLATMATES_MIN, FLATMATES_MAX)
	var spots := Lots.free_cells(sim, place)
	var first: CharacterSpec = null
	for i: int in size:
		if spots.is_empty():
			break
		var spec := CharacterSpec.random(sim.content, rng)
		if household.kind == Household.COUPLE and first != null:
			_partner_of(spec, first, sim.content, rng)
		var routine_id := _pick_routine(sim.content, rng)
		var cell: Vector3i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var person := SimFactory.spawn_person(sim, cell, spec)
		person.household_id = household.id
		person.routine_id = routine_id
		person.home_lot_id = lot.id
		household.member_ids.append(person.id)
		if first == null:
			first = spec
	sim.world.households[household.id] = household
	if BONDS.has(household.kind):
		for a: int in household.member_ids:
			for b: int in household.member_ids:
				if a != b:
					Social.set_values(sim.world.get_person(a), b, BONDS[household.kind], sim.clock.tick)
	return household


## How many people can sleep in `place`: the walkable use slots of its objects tagged "bed".
static func bed_places(sim: Sim, place: PlaceDef) -> int:
	var count := 0
	for obj: WorldObject in sim.world.objects.values():
		var def := sim.content.object_def(obj.def_id)
		if def == null or not def.tags.has("bed") or sim.content.place_at(obj.origin) != place:
			continue
		for index: int in obj.slot_count(sim.content):
			if sim.world.grid.is_walkable(obj.slot_cell(sim.content, index)):
				count += 1
	return count


static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0
	for kind: String in KIND_WEIGHTS:
		total += int(KIND_WEIGHTS[kind])
	var pick := rng.randi_range(1, total)
	for kind: String in KIND_WEIGHTS:
		pick -= int(KIND_WEIGHTS[kind])
		if pick <= 0:
			return kind
	return Household.SINGLE


## Ages `spec` to within COUPLE_AGE_GAP of `first` (never below 18 or outside the catalog's
## range) and sometimes gives it `first`'s last name.
static func _partner_of(spec: CharacterSpec, first: CharacterSpec, content: ContentDB, rng: RandomNumberGenerator) -> void:
	var low := maxi(Person.MIN_AGE, maxi(content.appearance.age_min, first.age_years - COUPLE_AGE_GAP))
	var high := maxi(low, mini(content.appearance.age_max, first.age_years + COUPLE_AGE_GAP))
	spec.age_years = rng.randi_range(low, high)
	if rng.randf() < SHARED_SURNAME_CHANCE:
		spec.last_name = first.last_name


## A routine id, weighted by RoutineDef.weight (in id order).
static func _pick_routine(content: ContentDB, rng: RandomNumberGenerator) -> String:
	var ids: Array = content.routines.keys()
	ids.sort()
	var total := 0
	for id: String in ids:
		total += content.routines[id].weight
	var pick := rng.randi_range(1, maxi(total, 1))
	for id: String in ids:
		pick -= content.routines[id].weight
		if pick <= 0:
			return id
	return content.default_routine
