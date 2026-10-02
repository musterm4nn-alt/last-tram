extends TestCase
## T-0072: owned clothes, saved outfits, the wardrobe in every home and the outfit command.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


func _home_wardrobe(sim: Sim, person: Person) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "wardrobe" and lot != null and lot.id == person.home_lot_id:
			return obj
	return null


func _stand_at(sim: Sim, person: Person, obj: WorldObject) -> void:
	var cell := obj.slot_cell(content(), 0)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z


func _refusals(sim: Sim) -> Array:
	return sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"outfit_refused").map(func(e: Dictionary) -> String: return e["data"]["reason"])


func test_everyone_owns_their_clothes_and_more() -> void:
	var sim := _game()
	for person: Person in sim.world.people.values():
		for slot: String in person.outfit.items:
			var worn: WornItem = person.outfit.items[slot]
			assert_true(Wardrobe.owns(person, worn.clothing_id, worn.colour), "%s owns what they wear" % person.full_name())
		assert_true(person.wardrobe.size() > person.outfit.items.size(), "and a few more pieces")
		assert_eq(person.outfits["Everyday"].to_dict(), person.outfit.to_dict())
	var keys := sim.world.player().wardrobe.map(func(w: WornItem) -> String: return w.clothing_id + "/" + w.colour)
	var sorted := keys.duplicate()
	sorted.sort()
	assert_eq(keys, sorted, "kept sorted for stable saves")


func test_every_home_has_a_wardrobe_you_can_reach() -> void:
	var sim := _game()
	for lot: Lot in sim.world.lots.values():
		var place := content().place(lot.place_id)
		if place.kind != "home":
			continue
		var found: WorldObject = null
		for obj: WorldObject in sim.world.objects.values():
			if obj.def_id == "wardrobe" and Lots.lot_at(sim, obj.origin) == lot:
				found = obj
		assert_true(found != null, place.id + " has a wardrobe")
		if found != null:
			var slot := found.slot_cell(content(), 0)
			var anyone := Lots.free_cells(sim, place)
			assert_true(sim.world.grid.is_walkable(slot), place.id)
			assert_true(not sim.nav.find_path(anyone[anyone.size() - 1], slot).is_empty() or anyone[anyone.size() - 1] == slot, place.id + ": reachable")


func test_you_can_only_wear_what_you_own_at_your_wardrobe() -> void:
	var sim := _game()
	var player := sim.world.player()
	var outfit := player.outfit.copy()
	var spare: WornItem = null
	for item: WornItem in player.wardrobe:
		var def := content().clothing_def(item.clothing_id)
		var worn := player.outfit.get_item(def.slot)
		if worn == null or worn.clothing_id != item.clothing_id or worn.colour != item.colour:
			spare = item
			break
	var def := content().clothing_def(spare.clothing_id)
	outfit.put_on(def.slot, spare.clothing_id, spare.colour)
	sim.submit(ChangeOutfitCommand.new(player.id, outfit.to_dict(), ""))
	sim.step()
	assert_eq(_refusals(sim), ["not_at_wardrobe"])
	_stand_at(sim, player, _home_wardrobe(sim, player))
	var stolen := outfit.copy()
	stolen.put_on("top", "blouse" if player.outfit.get_item("top").clothing_id != "blouse" else "shirt", "white")
	if not Wardrobe.owns(player, stolen.get_item("top").clothing_id, "white"):
		sim.submit(ChangeOutfitCommand.new(player.id, stolen.to_dict(), ""))
		sim.step()
		assert_eq(_refusals(sim), ["not_owned"])
	var bare := outfit.copy()
	bare.take_off("bottom")
	sim.submit(ChangeOutfitCommand.new(player.id, bare.to_dict(), ""))
	sim.step()
	assert_eq(_refusals(sim), ["not_owned"], "top, bottom and feet are always worn")
	sim.submit(ChangeOutfitCommand.new(player.id, outfit.to_dict(), "Going out"))
	sim.step()
	assert_eq(player.outfit.to_dict(), outfit.to_dict(), "changed")
	assert_eq(player.outfits["Going out"].to_dict(), outfit.to_dict(), "and saved")
	sim.submit(ChangeOutfitCommand.new(player.id, outfit.to_dict(), "Party"))
	sim.step()
	assert_eq(_refusals(sim), ["bad_name"])


func test_change_clothes_opens_the_wardrobe_screen() -> void:
	var sim := _game()
	var player := sim.world.player()
	var wardrobe := _home_wardrobe(sim, player)
	_stand_at(sim, player, wardrobe)
	sim.submit(QueueInteractionCommand.new(player.id, "change_clothes", wardrobe.id))
	sim.run_minutes(3)
	var asked := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"screen_requested")
	assert_eq(asked.size(), 1)
	assert_eq(asked[0]["data"], {"person_id": player.id, "screen": "wardrobe"})
	var other: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id and person.home_lot_id > 0:
			other = person
			break
	assert_eq(Requirements.check(sim, player, content().interaction("change_clothes"), _home_wardrobe(sim, other).id), "private", "only your own")


func test_wardrobes_survive_saves_and_old_saves_migrate() -> void:
	var sim := _game()
	var player := sim.world.player()
	Wardrobe.add(player, "blazer", "black")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	assert_true(Wardrobe.owns(loaded.world.player(), "blazer", "black"))
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v15_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	var old_player := old.world.player()
	for slot: String in old_player.outfit.items:
		var worn: WornItem = old_player.outfit.items[slot]
		assert_true(Wardrobe.owns(old_player, worn.clothing_id, worn.colour))
	assert_true(_home_wardrobe(old, old_player) != null, "old towns get their wardrobes")
	var command := CommandRegistry.decode(CommandRegistry.encode(ChangeOutfitCommand.new(3, {"top": {"item": "t_shirt", "colour": "black"}}, "Work")))
	assert_true(command is ChangeOutfitCommand and (command as ChangeOutfitCommand).save_as == "Work")
