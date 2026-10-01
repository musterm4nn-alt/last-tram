class_name TierSystem
extends SimSystem
## Decides who is simulated in full detail (T-0042, D28). Every CHECK_MINUTES: the player is
## active; in "full" mode everyone is; otherwise people within World.tiers.active_radius of
## the player become active and those beyond demote_radius become background (hysteresis),
## and anyone talking with an active person is active too. Background people keep all their
## data and rules but ActionSystem and MovementSystem update them once per game minute
## instead of every step. Runs first in the minute.

const CHECK_MINUTES: int = 2
## Each floor between two people counts as this many cells of distance.
const LEVEL_DISTANCE: float = 10.0


func on_minute(sim: Sim) -> void:
	if sim.clock.total_minutes() % CHECK_MINUTES != 0:
		return
	var player := sim.world.player()
	var settings := sim.world.tiers
	for person: Person in sim.world.people.values():
		var background := false
		if settings.mode != TierSettings.FULL and player != null and person.id != player.id:
			var distance := distance_to(person, player)
			background = distance > settings.active_radius if person.background else distance > settings.demote_radius
		if background != person.background:
			person.background = background
			sim.emit_event(&"tier_changed", {"person_id": person.id, "background": background})
	# Conversations with active people happen in full detail on both sides.
	for person: Person in sim.world.people.values():
		if person.background or person.action_queue.is_empty():
			continue
		var other := sim.world.get_person(person.action_queue[0].target_id)
		if other != null and other.background:
			other.background = false
			sim.emit_event(&"tier_changed", {"person_id": other.id, "background": false})


## Cells between two people, with LEVEL_DISTANCE per floor apart.
static func distance_to(a: Person, b: Person) -> float:
	return a.pos.distance_to(b.pos) + absi(a.level - b.level) * LEVEL_DISTANCE
