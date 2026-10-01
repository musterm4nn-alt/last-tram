extends TestCase
## T-0054: cash, the bank account, the ledger and starting money.

const ROOM: PackedStringArray = ["#####", "#@..#", "#####"]
const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"


func _sim() -> Sim:
	return SimFactory.from_rows(content(), ROOM)


## The player of `sim` with exactly this cash and bank (as starting money).
func _with(sim: Sim, cash: int, bank: int) -> Person:
	var player := sim.world.player()
	Money.earn(sim, player, cash, "start", Money.CASH)
	Money.earn(sim, player, bank, "start", Money.BANK)
	sim.events.drain()
	return player


func _money_events(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == &"money_changed":
			out.append(event["data"])
	return out


func test_economy_content_loads() -> void:
	var economy := content().economy
	assert_eq(economy.player_start_cash, 4000)
	assert_eq(economy.player_start_bank, 30000)
	assert_eq(economy.resident_cash, Vector2i(1000, 8000))
	assert_eq(economy.resident_bank, Vector2i(20000, 300000))


func test_spend_uses_cash_first_then_the_card() -> void:
	var sim := _sim()
	var player := _with(sim, 1000, 5000)
	assert_true(Money.spend(sim, player, 400, "purchase", "have_a_drink"))
	assert_eq(player.wallet.cash, 600)
	assert_eq(player.wallet.bank, 5000)
	assert_true(Money.spend(sim, player, 1000, "purchase"))
	assert_eq(player.wallet.cash, 0, "cash goes first")
	assert_eq(player.wallet.bank, 4600, "the card pays the rest")
	assert_eq(sim.world.ledger.sinks["purchase"], 1400)


func test_spend_splits_cash_and_card() -> void:
	var sim := _sim()
	var player := _with(sim, 200, 300)
	assert_true(Money.spend(sim, player, 400, "purchase", "eat_doener"))
	assert_eq(player.wallet.cash, 0)
	assert_eq(player.wallet.bank, 100)
	var events := _money_events(sim)
	assert_eq(events.size(), 2)
	assert_eq(events[0]["account"], "cash")
	assert_eq(events[0]["amount"], -200)
	assert_eq(events[1]["account"], "bank")
	assert_eq(events[1]["amount"], -200)
	assert_eq(events[1]["detail"], "eat_doener")


func test_cannot_spend_more_than_you_have() -> void:
	var sim := _sim()
	var player := _with(sim, 200, 100)
	assert_false(Money.spend(sim, player, 301, "purchase"))
	assert_eq(player.wallet.total(), 300)
	assert_eq(player.wallet.statement.size(), 2, "only the starting money")
	assert_true(_money_events(sim).is_empty())
	assert_false(sim.world.ledger.sinks.has("purchase"))


func test_charge_takes_only_from_the_bank() -> void:
	var sim := _sim()
	var player := _with(sim, 10000, 500)
	assert_false(Money.charge(sim, player, 600, "rent"), "cash doesn't pay the rent")
	assert_eq(player.wallet.total(), 10500)
	assert_true(Money.charge(sim, player, 500, "rent"))
	assert_eq(player.wallet.cash, 10000)
	assert_eq(player.wallet.bank, 0)
	assert_eq(sim.world.ledger.sinks["rent"], 500)


func test_withdraw_moves_bank_to_cash_outside_the_ledger() -> void:
	var sim := _sim()
	var player := _with(sim, 0, 3000)
	var balance := sim.world.ledger.balance()
	assert_true(Money.withdraw(sim, player, 2000))
	assert_eq(player.wallet.cash, 2000)
	assert_eq(player.wallet.bank, 1000)
	assert_eq(sim.world.ledger.balance(), balance)
	assert_eq(player.wallet.statement.back()["reason"], "atm")
	assert_false(Money.withdraw(sim, player, 1001))
	assert_false(Money.withdraw(sim, player, 0))


func test_bad_amounts_and_reasons_change_nothing() -> void:
	var sim := _sim()
	var player := _with(sim, 1000, 1000)
	assert_false(Money.earn(sim, player, 0, "wage"))
	assert_false(Money.earn(sim, player, -5, "wage"))
	assert_false(Money.earn(sim, player, 100, "purchase"), "purchase is not a source")
	assert_false(Money.earn(sim, player, 100, "wage", "sock"))
	assert_false(Money.spend(sim, player, 100, "wage"), "wage is not a sink")
	assert_false(Money.spend(sim, player, -100, "purchase"))
	assert_false(Money.charge(sim, player, 100, "start"))
	assert_eq(player.wallet.total(), 2000)
	assert_true(_money_events(sim).is_empty())
	assert_eq(sim.world.ledger.balance(), 2000)


func test_money_is_conserved() -> void:
	var sim := _sim()
	var people: Array[Person] = [sim.world.player()]
	for i: int in 4:
		people.append(SimFactory.spawn_person(sim, Vector3i(2, 1, 0), CharacterSpec.default_player(content())))
	var rng := RandomNumberGenerator.new()
	rng.seed = 54
	for i: int in 500:
		var person: Person = people[rng.randi_range(0, people.size() - 1)]
		var amount := rng.randi_range(-100, 5000)
		match rng.randi_range(0, 3):
			0:
				Money.earn(sim, person, amount, Money.SOURCES[rng.randi_range(0, Money.SOURCES.size() - 1)], [Money.CASH, Money.BANK][rng.randi_range(0, 1)])
			1:
				Money.spend(sim, person, amount, Money.SINKS[rng.randi_range(0, Money.SINKS.size() - 1)])
			2:
				Money.charge(sim, person, amount, "rent")
			3:
				Money.withdraw(sim, person, amount)
		assert_eq(Money.held(sim.world), sim.world.ledger.balance(), "after operation %d" % i)
		for p: Person in people:
			assert_true(p.wallet.cash >= 0 and p.wallet.bank >= 0, "no wallet goes negative")


func test_statement_keeps_the_newest_twenty() -> void:
	var sim := _sim()
	var player := sim.world.player()
	for i: int in 25:
		Money.earn(sim, player, 100 + i, "found", Money.CASH)
	assert_eq(player.wallet.statement.size(), Wallet.STATEMENT_SIZE)
	assert_eq(player.wallet.statement[0]["amount"], 105)
	assert_eq(player.wallet.statement.back()["amount"], 124)


func test_money_changed_reports_the_new_balances() -> void:
	var sim := _sim()
	var player := _with(sim, 500, 700)
	Money.earn(sim, player, 1200, "wage", Money.BANK, "office_clerk")
	var events := _money_events(sim)
	assert_eq(events.size(), 1)
	var data := events[0]
	assert_eq(data["person_id"], player.id)
	assert_eq(data["amount"], 1200)
	assert_eq(data["account"], "bank")
	assert_eq(data["reason"], "wage")
	assert_eq(data["detail"], "office_clerk")
	assert_eq(data["cash"], 500)
	assert_eq(data["bank"], 1900)


func test_new_game_gives_everyone_starting_money() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := content().economy
	var player := sim.world.player()
	assert_eq(player.wallet.cash, economy.player_start_cash)
	assert_eq(player.wallet.bank, economy.player_start_bank)
	for person: Person in sim.world.people.values():
		if person.id == player.id:
			continue
		assert_true(person.wallet.cash >= economy.resident_cash.x and person.wallet.cash <= economy.resident_cash.y)
		assert_true(person.wallet.bank >= economy.resident_bank.x and person.wallet.bank <= economy.resident_bank.y)
		assert_eq(person.wallet.cash % 100, 0, "whole euros")
		assert_eq(person.wallet.bank % 100, 0, "whole euros")
	assert_eq(Money.held(sim.world), sim.world.ledger.balance())
	assert_eq(sim.world.ledger.sources["start"], Money.held(sim.world))
	assert_true(sim.world.ledger.sinks.is_empty())


func test_starting_money_is_deterministic() -> void:
	var a := SimFactory.new_game(content(), 5)
	var b := SimFactory.new_game(content(), 5)
	for id: int in a.world.people:
		assert_eq(a.world.people[id].wallet.to_dict(), b.world.people[id].wallet.to_dict())
	var c := SimFactory.new_game(content(), 6)
	assert_ne(Money.held(a.world), Money.held(c.world), "another seed, another town")


func test_money_survives_save_and_load() -> void:
	var sim := SimFactory.new_game(content(), 3)
	var player := sim.world.player()
	Money.spend(sim, player, 4550, "purchase", "eat_doener")
	var text := SaveCodec.to_json(sim)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(text, content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	assert_eq(loaded.world.player().wallet.to_dict(), player.wallet.to_dict())
	assert_eq(loaded.world.ledger.to_dict(), sim.world.ledger.to_dict())
	assert_eq(SaveCodec.to_json(loaded), text)


func test_v3_saves_get_starting_money() -> void:
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content(), errors)
	assert_true(sim != null, "%s" % [errors])
	if sim == null:
		return
	for person: Person in sim.world.people.values():
		assert_eq(person.wallet.cash, 4000)
		assert_eq(person.wallet.bank, 30000)
	assert_eq(Money.held(sim.world), sim.world.ledger.balance())


func test_format() -> void:
	assert_eq(Money.format(0), "€0.00")
	assert_eq(Money.format(1250), "€12.50")
	assert_eq(Money.format(123405), "€1,234.05")
	assert_eq(Money.format(-300), "−€3.00")
	assert_eq(Money.format(123456789), "€1,234,567.89")
