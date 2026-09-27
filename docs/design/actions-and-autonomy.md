# Actions and autonomy

How people *do* things: the player by command, NPCs (and the idle player) on their own.
Direct control and Sims-style control are two front ends to this **one** system.

## Interactions (data)

An **interaction** is something a person can do, defined in `data/interactions/*.json`:

| Field | Meaning |
|---|---|
| `id`, `name` | `"sleep"`, `"Sleep"` |
| `target` | `"object"` (with `object_tags`), `"person"`, `"self"` or `"cell"` |
| `duration` | fixed minutes, or "until need X is full" with min/max minutes |
| `need_rates` | per-hour need changes while performing (`{"energy": 12.5}`) |
| `finish_effects` | one-off effects at the end: needs, moodlets, skill XP, money, items, memories, relationship deltas |
| `advertise` | the need gains autonomy expects (for scoring); may differ from reality (a TV promises more fun than it gives) |
| `requirements` | skills, items, money, ownership/access, time window, relationship, life stage |
| `privacy` | wants to be alone in the room (toilet, shower) |
| `interruptible`, `priority` | how easily it's cancelled or overridden |
| `crime` (M4) | crime type and severity if witnessed |
| `anim` | animation tag for the view only |

Objects list which interactions they offer through their tags. People offer social
interactions (M2).

## Actions (runtime)

An **action** is one interaction a person is doing or has queued:
`{interaction_id, target_id, slot, state, progress_minutes, started_tick}`, stored in
`Person.action_queue` (saved).

States: `queued → routing → performing → done` (or `failed` / `cancelled`).

1. **routing:** reserve a free use slot on the target, path to it, and walk there. Fail if
   there's no path or no free slot.
2. **performing:** apply `need_rates` every minute and check the end condition.
3. **done:** apply `finish_effects`, emit an event, and move on to the next queued action.

The player can queue up to **6** actions (visible in command mode, each cancellable). NPCs
usually queue 1–2.

## Control modes

| | Direct mode (default) | Command mode (`Tab`) |
|---|---|---|
| Move | WASD / arrows | click the ground (walk there) |
| Interact | `E`: menu for the nearest interactable in front of you | click an object or person: menu |
| Camera | follows you | free pan (WASD / drag), zoom, level paging |
| Cancel | any WASD input cancels routing, or stands you up from a performing action | cancel button on the queue |

Both open the same interaction menu and submit the same `QueueInteractionCommand`.

**Free will** (setting: on / off): when on, an idle player (empty queue, no input for a
while) looks after their own needs with the same autonomy NPCs use. "Walk away and your
character looks after themselves."

## Autonomy (utility AI)

When a person is idle (queue empty), and at most every few minutes:

1. **Gather candidates:** interactions offered by objects and people within a search radius
   (M1: the current lot), plus routine options ("go to work", "go home", "go to the Kneipe").
2. **Score** each candidate:
   ```
   score = Σ over needs  urgency(need) × advertised_gain(need)
           × personality_modifier × mood_modifier
         − travel_cost(distance)
         − risk_cost            (crimes: witnesses, police nearby, honesty, bravery)
         + routine_bonus + memory_bias (seek friends, avoid enemies)
         + small noise
   urgency(v) = ((100 − v) / 100)² × weight(need)
   ```
   Urgency rises steeply as a need empties, so a desperate bladder beats a slightly bored
   mind.
3. **Pick** randomly among the top 3, weighted by score (rng stream `"autonomy"`), so
   people are sensible but not robotic.

## Routines and obligations (M2)

- Obligations are time windows that must be kept: work shifts, school, appointments. The
  person leaves early enough (travel time) and autonomy yields to them.
- Routine templates set the rhythm of a life: early-shift worker, office worker, night worker,
  student, unemployed, retiree, night-life/criminal. Each has sleep windows and preferred
  leisure places.
- Free time is filled by autonomy, with a bonus for the routine's preferred places.

## Background (abstract) execution

In the background tier ([simulation-tiers.md](simulation-tiers.md)) the same interaction
definitions are resolved abstractly: travel becomes a time estimate, effects are applied in
bulk, and the outcome is the same kind of result (needs, memories, events). One set of
content serves both tiers.
