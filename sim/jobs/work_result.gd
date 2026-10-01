class_name WorkResult
extends RefCounted
## How a shift went (WorkSession.finish, T-0059): pay and performance come from it (T-0061).

var job_id: String = ""
## Minutes worked inside the shift window.
var minutes: int = 0
## Minutes between the shift's start and starting to work (0 when on time or early).
var late_minutes: int = 0
## True when the shift was ended before its end (walking away, being cancelled).
var left_early: bool = false
