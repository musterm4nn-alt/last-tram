class_name WalkPose2D
extends RefCounted
## View-only walk timing driven by actual displacement, with running and pause respected.

var elapsed: float = 0.0
var walking: bool = false


## Pause freezes the current pose; blocked or stopped people reset to the resting phase.
func advance(delta: float, displaced: bool, speed: int, running: bool) -> void:
	if speed <= 0:
		return
	walking = displaced
	if walking:
		elapsed += delta * speed * (Person.RUN_FACTOR if running else 1.0)
	else:
		elapsed = 0.0
