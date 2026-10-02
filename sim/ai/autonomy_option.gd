class_name AutonomyOption
extends RefCounted
## One thing free will could do (T-0078: typed, so a person id no longer hides in an object
## id field): an interaction on an object or with a person, its score and the walk to it.

const OBJECT: String = "object"
const PERSON: String = "person"

## The object's or the person's id (see target_kind).
var target_id: int = 0
## OBJECT or PERSON.
var target_kind: String = OBJECT
var interaction_id: String = ""
var score: float = 0.0
## The walk in cells (0 when already there).
var cells: int = 0
## Its place in Autonomy.candidates()' order (ties in choose()).
var order: int = 0


func _init(p_target_id: int = 0, p_interaction_id: String = "", p_score: float = 0.0, p_cells: int = 0,
		p_target_kind: String = OBJECT) -> void:
	target_id = p_target_id
	interaction_id = p_interaction_id
	score = p_score
	cells = p_cells
	target_kind = p_target_kind


func copy() -> AutonomyOption:
	var out := AutonomyOption.new(target_id, interaction_id, score, cells, target_kind)
	out.order = order
	return out


## {target_id, target_kind, interaction_id, score, cells}, for comparing and reports.
func to_dict() -> Dictionary:
	return {"target_id": target_id, "target_kind": target_kind, "interaction_id": interaction_id, "score": score, "cells": cells}
