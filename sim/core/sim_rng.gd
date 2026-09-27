class_name SimRng
extends RefCounted
## Deterministic randomness for the sim. Each system draws from its own named stream,
## so adding a new system never changes the random numbers another system gets.
## Never use the global randi()/randf()/randomize() in sim code (lint-enforced).
##
##     var r := sim.rng.stream("autonomy")
##     if r.randf() < 0.25: ...

var master_seed: int = 0
var _streams: Dictionary[String, RandomNumberGenerator] = {}


func _init(p_master_seed: int = 0) -> void:
	master_seed = p_master_seed


func stream(stream_name: String) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = _streams.get(stream_name)
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = hash("%d:%s" % [master_seed, stream_name])
		_streams[stream_name] = r
	return r


func to_dict() -> Dictionary:
	# RNG states are 64-bit; JSON numbers are doubles, so store them as strings.
	var states: Dictionary = {}
	for stream_name: String in _streams:
		states[stream_name] = str(_streams[stream_name].state)
	return {"master_seed": master_seed, "streams": states}


static func from_dict(d: Dictionary) -> SimRng:
	var rng := SimRng.new(int(d["master_seed"]))
	var states: Dictionary = d["streams"]
	for stream_name: String in states:
		var r := RandomNumberGenerator.new()
		r.state = String(states[stream_name]).to_int()
		rng._streams[stream_name] = r
	return rng
