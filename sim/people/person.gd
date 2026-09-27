class_name Person
extends RefCounted
## A resident of the town. The player is a Person too (see World.player_id), and runs on
## exactly the same rules as everyone else.

## Half-size of a person's collision box, in cells.
const RADIUS: float = 0.3

var id: int = 0
var first_name: String = ""
var last_name: String = ""
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

## NOT saved: position before the latest step, only used to draw smooth movement.
var prev_pos: Vector2 = Vector2.ZERO


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func cell() -> Vector3i:
	return Vector3i(floori(pos.x), floori(pos.y), level)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"level": level,
		"pos": Ser.vec2(pos),
		"facing": Ser.vec2(facing),
		"move_intent": Ser.vec2(move_intent),
		"walk_speed": walk_speed,
	}


static func from_dict(d: Dictionary) -> Person:
	var p := Person.new()
	p.id = int(d["id"])
	p.first_name = String(d["first_name"])
	p.last_name = String(d["last_name"])
	p.level = int(d["level"])
	p.pos = Ser.to_vec2(d["pos"])
	p.facing = Ser.to_vec2(d["facing"])
	p.move_intent = Ser.to_vec2(d["move_intent"])
	p.walk_speed = float(d["walk_speed"])
	p.prev_pos = p.pos
	return p
