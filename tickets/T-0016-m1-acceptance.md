---
id: T-0016
title: M1 acceptance: a day at home, proven headless
status: draft
milestone: M1
size: S
owner: builder
depends_on: [T-0011, T-0012, T-0013, T-0021]
builder:
review_rounds: 0
---

## Goal
A long headless scenario proves M1: the player with free will survives 3 days in the flat with healthy needs, and the sim report shows it.

## Notes for the architect (to detail before this becomes todo)
- tools/simrun.sh gains --free-will and a needs summary (min, avg per need).
- Test in tests/sim/test_m1_day_at_home.gd with explicit thresholds.
- The owner playtest checklist goes into the ticket for the final review, and starts with creating a character in the creator (T-0021).

## Implementation notes

## Questions

## Review feedback
