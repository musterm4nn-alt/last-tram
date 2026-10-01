class_name TierSettings
extends RefCounted
## The simulation fidelity dial (docs/design/simulation-tiers.md, T-0042; saved with the
## world). "tiered": people far from the player are background (updated once per game
## minute); "full": everyone is simulated in full detail ("full lives").

const TIERED: String = "tiered"
const FULL: String = "full"

var mode: String = TIERED
## Background people closer than this (cells) become active.
var active_radius: float = 40.0
## Active people further than this become background (hysteresis: larger than active_radius).
var demote_radius: float = 50.0


func to_dict() -> Dictionary:
	return {"mode": mode, "active_radius": active_radius, "demote_radius": demote_radius}


static func from_dict(d: Dictionary) -> TierSettings:
	var t := TierSettings.new()
	t.mode = String(d.get("mode", TIERED))
	t.active_radius = float(d.get("active_radius", 40.0))
	t.demote_radius = maxf(t.active_radius, float(d.get("demote_radius", 50.0)))
	return t
