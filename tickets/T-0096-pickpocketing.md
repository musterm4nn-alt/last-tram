---
id: T-0096
title: Pickpocketing
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0092]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The second crime with an action: the player can pick anyone's pocket. Unnoticed, it takes
cash and the victim never knows who; noticed, it takes nothing and the victim is a witness.

## Docs
[docs/design/crime-and-police.md](../docs/design/crime-and-police.md) "Crimes", "Being noticed"

## Scope
- `"pickpocket"` in `data/interactions/social.json` (target person, crime "pickpocketing",
  1 minute, social kind `"sneaky"`), moodlet `nearly_robbed`.
- `SocialDef.KINDS` + `"sneaky"`; `Conversations.acceptance` for it (logistic of base +
  the target's trust in the actor / 50); `Conversations.resolve` leaves no relationship
  change or memory when the outcome's deltas and memory are empty.
- `CrimeDef.steal_share` / `steal_max` (`"steals_cash"` in `data/crimes.json`, validated).
- `Crimes.commit(..., outcome)`: theft of cash (`Money.steal`, reason `"theft"`, the ledger
  unchanged), `Incident.stolen` (saved), `&"stolen"`; an unaware victim isn't a witness
  (`Witnesses.record(..., unaware)`). `ActionSystem` passes the social outcome on.
- HUD: theft and "caught" notices (`game/ui/crime_notices.gd`, `CrimeNotices`; the crime and
  police notices moved there from `Hud`, which was over 350 lines). Bank app: "Stolen".

**Out of scope:** NPCs picking pockets (T-0097), a stealth skill, victims finding out later,
items, gossip.

## Acceptance criteria
- [x] Content: the interaction, kind, crime and theft numbers →
  `test_pickpocketing.gd: test_pickpocketing_content`, `test_bad_theft_content_is_reported`
- [x] Unnoticed: half the cash, at most €40, no money made, the victim not a witness →
  `test_unnoticed_takes_half_the_cash_up_to_the_cap`, `test_empty_pockets`
- [x] Noticed: nothing taken, the victim a witness → `test_noticed_takes_nothing_and_the_victim_is_a_witness`
- [x] Trust makes it easier → `test_trust_makes_it_easier`
- [x] In play over 40 seeds, about 60% go unnoticed; each outcome leaves the right traces →
  `test_picking_pockets_in_play`
- [x] Saved and validated → `test_stolen_cash_survives_save_and_load`
- [x] Free will never picks it → `test_free_will_never_picks_a_pocket_for_the_honest`
- [x] Notices → `test_hud_place.gd: test_pickpocket_notices`, `test_police_notices`

## Implementation notes
Built and reviewed by the architect. `tools/check.sh` passes.
- The social roll decides whether the victim notices ("success" = unnoticed), so the walk
  over, standing next to them and the outcome reuse the person-action code (T-0038). The
  victim must be standing still (`Conversations.available`), as for a chat.
- Bystanders see a pickpocketing like any crime (sight range, walls); only the victim's own
  noticing is rolled.
- Also: speech-bubble lines for it (the thief "bumps into them"; caught: "Hey! Hands off!")
  and inspector words for the memories "caught_pickpocketing" and "saw_crime"; free will
  skips crime interactions on people too (`Autonomy`, tested by
  `test_free_will_never_picks_a_pocket_for_the_honest`). Two tests that list every person interaction
  (`test_social.gd`, `test_talk_to_people.gd`) now expect the new one at the end.
- No screenshot: the launch options can't target a person, and what's new on screen is the
  menu line and the notices (tested as text).
