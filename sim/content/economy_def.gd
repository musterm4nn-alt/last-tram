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
## Jobs (T-0058): the job a new game's player starts in ("" = none), and the age people retire.
var player_job: String = ""
var retirement_age: int = 67
## Pay and performance (T-0061): wages are paid on payday (weekday 0 = Monday, whole hour).
var payday_weekday: int = 4
var payday_hour: int = 18
## Performance rules by name (see data/economy.json "performance").
var performance: Dictionary[String, float] = {}
