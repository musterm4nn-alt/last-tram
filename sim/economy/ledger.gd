class_name Ledger
extends RefCounted
## Totals of the money that entered people's hands (sources) and left them (sinks), by reason,
## in cents (D29). The money everyone holds always equals balance(): the test that money is
## never created or lost by accident.

var sources: Dictionary[String, int] = {}
var sinks: Dictionary[String, int] = {}


func add_source(reason: String, amount: int) -> void:
	sources[reason] = sources.get(reason, 0) + amount


func add_sink(reason: String, amount: int) -> void:
	sinks[reason] = sinks.get(reason, 0) + amount


## Σ sources − Σ sinks.
func balance() -> int:
	var total := 0
	for reason: String in sources:
		total += sources[reason]
	for reason: String in sinks:
		total -= sinks[reason]
	return total


## Keys sorted, so save text is stable.
func to_dict() -> Dictionary:
	return {"sources": _sorted(sources), "sinks": _sorted(sinks)}


static func from_dict(d: Dictionary) -> Ledger:
	var ledger := Ledger.new()
	for key: String in ["sources", "sinks"]:
		var totals: Variant = d.get(key, {})
		if not totals is Dictionary:
			continue
		var target: Dictionary[String, int] = ledger.sources if key == "sources" else ledger.sinks
		for reason: Variant in totals:
			target[String(reason)] = int(totals[reason])
	return ledger


static func _sorted(totals: Dictionary[String, int]) -> Dictionary:
	var keys: Array = totals.keys()
	keys.sort()
	var out: Dictionary = {}
	for reason: String in keys:
		out[reason] = totals[reason]
	return out
