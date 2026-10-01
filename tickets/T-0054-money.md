---
id: T-0054
title: Money - cash, a bank account and the ledger
status: todo
milestone: M3
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Everyone has money: cash in their pocket and a bank account, in euro cents. The player starts
with €40 cash and €300 in the bank, and residents get random savings. Every change to anyone's
money goes through one API that also keeps the world's ledger, so a test can prove that money
is never created or lost by accident. The HUD shows your cash and bank balance. Nothing costs
money yet (T-0055).

## Read first
- `docs/decisions.md` D29, `docs/design/jobs-and-economy.md` → Money.
- Patterns to copy: `sim/content/needs_loader.gd` (a loader), `sim/social/moodlet.gd` (a small
  saved class), `SaveMigrations._v2_to_v3` (a migration), `Hud.place_text` (a pure HUD helper).

## Scope
Create `sim/economy/wallet.gd`, `sim/economy/ledger.gd`, `sim/economy/money.gd`,
`sim/content/economy_def.gd`, `sim/content/economy_loader.gd`, `data/economy.json`,
`tests/sim/test_money.gd`, `tests/fixtures/saves/v4_basic.json` (with
`tools/make_fixture_save.sh`).
Change `sim/content/content_db.gd`, `sim/people/person.gd`, `sim/world/world.gd`,
`sim/sim_factory.gd`, `sim/save/save_codec.gd`, `save_migrations.gd`, `save_validator.gd`,
`save_person_validator.gd`, `game/ui/hud.gd`, `game/ui/person_inspector.gd`,
`tools/sim_runner.gd`, and tests: `tests/sim/test_save_validation.gd`,
`tests/game/test_hud_place.gd`, `tests/game/test_person_inspector.gd`.
**Out of scope:** prices and paying for anything (T-0055), the ATM (T-0056), wages and rent
(T-0061, T-0062), the phone's bank app (T-0063), backgrounds (T-0075).

## Specification

### Data: `data/economy.json` → `ContentDB.economy: EconomyDef`
```json
{
	"_doc": "Money (T-0054, D29). Amounts are euro cents. player_start: the new-game player's cash and bank (backgrounds change it in T-0075). resident_start: [min, max] for generated residents, drawn in whole euros from the \"money\" stream.",
	"player_start": { "cash": 4000, "bank": 30000 },
	"resident_start": { "cash": [1000, 8000], "bank": [20000, 300000] }
}
```
- `EconomyDef` fields: `player_start_cash: int`, `player_start_bank: int`,
  `resident_cash: Vector2i`, `resident_bank: Vector2i` (x = min, y = max).
- `EconomyLoader.load(db, reader, path)`: reads with `reader.read_obj` /
  `reader.read_int` / `reader.read_coordinates(d, key, ctx, 2)`. Errors: any amount < 0,
  a range with min > max. A missing file is an error (like `needs.json`). `ContentDB.load_from`
  calls it right after `NeedsLoader`.

### `Wallet` (`sim/economy/wallet.gd`, saved inside Person)
```gdscript
class_name Wallet
extends RefCounted
## A person's money in euro cents (D29): cash in the pocket and the bank account, plus their
## latest changes for the phone's bank app. Change it only through Money.
const STATEMENT_SIZE: int = 20
var cash: int = 0          ## never negative
var bank: int = 0          ## never negative in M3 (debts and fines come with M4)
## Newest last, at most STATEMENT_SIZE entries:
## {"tick": int, "amount": int (signed), "account": "cash" | "bank", "reason": String,
##  "detail": String (what it was for: an interaction or job id, "" if nothing more to say)}
var statement: Array[Dictionary] = []
func total() -> int        # cash + bank
func to_dict() -> Dictionary      # {"cash", "bank", "statement"}
static func from_dict(d: Dictionary) -> Wallet   # ints via int(); missing keys → 0 / []
```
`Person.wallet: Wallet = Wallet.new()`, saved as `"wallet"` in `to_dict()`; `from_dict()`
reads `d.get("wallet", {})` when it is a Dictionary.

### `Ledger` (`sim/economy/ledger.gd`, saved as `World.ledger`)
```gdscript
class_name Ledger
extends RefCounted
## Totals of the money that entered people's hands (sources) and left them (sinks), by reason,
## in cents (D29). The money everyone holds always equals balance().
var sources: Dictionary[String, int] = {}
var sinks: Dictionary[String, int] = {}
func add_source(reason: String, amount: int) -> void
func add_sink(reason: String, amount: int) -> void
func balance() -> int                    # Σ sources − Σ sinks
func to_dict() -> Dictionary             # {"sources": {...}, "sinks": {...}}, keys sorted
static func from_dict(d: Dictionary) -> Ledger
```
`World.ledger: Ledger = Ledger.new()`, saved as `"ledger"`; `World.from_dict` reads
`d.get("ledger", {})`.

### `Money` (`sim/economy/money.gd`, static, no state)
```gdscript
class_name Money
extends RefCounted
## Every change to anyone's money goes through here (D29). It updates the wallet, the world's
## ledger and the person's statement, and emits &"money_changed". Amounts are euro cents.
const CASH: String = "cash"
const BANK: String = "bank"
## Reasons money enters people's hands (ledger sources) and leaves them (sinks).
const SOURCES: PackedStringArray = ["start", "wage", "benefit", "pension", "found"]
const SINKS: PackedStringArray = ["purchase", "rent", "bill"]

static func earn(sim: Sim, person: Person, amount: int, reason: String, account: String = BANK, detail: String = "") -> bool
static func spend(sim: Sim, person: Person, amount: int, reason: String, detail: String = "") -> bool
static func charge(sim: Sim, person: Person, amount: int, reason: String, detail: String = "") -> bool
static func withdraw(sim: Sim, person: Person, amount: int) -> bool
static func can_afford(person: Person, amount: int) -> bool    # wallet.total() >= amount
static func held(world: World) -> int                           # Σ everyone's cash + bank
static func give_start(sim: Sim) -> void
static func format(cents: int) -> String
```
- `earn`: adds `amount` to the account and `ledger.add_source(reason, amount)`. False, with
  no change, if `amount <= 0`, `reason` is not in SOURCES, or `account` is unknown.
- `spend`: pays from cash first; the rest comes from the bank (the card). False, with no
  change at all, if `amount <= 0`, `reason` is not in SINKS, or `can_afford` fails.
  `ledger.add_sink(reason, amount)` once for the whole amount.
- `charge`: like `spend`, but from the bank only (rent, bills): false unless `bank >= amount`.
- `withdraw` (the ATM, T-0056): moves `amount` from the bank to cash. The ledger doesn't
  change. False unless `0 < amount <= bank`.
- Each account that changes appends one statement entry (dropping the oldest beyond
  STATEMENT_SIZE) and emits `money_changed {person_id, amount (signed), account, reason,
  detail, cash, bank}` (`cash` and `bank` after the change). A cash-and-card payment gives
  two entries and two events. A withdrawal's reason is `"atm"`.
- `give_start` (new games only, called last in `SimFactory.new_game`): for every person in
  ascending id order, the player gets `player_start_cash` (cash) and `player_start_bank`
  (bank). Everyone else gets `randi_range(min / 100, max / 100) * 100` for cash, then for
  bank, from `sim.rng.stream("money")`. All with reason `"start"`.
  `SimFactory.from_rows` gives no money.
- `format`: `"€0.00"`, `"€12.50"`, `"€1,234.05"`, `"−€3.00"` (U+2212 minus sign, thousands
  separated by commas).

### Saving: v4
- `SaveCodec.SAVE_VERSION = 4`. `SaveMigrations._v3_to_v4`: every person gets
  `"wallet": {"cash": 4000, "bank": 30000, "statement": []}`, and the world gets
  `"ledger": {"sources": {"start": 34000 × number of people}, "sinks": {}}`, so old towns
  balance.
- `SavePersonValidator`: `wallet` (optional, so v3 data still validates before migration):
  a dictionary; `cash` an integer ≥ 0; `bank` an integer (−MAX..MAX); `statement` a list of at
  most `Wallet.STATEMENT_SIZE` dictionaries with integer `tick` and `amount`, `account` in
  ["cash", "bank"], and text `reason` and `detail`.
- `SaveValidator._world`: `ledger` (optional): `sources` and `sinks` are dictionaries of text
  keys to integers ≥ 0.
- Fixture `tests/fixtures/saves/v4_basic.json` from `tools/make_fixture_save.sh`.

### Showing it
- `Hud.money_text(person: Person) -> String`: `"Cash €40.00 · Bank €300.00"` ("" for null).
  A new 14 pt label under the clock line shows it, updated in `_process`.
- `PersonInspector.lines`: a `"Money: €340.00"` line (cash + bank) after `"Lives: …"`.
- `tools/sim_runner.gd`: after the town summary, print
  `money: people hold €X (median €Y) | in: start €A, … | out: purchase €B, …` (reasons
  sorted; "none" when empty).

## Acceptance criteria
- [ ] Money moves correctly → `test_money.gd`: `test_spend_uses_cash_first_then_the_card`,
  `test_spend_splits_cash_and_card` (cash €2 + bank €3 pays €4: cash 0, bank €1, two events),
  `test_cannot_spend_more_than_you_have` (false, nothing changes, no event),
  `test_charge_takes_only_from_the_bank`, `test_withdraw_moves_bank_to_cash_outside_the_ledger`,
  `test_bad_amounts_and_reasons_change_nothing`.
- [ ] Money is conserved → `test_money_is_conserved`: 500 random earn/spend/charge/withdraw
  calls on 5 people (fixed seed); after each one, `Money.held(world) == ledger.balance()` and
  no wallet is negative.
- [ ] `test_statement_keeps_the_newest_twenty` and
  `test_money_changed_reports_the_new_balances`.
- [ ] New games → `test_new_game_gives_everyone_starting_money` (the player gets exactly the
  data amounts, residents get amounts within the ranges in whole euros, and
  `held == ledger.balance() == sources["start"]`) and `test_starting_money_is_deterministic`
  (same seed, same amounts).
- [ ] Saving → `test_money_survives_save_and_load` (wallets, statements and ledger round-trip;
  "save mid-run equals uninterrupted run" in `test_save.gd` still passes);
  `test_v3_saves_get_starting_money` (the v3 fixture loads with €40/€300 each and a balanced
  ledger); `test_save_validation.gd` rejects negative cash, a non-integer bank and an unknown
  statement account.
- [ ] Content → `test_money.gd::test_economy_content_loads` (the real values) and a broken
  `tests/fixtures/content_broken/economy.json` (min > max, negative amount) is reported
  (`test_content.gd`).
- [ ] `test_money.gd::test_format` covers the four format cases above.
- [ ] HUD and inspector → `test_hud_place.gd::test_money_text`,
  `test_person_inspector.gd` checks the Money line.
- [ ] `tools/check.sh` passes; `tools/simrun.sh --days=7 --check-m2` still passes and prints
  the money line. Screenshot `out/t0054.png` shows the money line under the clock.

## Implementation notes

## Questions

## Review feedback
