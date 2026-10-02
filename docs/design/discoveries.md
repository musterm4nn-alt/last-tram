# Secrets and discoveries (M3, deepened in M4)

The town hides things: rooms, stashes, habits and private lives. A **discovery** is
systemic content, not a story: anyone can *learn a clue* about it, and then *uncover* it by
being in the right place at the right time. Uncovering grants a concrete, testable effect.
There is no quest log, no marker and no required order, and the notebook only records what
a person already knows. (The idea comes from the owner's Small Hours prototype; this
document rebuilds it system-first, in `sim/`.)

Tickets: T-0067 (data and sim plumbing), T-0068 (searching and clues), T-0069 (the
Notebook and the map) and T-0070 (the first Altstadt secrets). A discovery's
`requires_discovery` interaction is one more rule in the shared requirements check (D29).

## Clues and discoveries

- A **clue** is a lead: one line of text plus the discovery id. It tells you what to look
  for and roughly where, not what is there. Clues are learned by:
  - **talking**: a person who knows the clue shares it when their trust in you is high
    enough (per-discovery threshold) — or when drunk (M4). People also share clues through
    autonomous gossip over time;
  - **doing**: notice boards, mail, bins and similar objects offer "read/check"
    interactions that teach a clue;
  - **exploring**: the **search** interaction (below) can surface the local clue instead
    of a find, so a lone player always has a path.
- **Uncovering** checks the discovery's requirements once per person and, on success,
  applies its effects and writes the moment into the notebook. Most v1 discoveries are
  uncovered through the place's `search` interaction; later content can add a named
  interaction instead.
- **Personal secrets** are a variant: the discovery is about a person. Others know the
  clue; uncovering means seeing the right thing at the right time (mail, a door, a
  routine), and the effect is usually a contact, a note or a memory, not money.

## Data

`data/discoveries/*.json`, loaded by a new `DiscoveryLoader` through `ContentReader` like
every other kind (`docs/conventions.md`; a content error fails tests). `DiscoveryDef`:

| Field | Meaning |
|---|---|
| `id`, `name` | `"kneipe_cellar"`, `"The door behind the bar"` |
| `clue` | the lead text shown in the notebook |
| `place_id` | the place it belongs to (validated against content) |
| `from`, `to` | time window in game minutes; wraps past midnight like lot hours |
| `level` | floor (`Vector3i.z`) it happens on |
| `clue_required` | `true`: only searchable with the clue; `false`: search can uncover directly |
| `share_trust` | trust needed to share the clue; `-1` = nobody shares it (search only) |
| `effects` | list of effect entries (below) |
| `scene` | optional scene requested on uncover, exactly like an interaction `presentation` (T-0043) |

Per-person state: **`Person.known_clues`** and **`Person.discoveries`**
(`PackedStringArray`, kept sorted for stable saves). Both are saved: `SAVE_VERSION` bumps,
with a migration and a v(n+1) fixture (golden rule 4). `from_dict` drops ids that content
no longer defines, like `World.from_dict` already does elsewhere.

Resource effects are **world-level, once per world**, not per person: fountain coins can't
be found by every resident. Knowledge (clues, notes, map annotations) is per person;
consumable rewards live in a saved `World` field (for example `looted_discoveries`) so the
economy ledger stays honest. All effects are integers or enums — validated at load.

## Effects (v1)

| Kind | Meaning |
|---|---|
| `note` | a line in the notebook and an annotation on the map; no mechanical change |
| `money` | a stash, in integer cents; world-once (ledger) |
| `item` | an inventory item; world-once. **M4**: M3 has no personal inventory (D29) |
| `moodlet` | a one-off moodlet, `data/moodlets.json` |
| `contact` | adds a phone contact (the M3 phone, T-0063) |
| `unlock_interaction` | an interaction that lists `requires_discovery` becomes offerable to this person |
| `clue` | a lead to another discovery: you learn its clue (T-0070: the tram notices lead to Haus 9) |

A discovery can also name a place in `known_at_start`: in a new town its residents or staff
know the clue, so locals have something to tell (T-0070).

Later effects — enabling a door object or shortcut, opening a hidden lot with its own
access rules, changing a price or service — arrive with M4/M5 world editing; they are the
reason the effect list is typed from day one.

## The search interaction

`search` ("Have a look around", 30 game minutes, small comfort/fun effect) is offered by
the **place** the person is on: a lot-level offer, one implementation path, because
discoveries are place-based. (Alternatives rejected: a `searchable` tag on one object per
place ties finding to furniture; per-discovery interactions don't scale in content.) The
time cost is the only limiter — no cooldown state is needed when nothing is left to find.

When it finishes at place P:

1. If the person knows a clue for an eligible discovery at P, and its requirements match
   (time, level, not already uncovered), uncover it.
2. Otherwise, if an eligible clue-not-known discovery exists at P and `clue_required` is
   `false`, learn its clue.
3. Otherwise, a "nothing here" line — and one small comfort effect, so the world still
   answers.

No rng: discoverability is deterministic and therefore trivially testable.

## Events and UI

Events (output only, `sim.emit_event`): `clue_learned {person_id, discovery_id, source,
source_id}` and `discovery_uncovered {person_id, discovery_id, place_id}`. Uncovering
always writes a **memory** (`kind` from the discovery) so gossip, the inspector and later
LLM dialogue can all see it.

- **Notebook** — a phone app (M3), player only: **Leads** (known clues, not yet uncovered;
  the place name, the clue text) and **Finds** (uncovered: what it gave you). The phone
  already exists as the M3 shell, so this is one more app.
- **Map**: hidden places do not appear until their discovery is uncovered; discovered ones
  get a small note icon (T-0048's map needs a knowledge filter; normal places are
  unaffected).
- **Notifications**: "You heard something about the Kneipe" / "You found the workbench",
  through the existing notice/hud path.

## Altstadt v1 content (examples to tune)

| id | Place | Clue source | Requirement | Effect |
|---|---|---|---|---|
| `tram_notices` | Hauptstraße tram stop | read the timetable case | any time | lead to `sublet_haus9`; note |
| `sublet_haus9` | Haus 9 | mail / a resident | evening | contact; note (someone lives there off the lease) |
| `kneipe_cellar` | Kneipe Zum Anker | the barkeeper, trust 40 | any time | note; M4 hook (after-hours gambling, break-in) |
| `spati_workbench` | Hinterhof | Kaya, after help | day | unlock `repair` interaction (handiness later) |
| `waschsalon_backroom` | Waschsalon Blitz | neighbourhood gossip | after closing | note; M4 hook (back door) |
| `st_nikolai_vestry` | St. Nikolai | the service board | weekday day | quiet `sit` spot; comfort moodlet |
| `fountain_coins` | Altmarkt | search at night | 22:00–04:00 | small money stash (world-once) |
| `promenade_alcove` | Promenade | search at night | 22:00–05:00 | unlock `sleep rough` (a dry spot; eviction path) |

Content rules apply to every clue and scene: adults only, no sexual-violence mechanics,
nothing explicit in the core game, and adult packs only change presentation (D17, D20).

## Tests

- Content: every `place_id` exists; time windows are valid; effects are known kinds;
  `requires_discovery` ids exist; a discovery that is `clue_required` has a reachable clue
  source (share_trust >= 0 or a clue-teaching interaction).
- Sim: learn a clue, uncover, assert effects, memory and events; resource effects fire once
  per world across two people; save/load round-trips `known_clues`, `discoveries` and the
  world result; a person with no clue can still find `clue_required = false` content; old
  saves load through the migration with empty sets.
- Fake pack content must not be able to add effects the validator doesn't know.

## Later (M4+)

- World-changing effects: a door object that was stuck becomes usable, a real shortcut,
  the cellar as a lot with access rules.
- Clue chains and distorted rumours: gossip spreads clues like memories, and they degrade.
- Intoxication changes what people tell (M4), and a very low trust can get a *false* clue.
- Personal secrets as leverage: blackmail, bribes, police informants, underworld standing.
- NPC discoveries: residents search and find on their own; the sim report counts clues and
  finds so the town stays alive without the player.
- Content packs can add or override discoveries — data only, never code.
