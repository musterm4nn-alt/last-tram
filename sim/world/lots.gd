class_name Lots
extends RefCounted
## Questions about lots (static, no state): which lot a cell is on, whether a lot is open,
## and whether a person may enter it.


## The lot of the place containing `cell` (ContentDB.place_at), or null.
static func lot_at(sim: Sim, cell: Vector3i) -> Lot:
	var place := sim.content.place_at(cell)
	if place == null:
		return null
	return by_place(sim.world, place.id)


## The lot covering the place with this id, or null.
static func by_place(world: World, place_id: String) -> Lot:
	for lot: Lot in world.lots.values():
		if lot.place_id == place_id:
			return lot
	return null


## True if the lot is open at the clock's hour. Public and private lots are always "open"
## (private ones still only let residents in). Hours: open_hour <= hour < close_hour, or
## past midnight when close_hour < open_hour; equal hours mean open all day.
static func is_open(lot: Lot, clock: SimClock) -> bool:
	if lot.access != Lot.HOURS or lot.open_hour == lot.close_hour:
		return true
	var hour := clock.hour()
	if lot.open_hour < lot.close_hour:
		return hour >= lot.open_hour and hour < lot.close_hour
	return hour >= lot.open_hour or hour < lot.close_hour


## Public: yes. Hours: while open. Private: only for the people who live there.
static func may_enter(sim: Sim, person: Person, lot: Lot) -> bool:
	match lot.access:
		Lot.PUBLIC:
			return true
		Lot.HOURS:
			return is_open(lot, sim.clock)
	return person.home_lot_id == lot.id


## Creates one lot per place, in district and place order (new games, and saves from
## before lots existed).
static func create_from_content(world: World) -> void:
	for district_id: String in world.content.district_order:
		for place: PlaceDef in world.content.districts[district_id].places:
			var lot := Lot.from_place(world.new_id(), place)
			world.lots[lot.id] = lot
