class_name Outfit
extends RefCounted
## What a person wears: one WornItem per slot (or empty). Top, bottom and feet are
## always worn (the game has no nudity); validation enforces it.


## Slot id -> WornItem.
var items: Dictionary[String, WornItem] = {}


## The item worn in `slot`, or null when nothing is worn there.
func get_item(slot: String) -> WornItem:
	return items.get(slot)


func put_on(slot: String, clothing_id: String, colour: String) -> void:
	items[slot] = WornItem.new(clothing_id, colour)


func take_off(slot: String) -> void:
	items.erase(slot)


## One message per problem: unknown slot/item, item in the wrong slot,
## a colour the item does not allow, or a REQUIRED slot left empty.
func validate(content: ContentDB) -> PackedStringArray:
	var problems := PackedStringArray()
	for slot: String in items:
		if not ClothingDef.SLOTS.has(slot):
			problems.append("unknown slot '%s'" % slot)
			continue
		var worn: WornItem = items[slot]
		var def: ClothingDef = content.clothing_def(worn.clothing_id)
		if def == null:
			problems.append("unknown clothing item '%s'" % worn.clothing_id)
			continue
		if def.slot != slot:
			problems.append("clothing item '%s' belongs in slot '%s', not '%s'" % [worn.clothing_id, def.slot, slot])
		if not def.colours.has(worn.colour):
			problems.append("colour '%s' is not allowed for item '%s'" % [worn.colour, worn.clothing_id])
	for slot: String in ClothingDef.REQUIRED_SLOTS:
		if not items.has(slot):
			problems.append("required slot '%s' is empty" % slot)
	return problems


func copy() -> Outfit:
	var out := Outfit.new()
	for slot: String in items:
		out.items[slot] = (items[slot] as WornItem).copy()
	return out


## {"top": {"item": "t_shirt", "colour": "black"}, ...}
func to_dict() -> Dictionary:
	var out := {}
	for slot: String in items:
		out[slot] = (items[slot] as WornItem).to_dict()
	return out


static func from_dict(d: Dictionary) -> Outfit:
	var out := Outfit.new()
	for key: Variant in d:
		var slot := String(key)
		var entry: Variant = d[key]
		if entry is Dictionary:
			out.items[slot] = WornItem.from_dict(entry)
	return out


## Deterministic random outfit: in ClothingDef.SLOTS order, required slots always,
## optional slots with probability 0.35. The item is uniform among eligible items
## for that slot (file order) and the colour uniform among the item's colours.
static func random(content: ContentDB, rng: RandomNumberGenerator, starter_only: bool = true) -> Outfit:
	var out := Outfit.new()
	for slot: String in ClothingDef.SLOTS:
		var required := ClothingDef.REQUIRED_SLOTS.has(slot)
		if not required and rng.randf() >= 0.35:
			continue
		var eligible: Array[ClothingDef] = []
		for item: ClothingDef in content.clothing.values():
			if item.slot == slot and (not starter_only or item.starter):
				eligible.append(item)
		if eligible.is_empty():
			continue
		var picked: ClothingDef = eligible[rng.randi_range(0, eligible.size() - 1)]
		var colour := String(picked.colours[rng.randi_range(0, picked.colours.size() - 1)])
		out.put_on(slot, picked.id, colour)
	return out
