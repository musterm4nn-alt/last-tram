class_name TemptationRules
extends RefCounted
## When residents commit crimes on their own (T-0097; "temptation" in data/crimes.json). Only
## the player decides for the player.

## A resident is willing with honesty at or below this, or with less than broke_below cents
## in all (cash and bank)...
var honesty_below: int = -40
var broke_below: int = 1000
## ...unless they are wanted, or committed a crime in the last cooldown_hours game hours.
var cooldown_hours: int = 72
## Added to the score of a crime that takes cash (pickpocketing).
var steal_bonus: float = 5.0
## Taken off a crime's score for each person who could see it, times (1 - bravery / 200)...
var risk_per_witness: float = 3.0
## ...and this much more for each police officer among them.
var risk_per_officer: float = 10.0
