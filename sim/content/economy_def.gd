class_name EconomyDef
extends RefCounted
## Money tuning (data/economy.json, D29). All amounts are euro cents.

## What a new game's player starts with.
var player_start_cash: int = 0
var player_start_bank: int = 0
## Ranges (x = min, y = max) for generated residents' starting money.
var resident_cash: Vector2i = Vector2i.ZERO
var resident_bank: Vector2i = Vector2i.ZERO
