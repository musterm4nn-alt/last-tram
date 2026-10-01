---
id: T-0039
title: Social free will - people seek company
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0038, T-0036]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Free will considers talking to people nearby, so neighbours chat at home and at the
Kneipe, couples flirt, and a hot-tempered person may insult someone they dislike. The
player's Social can be filled by people, not only the laptop.

## Scope
`sim/ai/autonomy.gd` (`_person_options`), `sim/ai/utility.gd` (`social_bias`),
`sim/ai/routines.gd` (`social_out_bonus`), `tests/sim/test_social_free_will.gd`; test
isolation in `test_relationships.gd` and `test_neighbours_live.gd`.

## Specification
- `Autonomy.candidates` adds every person-targeted interaction with each of the 3 nearest
  available people within the search radius on the same level, on lots the person may enter.
  The walking distance is the path to them. Score = need × routine factor + `social_bias`
  + `social_out_bonus` − travel.
- `Utility.social_bias`: friendly = friendship/25 + sociability/50. Mean = −4 − friendship/15
  + temper/40 − kindness/50. Romantic = −3 + romance/12 + friendship/50. A positive bias is
  ×2 × (share of Social still missing), so content people don't talk all day.
- `Routines.social_out_bonus`: friendly talk during the out window on a non-private lot gets
  0.6 × the going-out bonus (scaled by sociability), so people meet at the Kneipe and on the
  Altmarkt.

## Acceptance criteria (`tests/sim/test_social_free_will.gd`)
- [x] A lonely person talks to a friend in the room, and their Social rises.
- [x] Content people leave strangers alone.
- [x] Insults need dislike or a hot temper; romance needs romance.
- [x] Over 2 days: 100+ exchanges, 10+ new acquaintances outside households, and no flirting
  with people they feel nothing for.
- [x] `tools/check.sh` passes.

## Implementation notes
- Tuning by measurement (2 days, seed 1):
  - Unscaled bias gave 4,375 flirts (couples flirting nonstop). Scaling by missing Social
    brought it to 146.
  - Without the out bonus, nobody met anyone outside their household. A share of 1.2 gave
    4,923 chats (talking all evening); 0.6 gives 507 friendly exchanges, 137 flirts (all
    within couples) and 40 new acquaintances.
- Mean exchanges are rare: they need dislike, which builds from failed exchanges over days.
- Cost: a simulated day is now about 2.9 s (0.1 ms per step) with 31 people. Simulation tiers
  (T-0042) are where that gets cut.
- Verified: `tools/check.sh` 440 passed, 0 failed.

## Questions

## Review feedback
