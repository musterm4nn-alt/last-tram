# Crime and police (M4)

Crime is systemic: it's an interaction with a `crime` tag. It only matters if someone
**notices**, and it has **lasting consequences** through memory, gossip, records and police.

## Crimes (v1)

| Crime | Severity | Notes |
|---|---|---|
| Trespassing | 1 | being on a private lot without permission |
| Fare dodging | 1 | M7; ticket inspectors |
| Shoplifting | 2 | take an item from a shop without paying; stealth skill |
| Vandalism | 2 | graffiti, smashing things |
| Pickpocketing | 2 | steal cash or an item from a person; stealth vs. awareness |
| Drug possession / use | 2 | buying from a dealer, using |
| Drug dealing | 3 | an illegal job with customers and territory |
| Burglary | 4 | enter a home lot, steal items or cash; lockpicking; night |
| Mugging | 4 | threaten or force someone to hand over cash |
| Assault | 4 | a fight; injuries |
| Serious violence / killing | 8 | weapons (behind a content setting); NPC death is permanent |

**Hard rules:** there are no children or teenagers in the game (every person is an adult),
and there are no sexual-violence mechanics.

## Being noticed

- **Witnesses:** anyone in the active tier with line of sight (grid raycast, range shrinks at
  night) and awareness (not asleep, not deep in another action). Background-tier witnessing
  is rolled from how many people are on that lot.
- Each witness gets a **memory** ("saw X pickpocket Y at the Altmarkt") and **reacts**
  according to personality, relationship and bravery: flee, shout, intervene or fight, film it
  on their phone, **call the police**, confront later, ignore, or (later) blackmail.
- Victims always know they were robbed; they know *who* only if they saw.
- **Identification** depends on distance, light and your clothes' **concealment** (hood, cap,
  sunglasses, mask). A partial description ("hoodie, dark jeans, tall") can be shaken off by
  changing clothes ([character-and-appearance.md](character-and-appearance.md)).

## Police

- Officers are residents with the police job (on-site at the Polizeiposten, or on patrol
  between waypoints).
- **Dispatch:** a report creates an incident (location, crime, severity, and suspect: a known
  identity or only a description). Units respond by priority and distance, with a delay.
- **Heat and wanted level:** each person has heat per incident (identified or described).
  Player-facing **wanted level 0–5** summarises how hard the police are looking. Heat decays
  while you stay out of sight; being identified keeps it on record.
- **Built so far (T-0094):** the nearest on-duty officer runs to the reported crime, follows
  the suspect while they can see them and arrests them when they catch up: a fine of €50
  per severity point (cash, then the bank, which can go below zero), the case closed, a
  criminal record. Then they walk back to the desk. A call ends with the officer's shift.
- **Getting away (T-0095):** officers run a little slower than a running player. An officer
  who loses sight of you searches around where they last saw you for 10 minutes, then gives
  up; your stars then fade after 6 hours instead of 48, unless an officer spots you again
  (they turn round) or you're reported for something new.
- **Chase** on foot; officers tackle when adjacent. Losing line of sight for a while starts a
  search of the area, then they give up.
- **Arrest:** comply (cuffs, station, processing) or resist (escalation, an extra charge).
  Outcomes are a **fine** (from the bank, which can go into debt), a **night in the cell**, or
  **jail** as a time skip (days scale with severity and priors; needs are handled abstractly;
  the job may be lost). Each conviction adds a **criminal record** entry, which affects some
  job applications, police attention and what people think of you.

## Consequences that spread

Gossip spreads witness memories ([social-and-dialogue.md](social-and-dialogue.md)), so the
Späti owner may refuse to serve you, and your neighbours watch their wallets. Reputation in
the **underworld** is tracked separately: it rises with successful crimes and discretion, and
it unlocks contacts (fence, dealer, gang members) and illegal jobs.

## NPC crime

NPCs commit crimes through the same autonomy: when needs or money are desperate, or their
vice is high and honesty low, crime interactions score well. Their **risk cost** counts
visible witnesses, police nearby and bravery. Long headless runs must show believable rates
(`tools/simrun.sh` reports crimes per day by type).

## Health, injuries and death

Fights cause injuries and knock-outs. Hospital visits cost money. The player "dies" → wakes
up in hospital with a bill and a moodlet. NPC death is permanent; the household and friends
grieve (moodlets, memories); newcomers eventually move into the empty home.

## Later

CCTV at shops, evidence (stolen goods in your inventory, fingerprints), corrupt cops and
bribes, gangs and turf, car theft (with cars), prison life.
