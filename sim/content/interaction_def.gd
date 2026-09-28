class_name InteractionDef
extends RefCounted
## One thing a person can do with an object (Sleep on a bed, Grab a snack from a
## fridge...). Defined in data/interactions/*.json. Objects offer the interactions
## whose object_tags overlap their own tags. Exactly one of `duration_minutes`
## (fixed length) or `until_need` (ends when that need reaches 100, between
## `min_minutes` and `max_minutes`) is used.

var id: String = ""
var name: String = ""
## Object tags that offer this interaction (at least one must be used by some object).
var object_tags: PackedStringArray = PackedStringArray()
## Fixed length in game minutes, or 0 when `until_need` is used.
var duration_minutes: int = 0
## Need id this runs until (100), or "" when `duration_minutes` is used.
var until_need: String = ""
## Shortest and longest run for `until_need`, in game minutes.
var min_minutes: int = 0
var max_minutes: int = 0
## Per-game-hour need changes while performing, on top of normal decay.
var need_rates: Dictionary[String, float] = {}
## One-off need gains when the action finishes.
var finish_needs: Dictionary[String, float] = {}
## The need gains autonomy scoring expects (may differ from reality).
var advertise: Dictionary[String, float] = {}
## While the player performs this, the game runs at Session.SKIP_SPEED (sleeping).
var time_skip: bool = false
