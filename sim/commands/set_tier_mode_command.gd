class_name SetTierModeCommand
extends Command
## Sets the fidelity dial (TierSettings.mode: "tiered" or "full"); takes effect at the next
## tier check. Unknown modes are ignored.

var mode: String = TierSettings.TIERED


func _init(p_mode: String = TierSettings.TIERED) -> void:
	mode = p_mode


func type_id() -> String:
	return "set_tier_mode"


func apply(sim: Sim) -> void:
	if mode in [TierSettings.TIERED, TierSettings.FULL]:
		sim.world.tiers.mode = mode


func to_dict() -> Dictionary:
	return {"person_id": 0, "mode": mode}


func load_dict(d: Dictionary) -> void:
	mode = String(d["mode"])
