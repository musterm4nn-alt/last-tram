class_name Laundry
extends RefCounted
## Clothes get dirty (T-0074; static, no state). Person.dirt holds 0..100 per owned piece
## ("item:colour"; missing = clean). What a person wears gets dirtier every waking minute,
## faster at work; past dirty_at it shows (a moodlet) and costs hygiene. Washing cleans all.


## The key of a piece of clothing in Person.dirt.
static func key(item: WornItem) -> String:
	return "%s:%s" % [item.clothing_id, item.colour]


## The average dirt of what the person wears (0 with nothing on).
static func worn_dirt(person: Person) -> float:
	var total := 0.0
	for slot: String in person.outfit.items:
		total += float(person.dirt.get(key(person.outfit.items[slot]), 0.0))
	return total / person.outfit.items.size() if not person.outfit.items.is_empty() else 0.0


## True when the clothes they wear are past dirty_at.
static func dirty(sim: Sim, person: Person) -> bool:
	return worn_dirt(person) >= sim.content.economy.dirty_at


## One minute (NeedsSystem): awake, the worn pieces get dirtier (more at work); dirty clothes
## cost hygiene and, on the hour, renew the dirty_clothes moodlet.
static func minute(sim: Sim, person: Person) -> void:
	var economy := sim.content.economy
	var asleep := false
	if not person.action_queue.is_empty() and person.action_queue[0].state == Action.PERFORMING:
		var def := sim.content.interaction(person.action_queue[0].interaction_id)
		asleep = def != null and def.routine == "sleep"
	if not asleep:
		var rate := economy.dirt_per_hour + (economy.work_dirt_per_hour if Jobs.working(sim, person) else 0.0)
		for slot: String in person.outfit.items:
			var piece := key(person.outfit.items[slot])
			person.dirt[piece] = minf(100.0, float(person.dirt.get(piece, 0.0)) + rate / 60.0)
	if dirty(sim, person):
		person.needs["hygiene"] = maxf(0.0, float(person.needs.get("hygiene", 0.0)) - economy.dirty_hygiene_per_hour / 60.0)
		if sim.clock.minute_of_day() % 60 == 0:
			Social.add_moodlet(sim, person, "dirty_clothes")


## Everything the person owns is clean.
static func wash(person: Person) -> void:
	person.dirt.clear()
