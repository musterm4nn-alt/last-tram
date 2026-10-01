class_name SocialSystem
extends SimSystem
## Time passing for relationships, memories and moodlets (T-0037): ended moodlets go every
## minute; at midnight, relationships without recent contact drift towards neutral and
## memories fade (Social's constants).


func on_minute(sim: Sim) -> void:
	var midnight := sim.clock.minute_of_day() == 0
	for person: Person in sim.world.people.values():
		for i: int in range(person.moodlets.size() - 1, -1, -1):
			if person.moodlets[i].ends_tick <= sim.clock.tick:
				person.moodlets.remove_at(i)
		if midnight:
			_drift(sim, person)
			_fade(person)


static func _drift(sim: Sim, person: Person) -> void:
	var quiet := Social.DRIFT_AFTER_DAYS * SimClock.MINUTES_PER_DAY * SimClock.STEPS_PER_GAME_MINUTE
	for r: Relationship in person.relationships.values():
		if sim.clock.tick - r.last_contact_tick < quiet:
			continue
		for key: String in Social.DRIFT_PER_DAY:
			var step := float(Social.DRIFT_PER_DAY[key])
			var v := r.value(key)
			var floor_value := Social.FAMILIARITY_FLOOR if key == "familiarity" and v >= Social.FAMILIARITY_FLOOR else 0.0
			if v > floor_value:
				r.set(key, maxf(floor_value, v - step))
			elif v < 0.0:
				r.set(key, minf(0.0, v + step))


static func _fade(person: Person) -> void:
	for i: int in range(person.memories.size() - 1, -1, -1):
		person.memories[i].salience -= Social.SALIENCE_DECAY_PER_DAY
		if person.memories[i].salience <= 0.0:
			person.memories.remove_at(i)
