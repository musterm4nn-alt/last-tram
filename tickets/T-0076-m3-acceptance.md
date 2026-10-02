---
id: T-0076
title: M3 acceptance - 30 days of a working town
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0065, T-0066, T-0070, T-0073, T-0074, T-0075, T-0078, T-0079]
builder:
review_rounds: 0
---

## Goal
Prove M3 is done: a 30-day headless run in which the economy stays stable (no mass
bankruptcy or evictions, the ledger balances, shops are staffed), and a test in which the
player gets hired, gets paid, pays rent and gets fired. Plus the owner's playtest checklist.

## Read first
The roadmap's M3 "Done when"; `tools/town_check.gd` and T-0045 (the M2 acceptance pattern).

## Design (draft: detailed when its dependencies are merged)
- `tools/economy_check.gd` (`EconomyCheck`, like `TownCheck`) and
  `tools/simrun.sh --days=30 --check-m3`. Fail on: the ledger not balancing at any day's
  end; more than 10% of people broke (under €5) at a day's end; more than one eviction; an
  employment rate that moves more than 20 points from the start; a shop staffed under 80%
  of its open hours; any M2 town-check failure; sim cost over budget. Seeds 1, 2 and 3.
- `tests/sim/test_m3_making_a_living.gd`: the player applies, is hired, works shifts, is paid
  on Friday, pays rent on Monday, misses shifts and is fired, with a save and load in the
  middle.
- An evening-and-a-week checklist for the owner in this ticket.

## Acceptance (sketch)
- `--check-m3` passes for 30 days on three seeds; the player-flow test passes; the roadmap
  marks M3 ▶ → waiting for the owner's playtest.

## Implementation notes

## Questions

## Review feedback
