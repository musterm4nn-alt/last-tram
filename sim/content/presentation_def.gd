class_name PresentationDef
extends RefCounted
## When an interaction asks for a scene (T-0043): the "presentation" block of an interaction.

var scene_id: String = ""
## When it is requested; "finish" (when the action finishes) is the only one so far.
var when: String = "finish"
## Only when the player does it.
var player_only: bool = true
## Chance of showing it each time (0..1), rolled with the "scenes" stream when below 1.
var chance: float = 1.0
## Only on this game day (0 = Monday of the first week); -1 = any day.
var day: int = -1
## Only the first time for each person (remembered in Person.scenes_requested).
var once: bool = false
