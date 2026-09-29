---
id: T-0038
title: Social interactions v1: chat, joke, compliment, insult, argue, flirt
status: draft
milestone: M2
size: L
owner: builder
depends_on: [T-0037]
builder:
review_rounds: 0
---

## Goal
Person-targeted interactions in the same data format: two people meet, stand together and exchange actions of 1–3 minutes; the outcome (success, fail, awkward, backfire) is rolled from relationship, mood and personality and changes relationships, memories, moodlets and the social need.

## Notes for the architect (to detail before this becomes todo)
- `target: "person"` interactions in data; slots next to the target person; conversation lifecycle (both stop, face each other, end when either leaves).
- Acceptance formula from social-and-dialogue.md with rng stream "social"; `SocialExchange` event.
- Flirting between adults only (everyone is); no intimacy (M6).

## Implementation notes

## Questions

## Review feedback
