---
id: T-0042
title: Simulation tiers and the 'full lives' dial
status: draft
milestone: M2
size: L
owner: builder
depends_on: [T-0036, T-0039]
builder:
review_rounds: 0
---

## Goal
People far from the player are simulated cheaply (event-driven, abstract travel and actions); near the player in full detail; a setting switches everyone to full detail.

## Notes for the architect (to detail before this becomes todo)
- Exactly per docs/design/simulation-tiers.md, including the equivalence test (3 days full vs tiered, aggregates within tolerances), the round-trip test, and the budget report in simrun.
- Probably split into two tickets when detailed (background execution; promotion/demotion).

## Implementation notes

## Questions

## Review feedback
