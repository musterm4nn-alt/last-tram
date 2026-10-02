extends TestCase
## T-0045: M2 acceptance in the suite: two days of the full town pass TownCheck (the 7-day
## version is `tools/simrun.sh --days=7 --check-m2`; conversations are judged only over a
## week, D31).


func test_two_days_in_town_pass_the_town_check() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var town := TownCheck.new()
	for minute: int in 2 * SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			town.observe(sim, event)
		town.sample(sim)
	assert_eq(town.failures(sim, 2), PackedStringArray())
	print("        ", " | ".join(town.summary(sim)))


func test_the_check_notices_a_town_that_does_not_live() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for person: Person in sim.world.people.values():
		person.free_will = false
	var town := TownCheck.new()
	for minute: int in SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			town.observe(sim, event)
		town.sample(sim)
	var failures := town.failures(sim, 2)
	assert_true(failures.size() > 10, "without free will nobody eats or sleeps: %d problems" % failures.size())


func test_every_flat_has_beds_for_its_household() -> void:
	for seed_value: int in range(1, 6):
		var sim := SimFactory.new_game(content(), seed_value)
		for household: Household in sim.world.households.values():
			var place := sim.content.place(sim.world.lots[household.home_lot_id].place_id)
			assert_true(ResidentGenerator.bed_places(sim, place) >= household.member_ids.size(),
				"seed %d: %s sleeps %d in %d bed places" % [seed_value, place.id, household.member_ids.size(), ResidentGenerator.bed_places(sim, place)])
