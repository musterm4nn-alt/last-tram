---
id: T-0037
title: Relationships, memories and moodlets
status: draft
milestone: M2
size: M
owner: builder
depends_on: [T-0034]
builder:
review_rounds: 0
---

## Goal
People keep a directed relationship with everyone they meet (familiarity, friendship, romance, trust, fear), a capped list of memories, and moodlets that shift mood for a while.

## Notes for the architect (to detail before this becomes todo)
- Data model per docs/design/people.md; all saved by id; slow drift towards neutral without contact (per game day).
- Mood = needs + moodlets (update `Mood.compute`).
- Save version bump if the shape of existing data changes (probably not: new fields with defaults).

## Implementation notes

## Questions

## Review feedback
