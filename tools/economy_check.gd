class_name EconomyCheck
extends RefCounted
## M3 acceptance (T-0076): watches a long headless run and says whether the economy stays
## stable. Call start() once before the run, observe() with every sim event, and end_of_day()
## at each midnight; failures() lists what went wrong in plain words ([] = stable). Used by
## `tools/simrun.sh --days=30 --check-m3` (with TownCheck's M2 rules and the cost budget) and
## tests/sim/test_economy_check.gd.

## Under this much money in all (cash and bank, cents), a person counts as broke.
const BROKE_CENTS: int = 500
## Share of people who may be broke at a day's end.
const MAX_BROKE_SHARE: float = 0.1
## More evictions than this over the run is mass eviction.
const MAX_EVICTIONS: int = 1
## The employment rate may move this many percentage points from the start.
const MAX_EMPLOYMENT_SWING: float = 20.0
## Share of its open time each staffed place must have someone serving (TownCheck measures it).
const MIN_STAFFED_SHARE: float = 0.8

## The employment rate (percent) when the run started.
var start_employment: float = 0.0
var days: int = 0
var evictions: int = 0
## The most people broke at any day's end, and the lowest and highest employment rates.
var most_broke: int = 0
var lowest_employment: float = 100.0
var highest_employment: float = 0.0
## Day-end problems, in order ("day 3: ...").
var problems: PackedStringArray = []


func start(sim: Sim) -> void:
	start_employment = employment_rate(sim)
	lowest_employment = start_employment
	highest_employment = start_employment


func observe(_sim: Sim, event: Dictionary) -> void:
	if event.get("type") == &"evicted":
		evictions += 1


## Checks the day that just ended: the ledger balances, few people are broke and the
## employment rate stays near where it started.
func end_of_day(sim: Sim) -> void:
	days += 1
	var held := Money.held(sim.world)
	var balance := sim.world.ledger.balance()
	if held != balance:
		problems.append("day %d: people hold %s but the ledger says %s" % [days, Money.format(held), Money.format(balance)])
	var broke := broke_people(sim)
	most_broke = maxi(most_broke, broke.size())
	if broke.size() > sim.world.people.size() * MAX_BROKE_SHARE:
		var names := PackedStringArray()
		for person: Person in broke:
			names.append(person.full_name())
		problems.append("day %d: %d of %d people are broke (%s)" % [days, broke.size(), sim.world.people.size(), ", ".join(names)])
	var rate := employment_rate(sim)
	lowest_employment = minf(lowest_employment, rate)
	highest_employment = maxf(highest_employment, rate)
	if absf(rate - start_employment) > MAX_EMPLOYMENT_SWING:
		problems.append("day %d: employment is %.0f%% (it started at %.0f%%)" % [days, rate, start_employment])


## Everything that went wrong: the day-end problems, mass eviction and understaffed shops
## (from `town`'s staffing numbers).
func failures(sim: Sim, town: TownCheck) -> PackedStringArray:
	var out := problems.duplicate()
	if evictions > MAX_EVICTIONS:
		out.append("%d households were evicted" % evictions)
	for place_id: String in Staffing.places(sim.content):
		if town.staffed_share(place_id) < MIN_STAFFED_SHARE:
			out.append("%s was staffed only %.0f%% of its open time" % [sim.content.place(place_id).name, town.staffed_share(place_id) * 100.0])
	return out


## "economy: 30 days, employment 78% (start 78%, range 74–81%), most broke at a day's end 1,
## evictions 0".
func summary() -> String:
	return "economy: %d days, employment start %.0f%% (range %.0f–%.0f%%), most broke at a day's end %d, evictions %d" % [
		days, start_employment, lowest_employment, highest_employment, most_broke, evictions]


## People holding less than BROKE_CENTS in all, in id order.
static func broke_people(sim: Sim) -> Array[Person]:
	var ids: Array = sim.world.people.keys()
	ids.sort()
	var out: Array[Person] = []
	for id: int in ids:
		var person: Person = sim.world.people[id]
		if person.wallet.total() < BROKE_CENTS:
			out.append(person)
	return out


## Percent of working-age residents (not the player; under the retirement age) with a job.
static func employment_rate(sim: Sim) -> float:
	var working_age := 0
	var employed := 0
	for person: Person in sim.world.people.values():
		if person.id == sim.world.player_id or person.age_years >= sim.content.economy.retirement_age:
			continue
		working_age += 1
		if person.job != null:
			employed += 1
	return 100.0 * employed / working_age if working_age > 0 else 0.0
