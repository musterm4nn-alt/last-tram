class_name SimSystem
extends RefCounted
## Base class for sim systems (movement, needs, autonomy, jobs...).
## Systems keep NO state of their own: all state lives in World (and is saved there).
## A system may keep caches, but only ones it can rebuild from World at any time.
## Sim.default_systems() lists the systems and their order.


## Called every step (1/20 of a game minute). Keep it cheap: movement, collisions.
func step(_sim: Sim) -> void:
	pass


## Called once per game minute, after the step that completed it: needs, schedules, AI.
func on_minute(_sim: Sim) -> void:
	pass
