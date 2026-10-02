class_name ProfiledSystem
extends SimSystem
## Wraps a sim system and adds up the real time its step and on_minute take (T-0078,
## `tools/simrun.sh --profile`). Tools only: the sim never measures time.

var inner: SimSystem
var name: String = ""
var usec: int = 0


func _init(p_inner: SimSystem) -> void:
	inner = p_inner
	name = p_inner.get_script().get_global_name()


func step(sim: Sim) -> void:
	var started := Time.get_ticks_usec()
	inner.step(sim)
	usec += Time.get_ticks_usec() - started


func on_minute(sim: Sim) -> void:
	var started := Time.get_ticks_usec()
	inner.on_minute(sim)
	usec += Time.get_ticks_usec() - started
