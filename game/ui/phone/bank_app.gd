class_name BankApp
extends RefCounted
## The phone's Bank app (T-0063): balances, what the week costs, what is owed, and the latest
## money changes in words. Pure helpers (tests call them); Phone draws the lines.

const REASONS: Dictionary = {
	"start": "Savings", "wage": "Wages", "benefit": "Benefit", "pension": "Pension",
	"found": "Found", "rent": "Rent", "bill": "Bills", "atm": "ATM", "fine": "Fine",
}


## The app's lines for `player_id`, newest money changes first.
static func lines(sim: Sim, player_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	var person := sim.world.get_person(player_id)
	if person == null:
		return out
	out.append("Cash %s" % Money.format(person.wallet.cash))
	out.append("Bank %s" % Money.format(person.wallet.bank))
	var household := Groceries.home_household(sim, person)
	if household != null:
		var lot: Lot = sim.world.lots[household.home_lot_id]
		out.append("Rent %s + bills %s, Mondays" % [Money.format(Housing.rent_share(sim, person)),
			Money.format(sim.content.economy.bills_week / household.member_ids.size())])
		if lot.arrears > 0:
			out.append("Owed: %s (%d weeks behind)" % [Money.format(lot.arrears), lot.weeks_behind])
	if person.job != null and person.job.unpaid > 0:
		out.append("Wages due Friday: %s" % Money.format(person.job.unpaid))
	out.append("")
	var statement := person.wallet.statement.duplicate()
	statement.reverse()
	for entry: Dictionary in statement:
		var when := SimClock.new()
		when.tick = int(entry["tick"])
		out.append("%s  %s  %s" % [when.format(), entry_text(sim.content, entry), Money.format(int(entry["amount"]))])
	return out


## What a statement entry was for: an interaction's or job's name, or the reason in words
## ("Rent", "Wages").
static func entry_text(content: ContentDB, entry: Dictionary) -> String:
	var detail := String(entry.get("detail", ""))
	var reason := String(entry.get("reason", ""))
	var interaction := content.interaction(detail)
	if interaction != null:
		return interaction.name
	var job := content.job(detail)
	if job != null and reason == "wage":
		return "Wages (%s)" % job.name
	return String(REASONS.get(reason, reason.capitalize()))
