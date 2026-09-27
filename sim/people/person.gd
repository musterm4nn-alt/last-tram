class_name Person
extends RefCounted
## A resident of the town. The player is a Person too (see World.player_id), and runs on
## exactly the same rules as everyone else.

## Half-size of a person's collision box, in cells.
const RADIUS: float = 0.3
## Everyone in the game is an adult (AGENTS.md content rules).
const MIN_AGE: int = 18

var id: int = 0
var first_name: String = ""
var last_name: String = ""
## Optional nickname shown instead of the first name (see display_name()).
var nickname: String = ""
## Gender id from AppearanceCatalog.genders.
var gender: String = ""
## Pronoun set id from AppearanceCatalog.pronouns.
var pronouns: String = ""
## Age in years. Everyone in the game is an adult: this never stores less than MIN_AGE,
## whatever a spec, a save or a bug tries to set.
var age_years: int = MIN_AGE:
	set(value):
		age_years = maxi(MIN_AGE, value)
## What the person looks like.
var appearance: Appearance = Appearance.new()
## What the person wears.
var outfit: Outfit = Outfit.new()
## Floor the person is on (the z of their cell).
var level: int = 0
## Feet position in cell units: cell (3, 4) spans x 3..4, y 4..5, so its centre is (3.5, 4.5).
var pos: Vector2 = Vector2.ZERO
## Last movement direction, for sprites. Always one of the four cardinal directions.
var facing: Vector2 = Vector2.DOWN
## Direct-control walking direction (length 0..1). Set by SetMoveIntentCommand.
var move_intent: Vector2 = Vector2.ZERO
## Walking speed in cells per game minute. At 1x speed that is cells per real second.
var walk_speed: float = 4.5
## Needs 0-100 (100 = fully satisfied). Keys are need ids from data/needs.json.
var needs: Dictionary[String, float] = {}

## NOT saved: position before the latest step, only used to draw smooth movement.
var prev_pos: Vector2 = Vector2.ZERO


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


## Nickname when set, else the first name.
func display_name() -> String:
	return nickname if not nickname.is_empty() else first_name


func cell() -> Vector3i:
	return Vector3i(floori(pos.x), floori(pos.y), level)


func to_dict() -> Dictionary:
	var needs_out: Dictionary = {}
	for key: String in needs:
		needs_out[key] = needs[key]
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname,
		"gender": gender,
		"pronouns": pronouns,
		"age_years": age_years,
		"appearance": appearance.to_dict(),
		"outfit": outfit.to_dict(),
		"level": level,
		"pos": Ser.vec2(pos),
		"facing": Ser.vec2(facing),
		"move_intent": Ser.vec2(move_intent),
		"walk_speed": walk_speed,
		"needs": needs_out,
	}


static func from_dict(d: Dictionary) -> Person:
	var p := Person.new()
	p.id = int(d["id"])
	p.first_name = String(d["first_name"])
	p.last_name = String(d["last_name"])
	p.nickname = String(d.get("nickname", ""))
	p.gender = String(d.get("gender", ""))
	p.pronouns = String(d.get("pronouns", ""))
	p.age_years = int(d.get("age_years", 18))
	var appearance_data: Variant = d.get("appearance", {})
	if appearance_data is Dictionary:
		p.appearance = Appearance.from_dict(appearance_data)
	var outfit_data: Variant = d.get("outfit", {})
	if outfit_data is Dictionary:
		p.outfit = Outfit.from_dict(outfit_data)
	p.level = int(d["level"])
	p.pos = Ser.to_vec2(d["pos"])
	p.facing = Ser.to_vec2(d["facing"])
	p.move_intent = Ser.to_vec2(d["move_intent"])
	p.walk_speed = float(d["walk_speed"])
	p.prev_pos = p.pos
	p.needs = {}
	var stored: Variant = d.get("needs", {})
	if stored is Dictionary:
		for key: Variant in (stored as Dictionary):
			p.needs[String(key)] = float((stored as Dictionary)[key])
	return p
