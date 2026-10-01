class_name ResidentGenerator
extends RefCounted
## Fills a new game's empty homes with households of generated adults (static, no state).
## Every draw comes from the "generation" stream, so the same seed gives the same town.

## Household kinds by weight; flatmates are FLATMATES_MIN..FLATMATES_MAX people.
const KIND_WEIGHTS: Dictionary = {Household.SINGLE: 30, Household.COUPLE: 40, Household.FLATMATES: 30}
const FLATMATES_MIN: int = 2
const FLATMATES_MAX: int = 3
## A partner's age is within this many years of the first member's.
const COUPLE_AGE_GAP: int = 8
## How often partners share a last name.
const SHARED_SURNAME_CHANCE: float = 0.5


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


## A household for `lot`: picks its kind and size, then creates and places its members.
static func _move_in(sim: Sim, rng: RandomNumberGenerator, lot: Lot, place: PlaceDef) -> void:
	var household := Household.new()
	household.id = sim.world.new_id()
	household.kind = _pick_kind(rng)
	household.home_lot_id = lot.id
	var size := 1
	if household.kind == Household.COUPLE:
		size = 2
	elif household.kind == Household.FLATMATES:
		size = rng.randi_range(FLATMATES_MIN, FLATMATES_MAX)
	var spots := free_cells(sim, place)
	var first: CharacterSpec = null
	for i: int in size:
		if spots.is_empty():
			break
		var spec := CharacterSpec.random(sim.content, rng)
		if household.kind == Household.COUPLE and first != null:
			_partner_of(spec, first, sim.content, rng)
		var cell: Vector3i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var person := SimFactory.spawn_person(sim, cell, spec)
		person.household_id = household.id
		person.home_lot_id = lot.id
		household.member_ids.append(person.id)
		if first == null:
			first = spec
	sim.world.households[household.id] = household


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


## Walkable cells of `place` (on its level, not claimed by an earlier place) where nobody
## stands yet, in scan order.
static func free_cells(sim: Sim, place: PlaceDef) -> Array[Vector3i]:
	var taken: Dictionary[Vector3i, bool] = {}
	for person: Person in sim.world.people.values():
		taken[person.cell()] = true
	var out: Array[Vector3i] = []
	for y: int in range(place.rect.position.y, place.rect.end.y):
		for x: int in range(place.rect.position.x, place.rect.end.x):
			var cell := Vector3i(x, y, place.level)
			if sim.content.place_at(cell) == place and sim.world.grid.is_walkable(cell) and not taken.has(cell):
				out.append(cell)
	return out
