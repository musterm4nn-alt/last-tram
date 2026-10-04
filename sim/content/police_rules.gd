class_name PoliceRules
extends RefCounted
## Reporting crimes and the wanted level (T-0093; "police" in data/crimes.json).

## A witness reports with chance report_base + report_per_severity × severity (at most
## 0.95), times friend_report_factor when their friendship with the perpetrator is at least
## friend_at.
var report_base: float = 0.1
var report_per_severity: float = 0.2
var friend_report_factor: float = 0.3
var friend_at: float = 30.0
## A reported crime counts towards the wanted level for this many game hours.
var heat_hours: int = 48
## Wanted level = ceil(sum of the severities of the crimes that count / severity_per_level),
## at most MAX_LEVEL.
var severity_per_level: int = 2
## An arrest costs this many cents per severity point of the crimes charged (T-0094).
var fine_per_severity: int = 5000
## An officer arrests a suspect they can see within this many cells (feet to feet).
var arrest_range: float = 1.0
