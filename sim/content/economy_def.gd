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
