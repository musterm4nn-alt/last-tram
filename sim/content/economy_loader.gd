class_name EconomyLoader
extends RefCounted
## Loads data/economy.json into ContentDB.economy (D29).


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var economy := EconomyDef.new()
	var player := reader.read_obj(root, "player_start", path)
	economy.player_start_cash = reader.read_int(player, "cash", path + ": player_start")
	economy.player_start_bank = reader.read_int(player, "bank", path + ": player_start")
	for amount: int in [economy.player_start_cash, economy.player_start_bank]:
		if amount < 0:
			reader.error("%s: player_start amounts must be >= 0" % path)
	var residents := reader.read_obj(root, "resident_start", path)
	economy.resident_cash = _range(reader, residents, "cash", path)
	economy.resident_bank = _range(reader, residents, "bank", path)
	economy.price_cost_per_euro = reader.read_num(root, "price_cost_per_euro", path)
	economy.low_money = reader.read_int(root, "low_money", path)
	economy.low_money_factor = reader.read_num(root, "low_money_factor", path)
	if economy.price_cost_per_euro < 0.0 or economy.low_money < 0 or economy.low_money_factor < 0.0:
		reader.error("%s: price_cost_per_euro, low_money and low_money_factor must be >= 0" % path)
	economy.fridge_capacity = reader.read_int(root, "fridge_capacity", path)
	var start := reader.read_coordinates(root, "start_groceries", path, 2)
	if start.size() == 2:
		if start[0] < 0 or start[0] > start[1]:
			reader.error("%s: 'start_groceries' must be [min, max] with 0 <= min <= max" % path)
		economy.start_groceries = Vector2i(start[0], start[1])
	economy.restock_below = reader.read_int(root, "restock_below", path)
	economy.restock_bonus = reader.read_num(root, "restock_bonus", path)
	economy.hungry_below = reader.read_num(root, "hungry_below", path)
	if economy.fridge_capacity < 1 or economy.start_groceries.y > economy.fridge_capacity:
		reader.error("%s: 'fridge_capacity' must be >= 1 and hold the starting groceries" % path)
	if economy.restock_below < 0 or economy.restock_bonus < 0.0 or economy.hungry_below < 0.0:
		reader.error("%s: restock_below, restock_bonus and hungry_below must be >= 0" % path)
	economy.player_job = reader.read_str(root, "player_job", path) if root.has("player_job") else ""
	economy.retirement_age = reader.read_int(root, "retirement_age", path)
	if economy.retirement_age <= Person.MIN_AGE:
		reader.error("%s: 'retirement_age' must be above %d" % [path, Person.MIN_AGE])
	var payday := reader.read_obj(root, "payday", path)
	economy.payday_weekday = reader.read_int(payday, "weekday", path + ": payday")
	economy.payday_hour = reader.read_int(payday, "hour", path + ": payday")
	if economy.payday_weekday < 0 or economy.payday_weekday > 6 or economy.payday_hour < 0 or economy.payday_hour > 23:
		reader.error("%s: payday needs a weekday 0..6 and an hour 0..23" % path)
	var week := reader.read_obj(root, "week", path)
	economy.benefit_hour = reader.read_int(week, "benefit_hour", path + ": week")
	economy.rent_hour = reader.read_int(week, "rent_hour", path + ": week")
	if economy.benefit_hour < 0 or economy.rent_hour > 23 or economy.benefit_hour >= economy.rent_hour:
		reader.error("%s: week needs benefit_hour before rent_hour, both 0..23" % path)
	economy.bills_week = reader.read_int(root, "bills_week", path)
	economy.benefit_week = reader.read_int(root, "benefit_week", path)
	economy.housing_cap = reader.read_int(root, "housing_cap", path)
	economy.pension_week = reader.read_int(root, "pension_week", path)
	for amount: int in [economy.bills_week, economy.benefit_week, economy.housing_cap, economy.pension_week]:
		if amount < 0:
			reader.error("%s: weekly amounts must be >= 0" % path)
	economy.performance = read_performance(reader, root, path)
	economy.pocket_money = reader.read_int(root, "pocket_money", path)
	economy.cash_errand_score = reader.read_num(root, "cash_errand_score", path)
	if economy.pocket_money < 0 or economy.cash_errand_score < 0.0:
		reader.error("%s: pocket_money and cash_errand_score must be >= 0" % path)
	_read_work(reader, economy, reader.read_obj(root, "work", path), path + ": work")
	var gentle := reader.read_obj(root, "gentle_profile", path)
	for need_id: Variant in gentle:
		if not need_id is String or db.need(need_id) == null:
			reader.error("%s: unknown need '%s' in 'gentle_profile'" % [path, need_id])
		elif not (gentle[need_id] is float or gentle[need_id] is int):
			reader.error("%s: 'gentle_profile' rate for '%s' must be a number" % [path, need_id])
		else:
			economy.gentle_profile[need_id] = float(gentle[need_id])
	var housing := reader.read_obj(root, "housing", path)
	for key: String in ["evict_after_weeks", "move_in_weeks", "move_in_hour", "vacant_days"]:
		economy.set(key, reader.read_int(housing, key, path + ": housing"))
	if economy.evict_after_weeks < 1 or economy.move_in_weeks < 1 or economy.vacant_days < 1 or economy.move_in_hour < 0 or economy.move_in_hour > 23:
		reader.error("%s: housing needs evict_after_weeks, move_in_weeks and vacant_days >= 1 and move_in_hour 0..23" % path)
	db.economy = economy


## The "work" block (T-0077): leaving for work, colleagues and lunch.
static func _read_work(reader: ContentReader, economy: EconomyDef, work: Dictionary, ctx: String) -> void:
	economy.leave_margin = reader.read_int(work, "leave_margin", ctx)
	economy.work_retry_minutes = reader.read_int(work, "retry_minutes", ctx)
	economy.look_ahead_hours = reader.read_int(work, "look_ahead_hours", ctx)
	economy.lunch_after_minutes = reader.read_int(work, "lunch_after_minutes", ctx)
	economy.lunch_hunger = reader.read_num(work, "lunch_hunger", ctx)
	if economy.leave_margin < 0 or economy.work_retry_minutes < 1 or economy.look_ahead_hours < 1:
		reader.error("%s: leave_margin must be >= 0, retry_minutes and look_ahead_hours >= 1" % ctx)
	if economy.lunch_after_minutes < 1 or economy.lunch_hunger < 0.0 or economy.lunch_hunger > 100.0:
		reader.error("%s: lunch_after_minutes must be >= 1 and lunch_hunger within 0..100" % ctx)
	var deltas := reader.read_obj(work, "colleague_deltas", ctx)
	for key: Variant in deltas:
		if not Relationship.RANGES.has(key):
			reader.error("%s: unknown relationship value '%s' in 'colleague_deltas'" % [ctx, key])
		elif not (deltas[key] is float or deltas[key] is int):
			reader.error("%s: 'colleague_deltas' change for '%s' must be a number" % [ctx, key])
		else:
			economy.colleague_deltas[String(key)] = float(deltas[key])


## Every rule data/economy.json "performance" must give (T-0061, T-0077).
const PERFORMANCE_KEYS: PackedStringArray = ["shift_done", "good_mood", "per_5_minutes_late", "left_early", "missed",
	"promote_at", "promote_after_shifts", "after_promotion", "warn_below", "warning_clears_at", "fire_at"]
## The rules that are performance levels (0..100).
const PERFORMANCE_LEVELS: PackedStringArray = ["promote_at", "after_promotion", "warn_below", "warning_clears_at", "fire_at"]


## Reads `root`'s "performance" rules and checks they make sense together (T-0077): every
## rule >= 0, the levels in 0..100, fire_at < warn_below < warning_clears_at <= promote_at,
## and promote_after_shifts a whole number >= 1.
static func read_performance(reader: ContentReader, root: Dictionary, path: String) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	var rules := reader.read_obj(root, "performance", path)
	for key: String in PERFORMANCE_KEYS:
		out[key] = reader.read_num(rules, key, path + ": performance")
		if out[key] < 0.0:
			reader.error("%s: performance '%s' must be >= 0" % [path, key])
		elif PERFORMANCE_LEVELS.has(key) and out[key] > 100.0:
			reader.error("%s: performance '%s' must be 0..100" % [path, key])
	if not (out["fire_at"] < out["warn_below"] and out["warn_below"] < out["warning_clears_at"] and out["warning_clears_at"] <= out["promote_at"]):
		reader.error("%s: performance needs fire_at < warn_below < warning_clears_at <= promote_at" % path)
	if out["promote_after_shifts"] < 1.0 or out["promote_after_shifts"] != floorf(out["promote_after_shifts"]):
		reader.error("%s: performance 'promote_after_shifts' must be a whole number >= 1" % path)
	return out


## A [min, max] amount range in cents (min <= max, both >= 0), or (0, 0) with an error.
static func _range(reader: ContentReader, d: Dictionary, key: String, path: String) -> Vector2i:
	var ctx := "%s: resident_start" % path
	var pair := reader.read_coordinates(d, key, ctx, 2)
	if pair.is_empty():
		return Vector2i.ZERO
	if pair[0] < 0 or pair[1] < 0:
		reader.error("%s: '%s' amounts must be >= 0" % [ctx, key])
		return Vector2i.ZERO
	if pair[0] > pair[1]:
		reader.error("%s: '%s' must be [min, max] with min <= max" % [ctx, key])
		return Vector2i.ZERO
	return Vector2i(pair[0], pair[1])
