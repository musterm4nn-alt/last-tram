---
id: T-0063
title: The phone - bank, contacts and map
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0062]
builder:
review_rounds: 0
---

## Goal
Press P and your phone comes up. The Bank app shows your cash, your balance, what you spent
and earned lately ("Eat a Döner −€6.00", "Wage +€412.00"), when the rent is due and what you
owe. Contacts lists the people you know and how you get on, and you can call one to fill your
Social without walking over. Map opens the town map. The Jobs app (T-0064) and the Notebook
(T-0069) slot in later.

## Read first
`docs/design/controls-and-ui.md` (P, the HUD layout); `game/ui/town_map.gd`,
`game/ui/person_inspector.gd` (pure `lines()` helpers make UI testable); the statement entries
from T-0054 (`detail`).

## Design (draft: detailed when its dependencies are merged)
- `game/ui/phone/phone.gd` (a `CanvasLayer` panel at the bottom right, built in code): an app
  list, then one app at a time with a Back button; P toggles it (`InputActions.KEYS`), and so
  does Esc while it's open. The game keeps running (it doesn't pause).
- One file per app in `game/ui/phone/`: `bank_app.gd`, `contacts_app.gd`; Map opens the
  existing town map. Each has pure `static func lines(sim, player_id) -> PackedStringArray`
  for tests.
- Bank: cash and bank (`Money.format`), the statement newest first with the day and time and
  the detail in words (an interaction's or job's name), the next rent due and the arrears.
- Contacts: people with familiarity ≥ 30 (or added by a discovery or background later),
  sorted by friendship, with relationship words (`PersonInspector.relationship_label`).
- Calls: `CallCommand(person_id, other_id)` starts a `phone_call` interaction (30 min, Social
  for both) if the other person is available (awake, not at work, not busy); otherwise
  "No answer". A remote person interaction needs a small extension of `SocialActions` (no
  walking); if that grows past this ticket, split calls into their own ticket.

## Acceptance (sketch)
- P opens and closes the phone; the apps' lines for a known state; a call fills Social for
  both, and a busy contact doesn't answer. Screenshots of the bank and contacts apps.

## Implementation notes

## Questions

## Review feedback
