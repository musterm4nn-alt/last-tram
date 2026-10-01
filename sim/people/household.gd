class_name Household
extends RefCounted
## People who live together in one home: a single, a couple or flatmates (runtime entity,
## saved). Members are referenced by id. From M3 a household shares money.

const SINGLE: String = "single"
const COUPLE: String = "couple"
const FLATMATES: String = "flatmates"
const KINDS: PackedStringArray = [SINGLE, COUPLE, FLATMATES]

var id: int = 0
## One of KINDS.
var kind: String = SINGLE
var member_ids: Array[int] = []
## The Lot the household lives in.
var home_lot_id: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "member_ids": member_ids.duplicate(), "home_lot_id": home_lot_id}


static func from_dict(d: Dictionary) -> Household:
	var household := Household.new()
	household.id = int(d["id"])
	household.kind = String(d["kind"])
	for member: Variant in d["member_ids"]:
		household.member_ids.append(int(member))
	household.home_lot_id = int(d["home_lot_id"])
	return household
