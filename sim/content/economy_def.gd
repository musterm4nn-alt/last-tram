class_name EconomyDef
extends RefCounted
## Money tuning (data/economy.json, D29). All amounts are euro cents.

## What a new game's player starts with.
var player_start_cash: int = 0
var player_start_bank: int = 0
## Ranges (x = min, y = max) for generated residents' starting money.
var resident_cash: Vector2i = Vector2i.ZERO
var resident_bank: Vector2i = Vector2i.ZERO
## Free will (T-0055): score lost per euro of an interaction's price...
var price_cost_per_euro: float = 0.0
## ...times low_money_factor while the person holds less than low_money (cents).
var low_money: int = 0
var low_money_factor: float = 1.0
## Groceries (T-0057): portions a fridge holds, and new households' [min, max] (x, y).
var fridge_capacity: int = 20
var start_groceries: Vector2i = Vector2i.ZERO
## Free will shops for groceries below this stock, with this score bonus...
var restock_below: int = 0
var restock_bonus: float = 0.0
## ...and eats out when hunger is below this with (almost) nothing at home.
var hungry_below: float = 0.0
