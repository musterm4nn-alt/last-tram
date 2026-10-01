class_name TownCheck
extends RefCounted
## M2 acceptance (T-0045): watches a headless run and says whether the town lives well.
## Feed it every sim event (observe) and sample it once per game minute (sample); failures()
## lists what went wrong in plain words ([] = healthy). Used by `tools/simrun.sh --check-m2`
## and tests/sim/test_m2_town_lives.gd.

const EATING: PackedStringArray = ["cook_meal", "grab_snack", "eat_doener", "eat_fries", "buy_snack"]
## Share of person-minutes any need may spend below 30.
const MAX_LOW_SHARE: float = 0.02
## No need may ever fall below this.
const NEED_FLOOR: float = 5.0
## Share of residents who must know someone outside their household (familiarity >= 20).
const MIN_CONNECTED_SHARE: float = 0.5

var meals: Dictionary[int, int] = {}
var sleeps: Dictionary[int, int] = {}
var sleeps_away: Dictionary[int, int] = {}
var exchanges: Dictionary[int, int] = {}
var low: Dictionary[String, int] = {}
var lowest: Dictionary[String, float] = {}
var samples: int = 0


func observe(sim: Sim, event: Dictionary) -> void:
	var data: Dictionary = event.get("data", {})
	match event.get("type"):
		&"action_finished":
			var id := int(data["person_id"])
			var interaction := String(data["interaction_id"])
			if EATING.has(interaction):
				meals[id] = meals.get(id, 0) + 1
			elif interaction == "sleep":
				sleeps[id] = sleeps.get(id, 0) + 1
				if not Routines.at_home(sim, sim.world.get_person(id)):
					sleeps_away[id] = sleeps_away.get(id, 0) + 1
		&"social_exchange":
			for key: String in ["actor_id", "target_id"]:
				var id := int(data[key])
				exchanges[id] = exchanges.get(id, 0) + 1


func sample(sim: Sim) -> void:
	samples += 1
	for person: Person in sim.world.people.values():
		for need_id: String in person.needs:
			var value: float = person.needs[need_id]
			lowest[need_id] = minf(lowest.get(need_id, 100.0), value)
			if value < 30.0:
				low[need_id] = low.get(need_id, 0) + 1


## What went wrong over `days` game days ([] when the town lived well): everyone eats at least
## days − 1 times, sleeps at least days − 1 times, always at home, and takes part in at least
## days / 2 social exchanges (loners exist); needs stay above NEED_FLOOR and below 30 at most MAX_LOW_SHARE of
## the time; and enough residents know someone outside their household (MIN_CONNECTED_SHARE
## after a week, proportionally less before).
func failures(sim: Sim, days: int) -> PackedStringArray:
	var out := PackedStringArray()
	for person: Person in sim.world.people.values():
		var name := person.full_name()
		if meals.get(person.id, 0) < days - 1:
			out.append("%s ate only %d times" % [name, meals.get(person.id, 0)])
		if sleeps.get(person.id, 0) < days - 1:
			out.append("%s slept only %d times" % [name, sleeps.get(person.id, 0)])
		if sleeps_away.get(person.id, 0) > 0:
			out.append("%s slept away from home %d times" % [name, sleeps_away[person.id]])
		if exchanges.get(person.id, 0) < days / 2:
			out.append("%s talked with people only %d times" % [name, exchanges.get(person.id, 0)])
	var people := sim.world.people.size()
	for need_id: String in lowest:
		if lowest[need_id] < NEED_FLOOR:
			out.append("%s fell to %.1f" % [need_id, lowest[need_id]])
		var share := float(low.get(need_id, 0)) / maxf(1.0, float(samples * people))
		if share > MAX_LOW_SHARE:
			out.append("%s was below 30 for %.1f%% of the time" % [need_id, share * 100.0])
	var connected := 0
	var residents := 0
	for person: Person in sim.world.people.values():
		if person.id == sim.world.player_id:
			continue
		residents += 1
		for r: Relationship in person.relationships.values():
			var other := sim.world.get_person(r.other_id)
			if other != null and other.household_id != person.household_id and r.familiarity >= 20.0:
				connected += 1
				break
	# Friendships take time: the full share is expected after a week.
	if connected < residents * MIN_CONNECTED_SHARE * minf(1.0, days / 7.0):
		out.append("only %d of %d residents know someone outside their household" % [connected, residents])
	return out


## Plain-words numbers for the report.
func summary(sim: Sim) -> PackedStringArray:
	var out := PackedStringArray()
	var total_exchanges := 0
	for id: int in exchanges:
		total_exchanges += exchanges[id]
	out.append("meals %d, sleeps %d (away from home %d), social exchanges %d" % [
		_sum(meals), _sum(sleeps), _sum(sleeps_away), total_exchanges / 2])
	return out


static func _sum(counts: Dictionary[int, int]) -> int:
	var total := 0
	for id: int in counts:
		total += counts[id]
	return total
