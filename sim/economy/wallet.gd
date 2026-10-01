class_name Wallet
extends RefCounted
## A person's money in euro cents (D29): cash in the pocket and the bank account, plus their
## latest changes for the phone's bank app. Change it only through Money.

## How many changes the statement keeps.
const STATEMENT_SIZE: int = 20

## Cash in the pocket; never negative.
var cash: int = 0
## The bank account; never negative in M3 (debts and fines come with M4).
var bank: int = 0
## Newest last, at most STATEMENT_SIZE entries:
## {"tick": int, "amount": int (signed), "account": "cash" | "bank", "reason": String,
##  "detail": String (what it was for: an interaction or job id, "" if nothing more to say)}
var statement: Array[Dictionary] = []


func total() -> int:
	return cash + bank


func to_dict() -> Dictionary:
	return {"cash": cash, "bank": bank, "statement": statement.duplicate(true)}


static func from_dict(d: Dictionary) -> Wallet:
	var wallet := Wallet.new()
	wallet.cash = int(d.get("cash", 0))
	wallet.bank = int(d.get("bank", 0))
	var entries: Variant = d.get("statement", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary:
				wallet.statement.append({
					"tick": int(entry.get("tick", 0)),
					"amount": int(entry.get("amount", 0)),
					"account": String(entry.get("account", "")),
					"reason": String(entry.get("reason", "")),
					"detail": String(entry.get("detail", "")),
				})
	return wallet
