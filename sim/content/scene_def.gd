class_name SceneDef
extends RefCounted
## A short text moment shown in a popup (data/scenes/*.json, T-0043). Its pages are
## templates the view fills in (SceneText). Scenes never change the sim.

var id: String = ""
## Adult scenes need the adult-content setting (M6); the core game has none.
var adult: bool = false
var pages: PackedStringArray = PackedStringArray()
