class_name RoutineDef
extends RefCounted
## A daily rhythm (data/routines.json): when a person with this routine sleeps.

var id: String = ""
var name: String = ""
## [start, end] whole hours; wraps past midnight when end < start.
var sleep_hours: Vector2i = Vector2i(23, 7)
## [start, end] whole hours for going out (routine "out" interactions, T-0052); wraps too.
var out_hours: Vector2i = Vector2i(19, 23)
## How often generated residents get this routine (relative; 0 = only to fit a job's shift).
var weight: int = 1
