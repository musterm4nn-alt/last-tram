class_name SaveMigrationsM3
extends RefCounted
## The save upgrades of M3 from v12 on (split out of SaveMigrations, which runs them in order).
## Never edit a step once it has been merged.


## v18 (T-0074): clothes start clean, and the Waschsalon gets its four washing machines.
static func v17_to_v18(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	var world: Dictionary = d["world"]
	for person: Variant in world.get("people", []):
		if person is Dictionary:
			person["dirt"] = {}
	var objects: Variant = world.get("objects")
	if not objects is Array or (objects as Array).is_empty() \
			or (objects as Array).any(func(obj: Variant) -> bool: return obj is Dictionary and obj.get("def_id") == "washing_machine"):
		return d
	var next := SaveMigrations.number(world.get("next_id"), 1)
	for x: int in [34, 35, 36, 37]:
		objects.append({"id": next, "def_id": "washing_machine", "origin": [x, 7, 0], "rotation": 0})
		next += 1
	world["next_id"] = next
	return d


## v17 (T-0073): Waschsalon Blitz gets a second-hand clothes rail and a barber chair (saves
## with objects and none yet; ids from next_id).
const V17_NEW: Array = [["clothes_rack", [32, 10, 0]], ["clothes_rack", [32, 12, 0]], ["barber_chair", [39, 11, 0]]]


static func v16_to_v17(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("objects") is Array:
		return d
	var world: Dictionary = d["world"]
	var objects: Array = world["objects"]
	if objects.is_empty() or objects.any(func(obj: Variant) -> bool: return obj is Dictionary and obj.get("def_id") == "barber_chair"):
		return d
	var next := SaveMigrations.number(world.get("next_id"), 1)
	for entry: Array in V17_NEW:
		objects.append({"id": next, "def_id": entry[0], "origin": entry[1], "rotation": 0})
		next += 1
	world["next_id"] = next
	return d


## Where the wardrobes stood when v16 was made (origin, rotation), one per home.
const V16_WARDROBES: Array = [[[27, 7, 1], 0], [[36, 7, 1], 0], [[27, 7, 2], 0], [[36, 7, 2], 0], [[48, 7, 1], 0], [[48, 7, 2], 0], [[62, 10, 1], 1], [[69, 9, 1], 1], [[62, 10, 2], 1], [[69, 9, 2], 1], [[7, 24, 1], 0], [[11, 24, 1], 0], [[7, 24, 2], 0], [[11, 24, 2], 0], [[60, 7, 0], 0], [[48, 24, 0], 0]]


## v16 (T-0072): everyone owns what they wear, saved as "Everyday", and every home gets its
## wardrobe (saves with objects and none yet; ids from next_id).
static func v15_to_v16(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	var world: Dictionary = d["world"]
	for person: Variant in world.get("people", []):
		if not person is Dictionary:
			continue
		var outfit: Dictionary = person.get("outfit", {}) if person.get("outfit") is Dictionary else {}
		var owned: Array = []
		for slot: Variant in outfit:
			if outfit[slot] is Dictionary:
				owned.append((outfit[slot] as Dictionary).duplicate())
		owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("item")) < String(b.get("item")) or (a.get("item") == b.get("item") and String(a.get("colour")) < String(b.get("colour"))))
		person["wardrobe"] = owned
		person["outfits"] = {"Everyday": outfit.duplicate(true)}
	var objects: Variant = world.get("objects")
	if not objects is Array or (objects as Array).is_empty():
		return d
	for obj: Variant in objects:
		if obj is Dictionary and obj.get("def_id") == "wardrobe":
			return d
	var next := SaveMigrations.number(world.get("next_id"), 1)
	for spot: Array in V16_WARDROBES:
		objects.append({"id": next, "def_id": "wardrobe", "origin": spot[0], "rotation": spot[1]})
		next += 1
	world["next_id"] = next
	return d


## v15 (T-0071): nobody has practised anything yet.
static func v14_to_v15(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary:
			person["skills"] = {}
	return d


## v14 (T-0067): nobody knows a clue or has found anything, and no reward has been taken.
static func v13_to_v14(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	d["world"]["looted_discoveries"] = []
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary:
			person["known_clues"] = []
			person["discoveries"] = []
	return d


## v13 (T-0066): no flat has been left empty yet.
static func v12_to_v13(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("lots", []) is Array:
		return d
	for lot: Variant in d["world"].get("lots", []):
		if lot is Dictionary:
			lot["vacant_since_day"] = -1
	return d


## v12 (T-0065): Café Wolke gets its counter (the barista's workplace), as in new towns.
## Saves that already have one, or have no objects (test rooms), are left alone.
static func v11_to_v12(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("objects") is Array:
		return d
	var world: Dictionary = d["world"]
	var objects: Array = world["objects"]
	if objects.is_empty():
		return d
	for obj: Variant in objects:
		if obj is Dictionary and obj.get("def_id") == "cafe_counter":
			return d
	var id := SaveMigrations.number(world.get("next_id"), 1)
	objects.append({"id": id, "def_id": "cafe_counter", "origin": [21, 13, 0], "rotation": 2})
	world["next_id"] = id + 1
	return d
