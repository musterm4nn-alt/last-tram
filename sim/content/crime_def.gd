class_name CrimeDef
extends RefCounted
## A kind of crime (T-0091; data/crimes.json, docs/design/crime-and-police.md). An
## interaction with `crime` set to this id commits it when it finishes.

var id: String = ""
var name: String = ""
## How serious it is, 1 (trespassing) to 8 (killing): police priority, fines, jail time.
var severity: int = 1
## Theft of cash from a person target (T-0096; "steals_cash" in data): this share of their
## cash, at most steal_max cents. 0 = the crime takes no cash.
var steal_share: float = 0.0
var steal_max: int = 0
## Which of the victim's accounts it takes from: "cash" (pockets), or "bank" (T-0098: the
## savings a burglar finds at home).
var steal_account: String = "cash"
