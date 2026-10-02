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
## The Monday cycle (T-0062): hours for benefit and pensions, then rent and bills.
var benefit_hour: int = 6
var rent_hour: int = 8
## Weekly amounts in cents.
var bills_week: int = 0
var benefit_week: int = 0
var housing_cap: int = 0
var pension_week: int = 0
## Performance rules by name (see data/economy.json "performance").
var performance: Dictionary[String, float] = {}
## Cash (T-0064): below this in the pocket, a trip to the ATM is an errand with this score.
var pocket_money: int = 1000
var cash_errand_score: float = 4.0
## Leaving for work (T-0060): minutes of slack on top of the walk, how often someone not on
## their way yet is sent again, and how close (hours) to a shift the walk is worked out.
var leave_margin: int = 10
var work_retry_minutes: int = 5
var look_ahead_hours: int = 3
## Relationship changes between colleagues who worked the same day (Social.change keys).
var colleague_deltas: Dictionary[String, float] = {}
## Lunch at work (T-0077): after this many minutes of a shift, hunger rises by lunch_hunger.
var lunch_after_minutes: int = 240
var lunch_hunger: float = 60.0
## The need rates every job uses while World.work.gentle is on (T-0077).
var gentle_profile: Dictionary[String, float] = {}
## Housing (T-0066): rent days behind before eviction, weeks of rent paid up front to move in,
## the hour flats are let each day, and the days a flat stays empty before newcomers come.
var evict_after_weeks: int = 3
var move_in_weeks: int = 2
var move_in_hour: int = 10
var vacant_days: int = 7
