---
id: T-0038
title: Social interactions v1 - chat, joke, compliment, insult, argue, flirt
status: done
milestone: M2
size: L
owner: builder
depends_on: [T-0037]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Person-targeted interactions in the same data format as the rest. The actor walks next to
the other person and they exchange 1–3 minutes of talk. The outcome (success or fail) is rolled
from the target's view of the actor, their mood, personality and urgent needs, and it changes
relationships, memories, moodlets and needs on both sides. The player's menus come in T-0053;
free will choosing to talk comes in T-0039.

## Scope
Create `data/interactions/social.json`, `sim/content/social_def.gd`,
`social_outcome_def.gd`, `social_loader.gd`, `sim/social/conversations.gd`,
`sim/systems/social_actions.gd`, `tests/sim/test_social.gd`. Change
`sim/content/interaction_def.gd` and `interaction_loader.gd` (`target`, `social`),
`sim/actions/interactions.gd` (`offered_by_person`), `sim/commands/queue_interaction_command.gd`,
`sim/systems/action_system.gd`, `tests/sim/test_home_content.gd`.
**Out of scope:** UI (T-0053), autonomy (T-0039), bubbles (T-0040), gossip, groups.

## Specification
- Interactions with `"target": "person"` carry a `social` block: `kind` (friendly, mean,
  romantic), `base`, and `success` / `fail` outcomes (deltas to each one's view of the other,
  moodlets, the target's one-off need gains, and a memory kind and valence both keep).
- `Conversations.acceptance` = logistic(base + (target mood − 20)/40 + kind terms − urgent
  needs). Friendly adds friendship/25, familiarity/100 and (kindness + sociability)/200.
  Romantic adds friendship/50, romance/25 and (familiarity − 30)/50. Mean adds
  −friendship/50 and (actor temper − target bravery)/200. Urgent needs subtract
  max(0, 30 − lowest need)/15. The roll uses the "social" stream. `resolve` applies the
  outcome and emits `social_exchange` {actor_id, target_id, interaction_id, outcome, place_id,
  chance}.
- Actions on people (`SocialActions`): route to a free cell next to the target (8 neighbours,
  straight ones first), re-route if they move, give up after 10 minutes (`target_left`), and
  fail at once if the target is asleep or walking (`target_busy`). While performing, they end
  if either one moves (`moved` / `target_left`). The outcome is rolled when it finishes.
- Six interactions: chat, tell a joke, compliment, insult, argue, flirt (data in
  `social.json`).

## Acceptance criteria (`tests/sim/test_social.gd`)
- [x] Six person interactions load; objects never offer them; not with oneself.
- [x] A chat walks over, talks, and changes both relationships, memories and Social.
- [x] Friends accept more than strangers, strangers more than enemies; kindness helps;
  flirting with a stranger rarely lands.
- [x] Outcomes follow the odds and repeat with the seed; a landed insult hurts.
- [x] Nobody can be talked to while asleep; walking away ends it with no outcome.
- [x] Save mid-conversation = uninterrupted.
- [x] `tools/check.sh` passes.

## Implementation notes
- `test_home_content.gd` checks object interactions only (person ones are offered by people).
- Person-target actions use `slot_index` 0 and stamp `started_tick` when they set off, which
  `ROUTE_LIMIT_MINUTES` measures. Saves and validation stay unchanged.
- Verified: `tools/check.sh` 430 passed, 0 failed (`test_social.gd`, 8 tests).

## Questions

## Review feedback
