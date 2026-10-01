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
	db.economy = economy


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
