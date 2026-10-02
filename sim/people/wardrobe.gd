class_name Wardrobe
extends RefCounted
## Clothes people own and their saved outfits (T-0072; static, no state). Person.wardrobe
## holds the owned items (item + colour, sorted), Person.outfits the saved outfits by name.

## The names an outfit can be saved under.
const OUTFIT_NAMES: PackedStringArray = ["Everyday", "Work", "Going out"]
## Starter pieces a new person owns besides what they wear.
const EXTRA_STARTERS: int = 3


## True if the person owns `clothing_id` in `colour`.
static func owns(person: Person, clothing_id: String, colour: String) -> bool:
	for item: WornItem in person.wardrobe:
		if item.clothing_id == clothing_id and item.colour == colour:
			return true
	return false


## Adds an item to the person's wardrobe (kept sorted by item, then colour); false if they
## own it already.
static func add(person: Person, clothing_id: String, colour: String) -> bool:
	if owns(person, clothing_id, colour):
		return false
	person.wardrobe.append(WornItem.new(clothing_id, colour))
	person.wardrobe.sort_custom(func(a: WornItem, b: WornItem) -> bool:
		return a.clothing_id < b.clothing_id or (a.clothing_id == b.clothing_id and a.colour < b.colour))
	return true


## What's wrong with the person wearing `outfit`: the outfit's own rules (Outfit.validate:
## known items, colours, top, bottom and feet always worn) and anything they don't own.
static func problems(sim: Sim, person: Person, outfit: Outfit) -> PackedStringArray:
	var out := outfit.validate(sim.content)
	for slot: String in outfit.items:
		var worn: WornItem = outfit.items[slot]
		if not owns(person, worn.clothing_id, worn.colour):
			out.append("you don't own the %s in %s" % [worn.clothing_id, worn.colour])
	return out


## True when the person stands on the use slot of a wardrobe in their own home.
static func at_wardrobe(sim: Sim, person: Person) -> bool:
	var here := person.cell()
	for id: int in sim.world.objects_tagged("wardrobe"):
		var obj: WorldObject = sim.world.objects[id]
		var lot := Lots.lot_at(sim, obj.origin)
		if lot == null or lot.id != person.home_lot_id:
			continue
		for slot: int in obj.slot_count(sim.content):
			if obj.slot_cell(sim.content, slot) == here:
				return true
	return false


## New games: everyone, in id order, owns what they wear plus EXTRA_STARTERS random starter
## pieces (draws from the "wardrobe" stream), and has it saved as "Everyday".
static func give_start(sim: Sim) -> void:
	var rng := sim.rng.stream("wardrobe")
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		give_person_start(sim, sim.world.people[id], rng)


## One person's starting wardrobe (new games and newcomers).
static func give_person_start(sim: Sim, person: Person, rng: RandomNumberGenerator) -> void:
	for slot: String in person.outfit.items:
		var worn: WornItem = person.outfit.items[slot]
		add(person, worn.clothing_id, worn.colour)
	var starters: Array[ClothingDef] = []
	for item: ClothingDef in sim.content.clothing.values():
		if item.starter:
			starters.append(item)
	for i: int in EXTRA_STARTERS if not starters.is_empty() else 0:
		var picked := starters[rng.randi_range(0, starters.size() - 1)]
		add(person, picked.id, String(picked.colours[rng.randi_range(0, picked.colours.size() - 1)]))
	person.outfits["Everyday"] = person.outfit.copy()
