class_name CrimeNotices
extends RefCounted
## The HUD's words for crime and the police (T-0093 to T-0098): what the player did, what was
## done to them, and what the police are up to. Pure helpers; Hud.notice_for_event asks first.


## The notice a crime or police event deserves for the player ("" for none).
static func notice(event: Dictionary, player_id: int, sim: Sim) -> String:
	var data: Dictionary = event.get("data", {})
	if event.get("type") == &"stolen":
		return theft(data, player_id, sim)
	if int(data.get("person_id", -1)) != player_id:
		return ""
	match event.get("type"):
		&"crime_committed":
			return "You're trespassing" if data.get("crime_id") == Trespass.CRIME_ID else ""
		&"crime_reported":
			return "Someone called the police on you"
		&"police_dispatched":
			return "The police are looking for you"
		&"police_searching":
			return "The police lost sight of you"
		&"police_gave_up":
			return "The police gave up looking for you"
		&"police_spotted":
			return "The police spotted you again"
		&"arrested":
			return "Arrested: fined %s. It's on your record now." % Money.format(int(data.get("fine", 0)))
	return ""


## Words for a sneaky act (T-0096): only when it was noticed ("Anna Weber caught you!", or
## "Anna Weber tried to rob you!"); a theft that went unnoticed speaks through &"stolen".
static func sneaky(data: Dictionary, player_id: int, sim: Sim) -> String:
	if data.get("outcome") == "success":
		return ""
	var actor_id := int(data.get("actor_id", 0))
	var target_id := int(data.get("target_id", 0))
	var other := sim.world.get_person(target_id if actor_id == player_id else actor_id) if sim != null else null
	var who := other.full_name() if other != null else "Someone"
	if actor_id == player_id:
		return "%s caught you!" % who
	return "%s tried to rob you!" % who if target_id == player_id else ""


## Words for a theft (T-0096 pickpocketing, T-0098 burglary) the player did or suffered.
static func theft(data: Dictionary, player_id: int, sim: Sim) -> String:
	var amount := int(data.get("amount", 0))
	var burglary: bool = data.get("crime_id") == "burglary"
	if int(data.get("victim_id", 0)) == player_id:
		if amount <= 0:
			return ""
		return ("Someone broke into your home: %s gone" if burglary else "Someone picked your pocket: %s gone") % Money.format(amount)
	if int(data.get("person_id", 0)) != player_id:
		return ""
	if amount <= 0:
		return "Nothing worth taking" if burglary else "Their pockets were empty"
	var victim := sim.world.get_person(int(data.get("victim_id", 0))) if sim != null else null
	var whose := victim.full_name() if victim != null else "them"
	return ("You found %s at %s's" if burglary else "You lifted %s from %s") % [Money.format(amount), whose]
