---
id: T-0015
title: F9 bug report and headless replay
status: draft
milestone: M1
size: M
owner: builder
depends_on: [T-0014]
builder:
review_rounds: 0
---

## Goal
Pressing F9 writes a bug report folder (the save at the last load/autosave, the command log since then, a screenshot, the current save) that tools/replay.sh can replay headless and check it reproduces the current save exactly.

## Notes for the architect (to detail before this becomes todo)
- Session already keeps command_log since load; it needs the 'start' save kept in memory (or on disk) at load/autosave time.
- tools/replay.gd: load start, apply commands at their ticks, run to the final tick, compare to the saved end state (Ser.to_json equality), print OK or first difference.
- This is the owner's main bug-reporting tool: make the output plain.

## Implementation notes

## Questions

## Review feedback
