# People

Everyone in town, including the player, is a `Person` with the same data and rules.
Starting numbers below are **initial tuning values**. They live in `data/`, not code, and will
be tuned by playtesting.

## Identity

- First name, last name and optional nickname. The player chooses them in the character
  creator; residents get them from name lists in `data/names/` (a Central-European mix:
  German, Turkish, Polish, Czech, Dutch, Italian, Syrian and other names).
- Age in years (**always 18 or older**) and **life stage**: young adult (18–29), adult
  (30–64), elder (65+). There are no children or teenagers in the game.
- Gender and pronouns, chosen independently (pronouns drive generated text).
- Appearance and outfit: see [character-and-appearance.md](character-and-appearance.md).

## Needs (M1)

Needs run 0–100, where 100 means fully satisfied. They decay per game hour and are refilled by
interactions.

| Need | Decay/h | Refilled by (examples) |
|---|---|---|
| Hunger | 6 | eating (fridge snack, cooking, Döner, café) |
| Energy | 4.5 | sleeping, napping, coffee (small) |
| Bladder | 12 | toilet (or, grittily, a Hinterhof corner) |
| Hygiene | 4 | shower, washing hands, sink |
| Fun | 6 | TV, games, bar, park, gossip, drugs (M4) |
| Social | 4 | talking, drinking together, calls |
| Comfort | 8 while standing, recovers when seated | sofa, bed, chairs, benches |

At 0, bad things happen: pass out (energy), wet yourself (bladder), faint or health loss
(hunger), and social consequences (hygiene).

## Mood

- Mood (−100..+100) = the sum of need contributions (only low needs hurt, on a steep curve)
  + **moodlets**.
- Moodlets are temporary modifiers with a source and a duration: "Slept well +10, 6 h",
  "Witnessed violence −25, 12 h", "Hungover −15, until noon", "Evicted −40, 3 days".
- Mood affects work performance, social success, autonomous choices (a bad mood leads to a
  drink or a fight) and crime likelihood.

## Personality (M2)

Seven axes, −100..+100, fixed at generation (they shift slowly with life events, later):

| Axis | Low ↔ High |
|---|---|
| Kindness | cruel ↔ caring |
| Honesty | deceitful, bends rules ↔ principled |
| Sociability | loner ↔ outgoing |
| Ambition | idle ↔ driven |
| Temper | calm ↔ hot-headed |
| Vice | restrained ↔ indulgent (drink, drugs, gambling) |
| Bravery | timid ↔ bold (fight or flee, intervene or look away) |

Discrete **traits** come later (night owl, neat, romantic, paranoid, gossip...).

## Skills (M1+)

Levels 0–10 grown by XP from actions: cooking, fitness, charisma, logic, handiness, fighting,
stealth. Later: driving and street smarts. Skills gate interactions and change outcomes.

## Health and body (M4)

Health 0–100, injuries (with healing time), intoxication (alcohol, drugs; wears off),
addiction levels (tolerance, withdrawal moodlets and need pressure).

## Relationships (M2)

A **directed** edge from A to B (A's view of B), created on first contact:

| Value | Range | Meaning |
|---|---|---|
| familiarity | 0..100 | stranger → knows by sight → knows well |
| friendship | −100..100 | enemy ↔ best friend |
| romance | 0..100 | attraction and romantic bond |
| trust | −100..100 | would lend money / would snitch on |
| fear | 0..100 | intimidation |

Tags carry roles: family (parent, offspring, sibling, cousin, partner, spouse, ex; all
adults), work (coworker, boss),
and others (landlord, tenant, dealer, client, "cop who arrested me"). Values drift slowly
towards neutral without contact.

## Memory (M2)

Each person keeps a capped list (for example the 60 most salient) of memory records:
`{tick, kind, subjects (ids), place, valence −100..100, salience 0..100 (decays), source
(experienced / witnessed / heard from X), details}`.

Memories drive relationship changes, gossip (sharing memories), witness reports to the police,
reputation, what people talk about, and later LLM dialogue prompts.

## Reputation

There is no global score. What someone thinks of you is their relationship with you plus
what they remember about you, including gossip. "Known as" labels (thief, violent, generous,
dealer) appear when enough people remember matching things. Underworld standing is tracked
separately (M4).

## Households (M2)

A household has members (one person, a couple, or flatmates sharing a WG), a home lot and,
from M3, shared money. The player controls one member; switching to another comes in M6.
There are no births: the population renews through newcomers moving to town.

## Content rules

- There are no children or teenagers: every person is 18 or older. Validation rejects
  younger ages, and a test checks every person the game creates.
- No pregnancy or childbirth (and no adoption).
- Romance is between adults (everyone is) and intimacy fades to black. No sexual-violence
  mechanics.
- Owner-made content packs, adult ones included, are held to the same rules
  ([content-packs.md](content-packs.md)).
