class_name Routines
extends RefCounted
## Daily rhythm rules (T-0036, static, no state): when a person's routine says to sleep, how
## that changes free will's scores and when sleep ends, and the way home.

## Score factor for routine "sleep" interactions inside the sleep window.
const SLEEP_IN_WINDOW: float = 2.0
## Score factor for routine "sleep" interactions outside it (only exhaustion wins then).
const SLEEP_OUTSIDE: float = 0.3
## Added to routine "sleep" scores in the sleep window: bedtime wins over the TV even when a
## daytime nap left the person less tired.
const SLEEP_BONUS: float = 6.0
## Added to routine "out" scores in the out window, scaled by sociability (score_bonus).
const OUT_BONUS: float = 5.0
## Score factor for routine "out" interactions outside the out window.
const OUT_OUTSIDE: float = 0.5


## The person's routine, or the content's default (also for unknown ids).
static func routine_of(sim: Sim, person: Person) -> RoutineDef:
	var routine := sim.content.routine(person.routine_id)
	return routine if routine != null else sim.content.routine(sim.content.default_routine)


## True if `hour` is in [hours.x, hours.y), wrapping past midnight when hours.y < hours.x.
static func in_hours(hours: Vector2i, hour: int) -> bool:
	if hours.x < hours.y:
		return hour >= hours.x and hour < hours.y
	return hour >= hours.x or hour < hours.y


## True during the person's sleep window.
static func sleeping_time(sim: Sim, person: Person) -> bool:
	var routine := routine_of(sim, person)
	return routine != null and in_hours(routine.sleep_hours, sim.clock.hour())


## True during the person's evening window for going out.
static func going_out_time(sim: Sim, person: Person) -> bool:
	var routine := routine_of(sim, person)
	return routine != null and in_hours(routine.out_hours, sim.clock.hour())


## Multiplies free will's need score for `def`.
static func score_factor(sim: Sim, person: Person, def: InteractionDef) -> float:
	if def.routine == "sleep":
		return SLEEP_IN_WINDOW if sleeping_time(sim, person) else SLEEP_OUTSIDE
	if def.routine == "out" and not going_out_time(sim, person):
		return OUT_OUTSIDE
	return 1.0


## Added to free will's score for `def`: SLEEP_BONUS for "sleep" in the sleep window;
## OUT_BONUS × (1 + 0.5 × sociability / 100) for "out" in the out window (2.5 for a loner,
## 7.5 for the most outgoing); else 0.
static func score_bonus(sim: Sim, person: Person, def: InteractionDef) -> float:
	if def.routine == "sleep":
		return SLEEP_BONUS if sleeping_time(sim, person) else 0.0
	if def.routine != "out" or not going_out_time(sim, person):
		return 0.0
	return OUT_BONUS * (1.0 + 0.5 * person.personality.get_axis("sociability") / 100.0)


## True while a "sleep" interaction should go on past a full need (inside the window).
static func keeps_sleeping(sim: Sim, person: Person, def: InteractionDef) -> bool:
	return def.routine == "sleep" and sleeping_time(sim, person)


## True if the person stands on their home lot (or has none).
static func at_home(sim: Sim, person: Person) -> bool:
	if person.home_lot_id <= 0:
		return true
	var lot := Lots.lot_at(sim, person.cell())
	return lot != null and lot.id == person.home_lot_id


## A path to the first free walkable cell of the person's home (scan order) that can be
## reached; [] when they are home, have no home, or cannot get there.
static func home_route(sim: Sim, person: Person) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	if at_home(sim, person):
		return none
	var lot: Lot = sim.world.lots.get(person.home_lot_id)
	var place := sim.content.place(lot.place_id) if lot != null else null
	if place == null:
		return none
	for cell: Vector3i in Lots.free_cells(sim, place):
		var path := sim.nav.find_path(person.cell(), cell)
		if not path.is_empty():
			return path
	return none
