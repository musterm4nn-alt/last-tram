extends TestCase
## T-0067: discoveries as content, learning clues, uncovering, once-per-world rewards, saves.

const BROKEN: String = "res://tests/fixtures/discoveries_broken"


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.events.drain()
	return sim


func _events(sim: Sim, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type:
			out.append(event["data"])
	return out


func test_discovery_content_loads() -> void:
	var def := content().discovery("fountain_coins")
	assert_true(def != null)
	assert_eq(def.place_id, "altmarkt")
	assert_eq(def.from_minute, 22 * 60)
	assert_eq(def.to_minute, 4 * 60)
	assert_true(def.in_window(23 * 60) and def.in_window(60) and not def.in_window(12 * 60), "wraps past midnight")
	assert_eq(def.effects.size(), 2)
	assert_eq(def.effects[0].kind, DiscoveryEffect.MONEY)
	assert_eq(def.effects[0].cents, 340)


func test_broken_discoveries_are_reported() -> void:
	var db := ContentDB.load_default()
	var reader := ContentReader.new()
	DiscoveryLoader.load(db, reader, BROKEN)
	var all := "\n".join(reader.errors)
	for expected: String in ["'bad_place': unknown place 'nowhere_at_all'", "'bad_time': 'from' must be a time",
			"'bad_level': 'level' 2 is not the level of 'altmarkt'", "'bad_effect': unknown effect kind 'item'",
			"'bad_money': a money effect needs 'cents' > 0", "discovery 'bad_unlock': unlock_interaction 'sleep' must be",
			"discovery 'unreachable': needs its clue"]:
		assert_true(all.contains(expected), "missing: %s\n%s" % [expected, all])
	var linked := ContentDB.load_default()
	linked.interaction("sit").requires_discovery = "no_such_secret"
	var link_reader := ContentReader.new()
	DiscoveryLoader.check_links(linked, link_reader)
	assert_true("\n".join(link_reader.errors).contains("interaction 'sit': unknown discovery 'no_such_secret' in 'requires_discovery'"))


func test_learn_and_uncover() -> void:
	var sim := _game()
	var player := sim.world.player()
	assert_true(Discoveries.learn_clue(sim, player, "fountain_coins", "talk", 99))
	assert_false(Discoveries.learn_clue(sim, player, "fountain_coins", "talk", 99), "once")
	assert_false(Discoveries.learn_clue(sim, player, "no_such_secret", "talk"))
	assert_eq(player.known_clues, PackedStringArray(["fountain_coins"]))
	var learned := _events(sim, &"clue_learned")
	assert_eq(learned.size(), 1)
	assert_eq(learned[0], {"person_id": player.id, "discovery_id": "fountain_coins", "source": "talk", "source_id": 99})
	var cash := player.wallet.cash
	assert_true(Discoveries.uncover(sim, player, "fountain_coins"))
	assert_false(Discoveries.uncover(sim, player, "fountain_coins"), "found already")
	assert_eq(player.known_clues, PackedStringArray(), "a lead becomes a find")
	assert_eq(player.discoveries, PackedStringArray(["fountain_coins"]))
	assert_eq(player.wallet.cash, cash + 340)
	assert_eq(sim.world.ledger.sources.get("found", 0), 340, "the ledger knows where it came from")
	assert_true(player.memories.any(func(m: Memory) -> bool: return m.kind == "fountain_coins" and m.place_id == "altmarkt"))
	var found := _events(sim, &"discovery_uncovered")
	assert_eq(found.size(), 1)
	assert_eq(found[0]["place_id"], "altmarkt")
	assert_false(Discoveries.learn_clue(sim, player, "fountain_coins", "talk"), "no clue for what you found")


func test_money_only_once_per_world() -> void:
	var sim := _game()
	var first := sim.world.player()
	var second: Person = null
	for person: Person in sim.world.people.values():
		if person.id != first.id:
			second = person
			break
	Discoveries.uncover(sim, first, "fountain_coins")
	var cash := second.wallet.cash
	assert_true(Discoveries.uncover(sim, second, "fountain_coins"), "they find the place too")
	assert_eq(second.wallet.cash, cash, "but the coins are gone")
	assert_eq(sim.world.looted_discoveries, PackedStringArray(["fountain_coins"]))
	assert_eq(sim.world.ledger.sources.get("found", 0), 340)


func test_eligibility_and_effects() -> void:
	var sim := _game()
	var player := sim.world.player()
	var def := content().discovery("fountain_coins")
	sim.clock.tick = SimClock.ticks_for(0, 23)
	assert_true(Discoveries.eligible(sim, player, def, "altmarkt"))
	assert_false(Discoveries.eligible(sim, player, def, "kneipe_anker"), "wrong place")
	sim.clock.tick = SimClock.ticks_for(1, 12)
	assert_false(Discoveries.eligible(sim, player, def, "altmarkt"), "wrong time")
	sim.clock.tick = SimClock.ticks_for(1, 3)
	player.level = 1
	assert_false(Discoveries.eligible(sim, player, def, "altmarkt"), "wrong floor")
	player.level = 0
	Discoveries.uncover(sim, player, "fountain_coins")
	assert_false(Discoveries.eligible(sim, player, def, "altmarkt"), "found already")
	# A contact and a moodlet, through a made-up discovery.
	var extra := DiscoveryDef.new()
	extra.id = "test_extra"
	extra.place_id = "spaeti_kaya"
	var contact := DiscoveryEffect.new()
	contact.kind = DiscoveryEffect.CONTACT
	contact.place_id = "spaeti_kaya"
	var mood := DiscoveryEffect.new()
	mood.kind = DiscoveryEffect.MOODLET
	mood.moodlet_id = "nice_coffee"
	extra.effects.append_array([contact, mood])
	sim.content.discoveries["test_extra"] = extra
	Discoveries.uncover(sim, player, "test_extra")
	sim.content.discoveries.erase("test_extra")
	var clerk := Jobs.holder(sim.world, "spaeti_clerk", 0)
	assert_true(Social.relationship(player, clerk.id).familiarity >= Discoveries.CONTACT_FAMILIARITY, "you know the Späti staff now")
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "nice_coffee"))


func test_secret_interactions_need_the_discovery() -> void:
	var sim := _game()
	var player := sim.world.player()
	var def := content().interaction("sit")
	var chair := 0
	for obj: WorldObject in sim.world.objects.values():
		if Interactions.offered_by(sim, obj.id).has(def):
			chair = obj.id
			break
	def.requires_discovery = "fountain_coins"
	var hidden := Requirements.check(sim, player, def, chair)
	Discoveries.uncover(sim, player, "fountain_coins")
	var open := Requirements.check(sim, player, def, chair)
	def.requires_discovery = ""
	assert_eq(hidden, "unknown_secret")
	assert_true(Requirements.HIDDEN.has("unknown_secret"), "not even shown in the menu")
	assert_ne(open, "unknown_secret")


func test_discoveries_survive_saves() -> void:
	var sim := _game()
	var player := sim.world.player()
	Discoveries.uncover(sim, player, "fountain_coins")
	var other: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id:
			other = person
			break
	Discoveries.learn_clue(sim, other, "fountain_coins", "talk", player.id)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	assert_eq(loaded.world.player().discoveries, PackedStringArray(["fountain_coins"]))
	assert_eq(loaded.world.get_person(other.id).known_clues, PackedStringArray(["fountain_coins"]))
	assert_eq(loaded.world.looted_discoveries, PackedStringArray(["fountain_coins"]))
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	var data := SaveCodec.to_dict(sim)
	data["world"]["people"][0]["known_clues"] = ["gone_from_content"]
	data["world"]["looted_discoveries"] = ["gone_from_content"]
	var trimmed := SaveCodec.from_dict(data, content(), errors)
	assert_eq(trimmed.world.get_person(int(data["world"]["people"][0]["id"])).known_clues, PackedStringArray(), "unknown ids are dropped")
	assert_eq(trimmed.world.looted_discoveries, PackedStringArray())
	var old := SaveMigrations.migrate({"save_version": 13, "world": {"people": [{"id": 1}]}})
	assert_eq(old["world"]["people"][0]["known_clues"], [])
	assert_eq(old["world"]["looted_discoveries"], [])
