# Jobs and economy (M3)

How money, shops, jobs and rent work. The decisions behind this page are in D29
([decisions.md](../decisions.md)); the tickets are T-0054 to T-0076. Every number below is a
starting value: it lives in `data/` and gets tuned by measuring the town (`tools/simrun.sh`).

## Money

- Stored as **integer euro cents** (no float drift). Displayed as `€12.50`.
- **Per person**: **cash** (in the wallet; it can be pickpocketed or robbed in M4) and a
  **bank** account (card payments, wages, rent; safe from street crime). Couples and
  flatmates keep their own money; joint accounts come with M6.
- Paying uses cash first, then the card for the rest. An **ATM** moves money from the bank
  to cash.
- Every change goes through one API (`Money`): it updates the wallet, the world's **ledger**
  and the person's statement, and emits `money_changed {person_id, amount, account, reason,
  cash, bank}`.
- The **ledger** keeps totals by reason. Sources (money entering people's hands): `start`,
  `wage`, `benefit`, `pension`, `found`. Sinks (money leaving): `purchase`, `rent`, `bill`.
  The money people hold always equals sources minus sinks, so a test can prove that money is
  conserved. The ATM and gifts between people move money without touching the totals.
- The **economy is open**: employers, shops, landlords and the state are outside parties with
  no accounts of their own (D29).

Starting prices: a Späti snack €2, a Späti beer €1.50, a Döner €6, fries €3.50, coffee €3, a
Kneipe beer €4, a bag of groceries €9 (6 portions). Rent is €100–210 a week (that is
€450–900 a month), and wages are €11–20 an hour, after tax.

## What a person may do: requirements

`Requirements.check(sim, person, interaction, target)` answers "may this person start this
now?" with "" or a reason. The interaction menu shows the reason on a greyed-out entry
("Have a drink · €4.00 (not enough money)"), commands refuse with it, free will skips the
option, and the action system checks again when the action starts (the money may have gone
on the way). Reasons, added ticket by ticket: `closed` (outside opening hours or on a closed
day), `private` (someone else's home), `cant_afford`, `no_food` (empty fridge), `not_staffed`
(nobody serving), `not_your_job` (hidden) and `not_your_shift`, and `unknown_secret` (an
interaction unlocked by a discovery).

## Weekly cycle

| When | What |
|---|---|
| Monday 06:00 | Unemployment benefit and pensions are paid |
| Monday 08:00 | Rent and bills are due (from the bank) |
| Friday 18:00 | Wages for the week's shifts are paid |

**Unemployment benefit** is the floor that keeps the town from collapsing into mass
starvation, and it's very European. It pays a weekly base, plus the person's share of the
rent up to a cap, like the housing costs the German Jobcenter pays. NPCs are registered
automatically; the player registers once on the phone. People aged 67 or over are retired and
get a weekly pension instead of working.

## Shops and services

- A business lot has opening hours, optional **closed days** (most shops close on Sunday; the
  Späti, the Imbiss and the Kneipe don't) and **counters**: objects with "buy …"
  interactions, each with a price.
- From T-0065 counters sell **only while staffed**: someone is doing their on-site shift there.
  A shop whose staff didn't turn up is effectively closed.
- Stock is infinite. Real stock and deliveries come later (a crime hook: robbing the
  delivery van).
- M3 venues in the Altstadt: Späti Kaya (snacks, beer, groceries), Imbiss Anadolu (Döner,
  fries), Café Wolke (coffee), Kneipe Zum Anker (drinks), Waschsalon Blitz (laundry), a
  second-hand clothes shop and a barber (T-0073), and an ATM on the Altmarkt.

## Groceries

The only items in M3 (D29). Each household keeps a stock of **portions** in its fridge (it
holds 20). Cooking a meal uses 2 portions and grabbing a snack uses 1; an empty fridge greys
both out. A bag of groceries from the Späti adds 6 portions to the buyer's household (carrying
it home is abstracted). Free will goes shopping, anywhere in town, when the household's stock
runs low. A personal inventory (a beer in your pocket, stolen goods, tools) comes with M4.

## Jobs and careers

- **`JobDef`** (`data/jobs.json`): title, employer place, **session type** (`rabbit_hole` or
  `on_site`), the workplace object tag, the needs profile while working, a career track of
  **levels** (title and hourly wage), and **positions**. A position is one shift pattern
  (weekdays, from and to hours) that one person fills.
- **`WorkSession` interface** (D10), so any job can later become playable without touching
  the rest:
  ```
  begin(sim, person, employment)              # the shift starts (arrival, lateness)
  on_minute(sim, person, employment)          # during the shift: needs follow the job
  finish(sim, person, employment) -> WorkResult  # minutes worked, pay earned, performance
  ```
  - `RabbitHoleWork` (default): the person goes into the building (the Polizeiposten) or
    takes the tram from the stop (jobs outside the Altstadt) and is hidden for the shift.
  - `OnSiteWork`: the person stands behind a counter (the Späti, the Imbiss, the bar), and
    customers can buy there while they do.
  - `PlayableWork` (later): per job, for example a barista minigame. A registry maps the
    session type to an implementation.
- **Work is an action**: a `work` interaction on the workplace object that lasts until the
  shift ends. The action system handles walking there, slots, saving, tiers and leaving early
  (D29).
- **Obligations:** an hour before a shift, the player gets a reminder. At leaving time (the
  shift start minus the walk), NPCs, and the player when free will is on and they're idle,
  drop what they're doing, even sleep, and go.
- **Performance** (0–100, starting at 50) changes after every shift: up for working a full
  shift in a good mood, down for being late, leaving early or not turning up. It leads to
  promotion (the next level and a higher wage), a warning, or getting fired.
- **Applying** goes through the phone's Jobs app: vacancies are the unfilled positions. The
  interview is a check on presentation (hygiene, the outfit's formality), mood and later
  skills. Unemployed NPCs apply every Monday, and fired people's positions open up.
- **NPCs hold jobs**: shopkeepers, bar staff, police officers (rabbit hole until M4), and
  office, warehouse, care and building jobs in the city (by tram). Residents get a routine
  that fits their shift.

## Housing

- Every home lot has a **lease**: weekly rent from `district.json` and the household living
  there. Each member pays an equal share from the bank. Whatever isn't paid becomes
  **arrears**.
- Unpaid rent → a reminder → a warning → **eviction** after three weeks behind. The household
  leaves the flat. Evicted people sleep rough (park benches, the promenade) with an "evicted"
  moodlet, and recover through jobs, benefit and friends: anyone homeless who can pay two
  weeks' rent moves into an empty flat. Newcomers move into flats that stay empty.
- Buying property: M5.

## Health checks (sim report and `--check-m3`)

`tools/simrun.sh` reports money held (total and median), the ledger by reason, the employment
rate, shifts worked and missed, rent paid and owed, and evictions. The M3 check runs 30 days
and fails on mass bankruptcy (too many people broke), mass eviction, a broken ledger
(conservation) or an employment rate that collapses (T-0076).
