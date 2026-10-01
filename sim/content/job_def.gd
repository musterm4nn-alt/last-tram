class_name JobDef
extends RefCounted
## A job (data/jobs.json, T-0058, D29): who employs you, where you work, the career track and
## the positions to fill. One position is one ShiftDef; one person fills it.

const RABBIT_HOLE: String = "rabbit_hole"
const ON_SITE: String = "on_site"
const SESSIONS: PackedStringArray = [RABBIT_HOLE, ON_SITE]

var id: String = ""
## The job title at level 0 is levels[0].title; `name` is the job's own name.
var name: String = ""
## The employer's place (a PlaceDef id); the workplace object stands on it.
var place_id: String = ""
## How the shift is worked (WorkSession, T-0059): RABBIT_HOLE or ON_SITE.
var session: String = RABBIT_HOLE
## Tag of the object people work at (the tram shelter, a counter...).
var workplace_tag: String = ""
## Per-hour need changes while working, on top of normal decay.
var need_rates: Dictionary[String, float] = {}
var levels: Array[JobLevel] = []
## The positions, with "count" already expanded.
var positions: Array[ShiftDef] = []
## Chance (0..1) each position is filled when a new town is generated.
var start_filled: float = 1.0
