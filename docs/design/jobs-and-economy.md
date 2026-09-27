# Jobs and economy (M3)

## Money

- Stored as **integer euro cents** (no float drift). Displayed as `€12.50`.
- **Cash** (wallet; can be pickpocketed or robbed) and **bank** (card payments, wages, rent;
  safe from street crime). ATMs move money between them (later).
- A **ledger** records every transaction: tick, from, to, amount, reason. It's used for
  debugging, the bank app, tests ("money is conserved except at declared sources and sinks")
  and the sim report.

Starting prices (tuned later): Döner €6, coffee €3, Kneipe beer €4, Späti beer €1.20, a
meal's groceries €3, a flat's rent €450–900 per month, wages €13–25 per hour.

## Weekly cycle

Rent and bills are due Monday and wages are paid Friday. **Unemployment benefit** (weekly,
if unemployed and registered) is the floor that keeps the town from collapsing into mass
starvation. It's also very European.

## Shops and services

- A business lot has opening hours (Sunday closing!), a price table, and **counters** (objects)
  that offer "buy …" interactions **only while staffed** by an on-site worker.
- Stock is infinite at first. Real stock and deliveries come later (a crime hook: robbing
  the delivery van).
- M3 venues in Altstadt: Späti Kaya (snacks, drinks, beer, cigarettes, phone credit), Imbiss
  Anadolu (Döner, fries), Café Wolke (coffee, cake), Kneipe Zum Anker (beer, schnapps, gossip),
  Waschsalon Blitz (laundry, later).

## Items and inventory

Item definitions (food, drinks, alcohol, tobacco, phone credit, tools; drugs in M4), a small
personal inventory, and household storage (the fridge). Items are used through interactions
("eat snack", "drink beer").

## Jobs and careers

- `JobDef`: title, employer (business lot), **career track** (levels with title, hourly wage,
  shift pattern, requirements such as skills or a clean record, and performance weights),
  legal or illegal, and **session type**.
- **`WorkSession` interface**, so any job can later become playable without touching the rest:
  ```
  begin(sim, person, job)          # arrive at work
  on_minute(sim, person)           # during the shift
  finish(sim, person) -> WorkResult  # hours, pay, performance delta, events
  ```
  - `RabbitHoleWork` (default): the person enters the building and disappears; needs decay
    by the job's profile, and performance follows mood and skills.
  - `OnSiteWork`: the person stands at a work-station object (the Späti counter, the bar tap,
    the police desk) and customers can interact with them. This is what makes shops "staffed".
  - `PlayableWork` (later): per job, for example a barista minigame. A registry maps job id →
    implementation, with the rabbit hole as fallback.
- Performance goes up or down daily (mood, skills, lateness, absence) → promotion, warning,
  demotion, firing. Applying for jobs goes through the phone's jobs app; the "interview" is a
  charisma and record check.
- NPCs hold jobs: businesses have positions filled at town generation, and vacancies are
  refilled from the unemployed and from newcomers.

## Housing

- Homes are lots with rent and a landlord (an NPC or a housing company).
- Unpaid rent → reminders → eviction after a few weeks → homelessness (sleeping in the park,
  on benches or at friends'). It can be recovered from: jobs, benefit, friends.
- Buying property: M5.

## Health checks (sim report)

`tools/simrun.sh` reports the employment rate, median cash, number of evictions and money in
circulation. A 30-day run must stay stable.
