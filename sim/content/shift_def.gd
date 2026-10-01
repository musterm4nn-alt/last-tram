class_name ShiftDef
extends RefCounted
## When one position of a job works (data/jobs.json "positions"): weekdays and whole hours.

## Weekdays the shift starts on (0 = Monday … 6 = Sunday, like SimClock.weekday()).
var days: PackedInt32Array = PackedInt32Array()
## Whole hours 0..24; `to < from` means the shift ends after midnight, on the next day.
var from: int = 9
var to: int = 17


## Length in hours (past midnight counts on).
func hours() -> int:
	return to - from if to > from else to + 24 - from
