class_name SaveValidator
extends RefCounted
## Rejects malformed saves before migrations, constructors or command decoders run.
## Unknown content ids remain loadable through the existing compatibility fallbacks.

const MAX_GRID_CELLS: int = 4194304


## True only when every persisted field is safe to deserialize.
static func validate(data: Dictionary, errors: Array[String], content: ContentDB) -> bool:
	var before := errors.size()
	var s := SaveSchema.new(errors)
	var version := s.integer(data.get("save_version"), "save_version", 1)
	var clock := s.dictionary(data.get("clock"), "clock")
	var tick := s.integer(clock.get("tick"), "clock.tick")
	var rng := s.dictionary(data.get("rng"), "rng")
	s.integer(rng.get("master_seed"), "rng.master_seed", -SaveSchema.MAX_INTEGER)
	var streams := s.dictionary(rng.get("streams"), "rng.streams")
	for key: Variant in streams:
		s.text(key, "rng.stream name")
		var state := s.text(streams[key], "rng.streams." + str(key))
		if not SaveSchema.is_integer_string(state):
			s.reject("rng.streams." + str(key), "must contain a signed 64-bit integer string")
	var world := s.dictionary(data.get("world"), "world")
	_world(world, s, version, tick, content)
	for entry: Variant in s.list(data.get("pending_commands"), "pending_commands"):
		_command(s.dictionary(entry, "pending_commands[]"), s)
	return errors.size() == before


static func _world(world: Dictionary, s: SaveSchema, version: int, tick: int, content: ContentDB) -> void:
	var next_id := s.integer(world.get("next_id"), "world.next_id", 1)
	var player_id := s.integer(world.get("player_id"), "world.player_id", 1)
	var grid := s.dictionary(world.get("grid"), "world.grid")
	var grid_before := s.errors.size()
	_grid(grid, s)
	var grid_valid := s.errors.size() == grid_before and not grid.is_empty()
	var ids: Dictionary[int, bool] = {}
	var people_ids: Dictionary[int, bool] = {}
	for entry: Variant in s.list(world.get("people"), "world.people"):
		var person := s.dictionary(entry, "world.people[]")
		var id := s.integer(person.get("id"), "world.people[].id", 1)
		_register(id, next_id, ids, s)
		people_ids[id] = true
		var initial := s.errors.size()
		var action_ids := SavePersonValidator.validate(person, s, "world.people[%d]" % id, version)
		for action_id: int in action_ids:
			_register(action_id, next_id, ids, s)
		if grid_valid and s.errors.size() == initial:
			var position := Ser.to_vec2(person["pos"])
			var level := int(person["level"])
			var levels: Variant = grid.get("levels")
			if not levels is Dictionary or not levels.has(str(level)) or position.x < 0.0 or position.y < 0.0 or position.x >= float(grid.get("width", 0)) or position.y >= float(grid.get("height", 0)):
				s.reject("world.people[%d].pos" % id, "must be inside a saved grid level")
			if Ser.to_vec2(person["move_intent"]).length() > 1.00001:
				s.reject("world.people[%d].move_intent" % id, "direction length exceeds one")
			if int(person.get("last_input_tick", 0)) > tick:
				s.reject("world.people[%d].last_input_tick" % id, "cannot be in the future")
			for action: Dictionary in person.get("action_queue", []):
				if int(action.get("started_tick", -1)) > tick:
					s.reject("world.people[%d].action_queue" % id, "start tick cannot be in the future")
	if not people_ids.has(player_id):
		s.reject("world.player_id", "must reference a saved person")
	for entry: Variant in s.list(world.get("objects", []), "world.objects"):
		var obj := s.dictionary(entry, "world.objects[]")
		var id := s.integer(obj.get("id"), "world.objects[].id", 1)
		var def_id := s.text(obj.get("def_id"), "world.objects[].def_id")
		# Objects from removed content are skipped on load and cannot consume live ids.
		if content.object_def(def_id) != null:
			_register(id, next_id, ids, s)
		s.vector(obj.get("origin"), "world.objects[].origin", 3, true)
		s.integer(obj.get("rotation"), "world.objects[].rotation", 0, 3)
	for entry: Variant in s.list(world.get("lots", []), "world.lots"):
		var lot := s.dictionary(entry, "world.lots[]")
		var place_id := s.text(lot.get("place_id"), "world.lots[].place_id")
		var lot_id := s.integer(lot.get("id"), "world.lots[].id", 1)
		# Lots of removed places are dropped on load and cannot consume live ids.
		if content.place(place_id) != null:
			_register(lot_id, next_id, ids, s)
		if not Lot.ACCESS.has(s.text(lot.get("access"), "world.lots[].access")):
			s.reject("world.lots[].access", "unknown access")
		s.integer(lot.get("open_hour", 0), "world.lots[].open_hour", 0, 24)
		s.integer(lot.get("close_hour", 24), "world.lots[].close_hour", 0, 24)
	var tiers := s.dictionary(world.get("tiers", {}), "world.tiers")
	if not String(tiers.get("mode", TierSettings.TIERED)) in [TierSettings.TIERED, TierSettings.FULL]:
		s.reject("world.tiers.mode", "unknown tier mode")
	s.number(tiers.get("active_radius", 40.0), "world.tiers.active_radius", 0.0)
	s.number(tiers.get("demote_radius", 50.0), "world.tiers.demote_radius", 0.0)
	for entry: Variant in s.list(world.get("households", []), "world.households"):
		var household := s.dictionary(entry, "world.households[]")
		_register(s.integer(household.get("id"), "world.households[].id", 1), next_id, ids, s)
		if not Household.KINDS.has(s.text(household.get("kind"), "world.households[].kind")):
			s.reject("world.households[].kind", "unknown household kind")
		for member: Variant in s.list(household.get("member_ids"), "world.households[].member_ids"):
			if not people_ids.has(s.integer(member, "world.households[].member_ids[]", 1)):
				s.reject("world.households[].member_ids", "must reference saved people")
		s.integer(household.get("home_lot_id"), "world.households[].home_lot_id")


static func _register(id: int, next_id: int, ids: Dictionary[int, bool], s: SaveSchema) -> void:
	if ids.has(id) or id >= next_id:
		s.reject("world ids", "ids must be unique and smaller than next_id")
	ids[id] = true


static func _grid(grid: Dictionary, s: SaveSchema) -> void:
	var width := s.integer(grid.get("width"), "world.grid.width", 1, 4096)
	var height := s.integer(grid.get("height"), "world.grid.height", 1, 4096)
	s.strings(grid.get("palette"), "world.grid.palette")
	var levels := s.dictionary(grid.get("levels"), "world.grid.levels")
	if levels.is_empty() or width * height * levels.size() > MAX_GRID_CELLS:
		s.reject("world.grid", "must have levels within the supported grid size")
		return
	for key: Variant in levels:
		var name := s.text(key, "world.grid level")
		if name.length() > 11 or not name.is_valid_int() or name != str(name.to_int()) or name.to_int() < -2147483648 or name.to_int() > 2147483647:
			s.reject("world.grid.levels", "level keys must be canonical 32-bit integers")
		s.grid_bytes(levels[key], "world.grid.levels." + name, width * height * 4)


static func _command(command: Dictionary, s: SaveSchema) -> void:
	var path := "pending_commands[]"
	var type := s.text(command.get("type"), path + ".type")
	s.integer(command.get("person_id"), path + ".person_id")
	match type:
		"set_move_intent":
			s.vector(command.get("direction"), path + ".direction", 2)
		"walk_to":
			s.vector(command.get("target"), path + ".target", 3, true)
		"queue_interaction":
			s.text(command.get("interaction_id"), path + ".interaction_id")
			s.integer(command.get("target_id"), path + ".target_id")
		"cancel_action":
			s.integer(command.get("index"), path + ".index", -SaveSchema.MAX_INTEGER)
			s.integer(command.get("action_id", 0), path + ".action_id")
		"set_free_will":
			s.boolean(command.get("enabled"), path + ".enabled")
		"set_running":
			s.boolean(command.get("running"), path + ".running")
		"set_tier_mode":
			if not s.text(command.get("mode"), path + ".mode") in [TierSettings.TIERED, TierSettings.FULL]:
				s.reject(path + ".mode", "unknown tier mode")
		_:
			s.reject(path + ".type", "unknown command type")
