---
id: T-0079
title: Lone early-shift workers get a social life
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0065]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Nobody in town goes a whole week almost without talking to anyone just because of their shift
pattern. Today a loner who works early shifts (6–14) is out from 15 to 19, when most of the
town is at work, keeps their social need full with coffee and video calls, and talks to
people once or twice a week. The town check wants at least 3 conversations a week (a frozen
M3 rule; the owner chose on 2 October 2026 to fix the game, not the rule).

## Read first
T-0065's implementation notes ("About the seed 5 failure"), T-0077 and D30/D31 (the lone-worker
knife edge), `sim/ai/routines.gd` (`social_out_bonus`, out windows), `data/routines.json`,
`data/interactions/going_out.json`, `tools/town_check.gd`.

## The evidence (2 October 2026, cloud session)
- Fails `tools/simrun.sh --days=7 --check-m2 --gentle-work`: seed 5 (Sofia Petrović, early-shift
  warehouse worker, kindness −58, temper 79: 1 conversation; 23 coffees and 23 benches alone)
  and seed 11 (Stefan Bianchi 0 / Anouk Wójcik 1–3; `main` before T-0065 failed seed 11 too).
- The quietest residents are almost all Mon–Fri 6–14 / 7–15 workers.
- Rejected: small talk with the server on every purchase (the quietest resident of every town
  jumps to 23–61 conversations a week, so the rule stops meaning anything).

## Design (draft: to be detailed before building)
Ideas to measure, not decided: solitary "out" activities (coffee, benches, a drink) filling
less social need, so loners look for company; an early-shift routine whose out window overlaps
the evening crowd; the talk-while-out pull weighted towards people who have talked little this
week. Measure on seeds 1–12, both work modes, and keep the quietest resident's count honest
(no blanket inflation).

## Acceptance (sketch)
- [x] `tools/simrun.sh --days=7 --check-m2` passes on seeds 1–12 in both work modes, with the
  quietest resident per run reported in the notes before and after; the town's median
  conversations per person change by no more than ±25%.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (3 October 2026); D33. **The fix:** a video
call gives half the social it did (30 per hour instead of 60, advertising 25 instead of 45).
Calls had let loners fill their social need alone, so they never sought people.

Measured with a probe (quietest three residents and the median, 7 days), seeds 1–12, both
work modes:
- Before: failures on gentle 5 (Sofia Petrović, 0) and gentle 7 (Luca Meyer, 2); near misses
  gentle 11 (3) and gentle 10 (6); medians 63–150 (average about 110).
- After: no failures; the quietest resident of any run has 9 or more; medians 69–144
  (average about 115, +5%; per town between −22% and +40%).
`tools/simrun.sh --days=7 --check-m2 --check-staffing` passes on seeds 1–6 in both modes;
`tools/check.sh` passes (the laptop test uses the new rate). Not needed: the other ideas
(solitary outings filling less social, a later early-shift out window).


## Questions

## Review feedback
