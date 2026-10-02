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
	db.economy = economy


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
