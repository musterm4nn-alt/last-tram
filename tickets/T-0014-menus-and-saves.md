---
id: T-0014
title: Esc menu, save slots, autosave
status: draft
milestone: M1
size: M
owner: builder
depends_on: [T-0020]
builder:
review_rounds: 0
---

## Goal
Esc opens a menu (resume, save, load, quit); three save slots plus rotating autosaves every game day at 03:00.

## Notes for the architect (to detail before this becomes todo)
- game/ui/pause_menu.gd; Session gains slot paths and autosave logic (a game-time check in Session, not sim).
- Loading shows the save's in-game date and real timestamp.
- The main menu from T-0020 gets a **Load** button listing the same slots, and Continue loads the newest save of any kind.

## Implementation notes

## Questions

## Review feedback
