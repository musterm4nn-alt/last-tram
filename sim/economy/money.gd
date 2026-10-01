class_name Money
extends RefCounted
## Every change to anyone's money goes through here (D29). It updates the wallet, the world's
## ledger and the person's statement, and emits &"money_changed" {person_id, amount (signed),
## account, reason, detail, cash, bank}. Amounts are euro cents. Static, no state.

const CASH: String = "cash"
const BANK: String = "bank"
## Reasons money enters people's hands (ledger sources).
const SOURCES: PackedStringArray = ["start", "wage", "benefit", "pension", "found"]
## Reasons money leaves people's hands (ledger sinks).
const SINKS: PackedStringArray = ["purchase", "rent", "bill"]
## The reason on both statement entries of a withdrawal (it moves money, the ledger stays).
const ATM: String = "atm"


## Adds `amount` to the account from outside (wages, benefit...). False, with no change, for a
## non-positive amount, a reason not in SOURCES, or an unknown account.
static func earn(sim: Sim, person: Person, amount: int, reason: String, account: String = BANK, detail: String = "") -> bool:
	if person == null or amount <= 0 or not SOURCES.has(reason) or not account in [CASH, BANK]:
		return false
	_change(sim, person, account, amount, reason, detail)
	sim.world.ledger.add_source(reason, amount)
	return true


## Pays `amount` with cash first and the card (bank) for the rest. False, with no change at
## all, for a non-positive amount, a reason not in SINKS, or not enough money.
static func spend(sim: Sim, person: Person, amount: int, reason: String, detail: String = "") -> bool:
	if person == null or amount <= 0 or not SINKS.has(reason) or not can_afford(person, amount):
		return false
	var from_cash := mini(person.wallet.cash, amount)
	if from_cash > 0:
		_change(sim, person, CASH, -from_cash, reason, detail)
	if amount > from_cash:
		_change(sim, person, BANK, from_cash - amount, reason, detail)
	sim.world.ledger.add_sink(reason, amount)
	return true


## Like spend, but from the bank only (rent, bills): false unless the bank holds `amount`.
static func charge(sim: Sim, person: Person, amount: int, reason: String, detail: String = "") -> bool:
	if person == null or amount <= 0 or not SINKS.has(reason) or person.wallet.bank < amount:
		return false
	_change(sim, person, BANK, -amount, reason, detail)
	sim.world.ledger.add_sink(reason, amount)
	return true


## The cash machine: moves `amount` from the bank to cash. The ledger doesn't change. False
## unless 0 < amount <= bank.
static func withdraw(sim: Sim, person: Person, amount: int) -> bool:
	if person == null or amount <= 0 or person.wallet.bank < amount:
		return false
	_change(sim, person, BANK, -amount, ATM, "")
	_change(sim, person, CASH, amount, ATM, "")
	return true


static func can_afford(person: Person, amount: int) -> bool:
	return person.wallet.total() >= amount


## All the money people hold (cash and bank). Always equals world.ledger.balance().
static func held(world: World) -> int:
	var total := 0
	for person: Person in world.people.values():
		total += person.wallet.total()
	return total


## New games only: the player gets the content's player_start; everyone else, in ascending id
## order, a random cash and then bank amount in whole euros from the "money" stream.
static func give_start(sim: Sim) -> void:
	var economy := sim.content.economy
	var rng := sim.rng.stream("money")
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		var person: Person = sim.world.people[id]
		var cash := economy.player_start_cash
		var bank := economy.player_start_bank
		if id != sim.world.player_id:
			cash = rng.randi_range(economy.resident_cash.x / 100, economy.resident_cash.y / 100) * 100
			bank = rng.randi_range(economy.resident_bank.x / 100, economy.resident_bank.y / 100) * 100
		earn(sim, person, cash, "start", CASH)
		earn(sim, person, bank, "start", BANK)


## "€12.50", "€1,234.05", "−€3.00" (with a real minus sign).
static func format(cents: int) -> String:
	var whole := absi(cents) / 100
	var digits := str(whole)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return "%s€%s%s.%02d" % ["−" if cents < 0 else "", digits, grouped, absi(cents) % 100]


static func _change(sim: Sim, person: Person, account: String, amount: int, reason: String, detail: String) -> void:
	var wallet := person.wallet
	if account == CASH:
		wallet.cash += amount
	else:
		wallet.bank += amount
	wallet.statement.append({"tick": sim.clock.tick, "amount": amount, "account": account, "reason": reason, "detail": detail})
	if wallet.statement.size() > Wallet.STATEMENT_SIZE:
		wallet.statement.remove_at(0)
	sim.emit_event(&"money_changed", {
		"person_id": person.id, "amount": amount, "account": account, "reason": reason,
		"detail": detail, "cash": wallet.cash, "bank": wallet.bank,
	})
