extends TestCase
## T-0096: picking someone's pocket takes half their cash (at most €40) unless they notice;
## a victim who notices is a witness, one who doesn't never knew who it was.

const ROWS: PackedStringArray = [
	"::::::",
	":@::::",
	"::::::",
]


func _sim(seed_value: int = 1) -> Sim:
	var sim := SimFactory.from_rows(content(), ROWS, seed_value)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	var player := sim.world.player()
	player.free_will = false
	player.wallet.cash = 0
	player.wallet.bank = 0
	sim.events.drain()
	return sim


## An adult with `cash` cents standing on `cell`, without free will.
func _victim(sim: Sim, cell: Vector3i, cash: int) -> Person:
	var person := Person.new()
	person.id = sim.world.new_id()
	person.first_name = "Anna"
	person.last_name = "Weber"
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.free_will = false
	person.wallet.cash = cash
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = need_def.start
	sim.world.add_person(person)
	return person


func _events(sim: Sim, type: StringName) -> Array:
	return sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == type)


func test_pickpocketing_content() -> void:
	var def := content().interaction("pickpocket")
	assert_eq(def.target, "person")
	assert_eq(def.crime, "pickpocketing")
	assert_eq(def.social.kind, "sneaky")
	var crime := content().crime("pickpocketing")
	assert_eq(crime.steal_share, 0.5)
	assert_eq(crime.steal_max, 4000)
	assert_eq(content().crime("shoplifting").steal_share, 0.0, "shoplifting takes goods, not cash")
	var sim := _sim()
	var victim := _victim(sim, Vector3i(2, 1, 0), 0)
	assert_has(Interactions.offered_by_person(sim, sim.world.player_id, victim.id), def, "on everyone's menu")


func test_unnoticed_takes_half_the_cash_up_to_the_cap() -> void:
	var sim := _sim()
	var thief := sim.world.player()
	var victim := _victim(sim, Vector3i(2, 1, 0), 3000)
	var balance := sim.world.ledger.balance()
	var incident := Crimes.commit(sim, thief, "pickpocketing", victim.id, "success")
	assert_eq(incident.stolen, 1500)
	assert_eq(victim.wallet.cash, 1500)
	assert_eq(thief.wallet.cash, 1500)
	assert_eq(sim.world.ledger.balance(), balance, "money moved, none made")
	assert_eq(String(victim.wallet.statement[-1]["reason"]), Money.THEFT)
	assert_false(incident.witnesses.has(victim.id), "they didn't notice")
	var stolen := _events(sim, &"stolen")
	assert_eq(stolen.size(), 1)
	assert_eq(int(stolen[0]["data"]["amount"]), 1500)
	var rich := _victim(sim, Vector3i(0, 1, 0), 20000)
	assert_eq(Crimes.commit(sim, thief, "pickpocketing", rich.id, "success").stolen, 4000, "at most €40")


func test_noticed_takes_nothing_and_the_victim_is_a_witness() -> void:
	var sim := _sim()
	var victim := _victim(sim, Vector3i(2, 1, 0), 3000)
	var incident := Crimes.commit(sim, sim.world.player(), "pickpocketing", victim.id, "fail")
	assert_eq(incident.stolen, 0)
	assert_eq(victim.wallet.cash, 3000)
	assert_true(incident.witnesses.has(victim.id), "caught in the act")
	assert_eq(_events(sim, &"stolen"), [])


func test_empty_pockets() -> void:
	var sim := _sim()
	var victim := _victim(sim, Vector3i(2, 1, 0), 0)
	var incident := Crimes.commit(sim, sim.world.player(), "pickpocketing", victim.id, "success")
	assert_eq(incident.stolen, 0)
	var stolen := _events(sim, &"stolen")
	assert_eq(stolen.size(), 1, "the thief still finds out")
	assert_eq(int(stolen[0]["data"]["amount"]), 0)


func test_trust_makes_it_easier() -> void:
	var sim := _sim()
	var thief := sim.world.player()
	var victim := _victim(sim, Vector3i(2, 1, 0), 0)
	var def := content().interaction("pickpocket")
	assert_near(Conversations.acceptance(sim, thief, victim, def), Conversations.logistic(0.4), 0.001, "a stranger")
	Social.set_values(victim, thief.id, {"trust": 50.0}, sim.clock.tick)
	assert_near(Conversations.acceptance(sim, thief, victim, def), Conversations.logistic(1.4), 0.001, "trusted")
	Social.set_values(victim, thief.id, {"trust": -50.0}, sim.clock.tick)
	assert_near(Conversations.acceptance(sim, thief, victim, def), Conversations.logistic(-0.6), 0.001, "distrusted")


func test_picking_pockets_in_play() -> void:
	var unnoticed := 0
	for seed_value: int in range(1, 41):
		var sim := _sim(seed_value)
		var thief := sim.world.player()
		var victim := _victim(sim, Vector3i(3, 1, 0), 3000)
		sim.submit(QueueInteractionCommand.new(thief.id, "pickpocket", victim.id))
		sim.run_minutes(3)
		var mine := Crimes.committed_by(sim, thief.id)
		assert_eq(mine.size(), 1, "seed %d: walked over and did it" % seed_value)
		if mine.size() != 1:
			continue
		var incident := mine[0]
		assert_eq(incident.target_id, victim.id)
		if incident.stolen > 0:
			unnoticed += 1
			assert_eq(incident.stolen, 1500)
			assert_false(incident.witnesses.has(victim.id))
			assert_false(victim.relationships.has(thief.id), "seed %d: the victim never met the thief" % seed_value)
			assert_eq(victim.memories.size(), 0)
		else:
			assert_true(incident.witnesses.has(victim.id), "seed %d" % seed_value)
			assert_true(victim.relationships[thief.id].friendship <= -20.0)
			assert_true(victim.moodlets.any(func(m: Moodlet) -> bool: return m.id == "nearly_robbed"))
	assert_true(unnoticed > 14 and unnoticed < 34, "%d of 40 unnoticed (expected about 24)" % unnoticed)


func test_stolen_cash_survives_save_and_load() -> void:
	var sim := _sim()
	var victim := _victim(sim, Vector3i(2, 1, 0), 3000)
	var incident := Crimes.commit(sim, sim.world.player(), "pickpocketing", victim.id, "success")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(loaded.world.incidents[incident.id].stolen, 1500)
	var d: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	d["world"]["incidents"][0]["stolen"] = -1
	assert_eq(SaveCodec.from_json(JSON.stringify(d), content(), errors), null)
	assert_true("\n".join(errors).contains("world.incidents[].stolen"))


func test_bad_theft_content_is_reported() -> void:
	var reader := ContentReader.new()
	CrimeLoader.load(ContentDB.new(), reader, "res://tests/fixtures/crimes_broken/bad_theft.json")
	assert_true("\n".join(reader.errors).contains("steals_cash needs a share above 0 and up to 1"), "\n".join(reader.errors))


## Free will offers it only to the tempted (T-0097: test_npc_crime.gd); an honest resident
## with money never considers it.
func test_free_will_never_picks_a_pocket_for_the_honest() -> void:
	var sim := _sim()
	var thief := _victim(sim, Vector3i(2, 1, 0), 0)
	thief.wallet.bank = 10000
	_victim(sim, Vector3i(3, 1, 0), 3000)
	thief.needs["social"] = 0.0
	for option: AutonomyOption in Autonomy.candidates(sim, thief):
		assert_ne(option.interaction_id, "pickpocket")
