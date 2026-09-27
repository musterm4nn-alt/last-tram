---
id: T-0022
title: Split ContentDB into per-domain loader files
status: draft
milestone: M1
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Nothing changes in the game. `sim/content/content_db.gd` is about 620 lines after T-0005 and
T-0017 (the conventions say ~300), and T-0001, T-0006 and T-0018 each add more loading to it.
Split it by responsibility so builders work in small files.

## Notes for the architect (to detail before this becomes todo)
- Keep ContentDB's public API exactly as it is (fields, `terrain*()`, `need()`,
  `clothing_def()`, `place_at()`, `errors`, `is_valid()`), so no caller or test changes.
- Move the JSON readers (`_read_json`, `_str`, `_num`, `_bool`, `_arr`, `_obj`,
  `_str_array`) into one reader class that appends to the shared `errors`, and each domain
  (terrain, needs, names, appearance, clothing, world) into its own loader file in
  `sim/content/`. `load_from()` keeps the load order.
- A pure move: the existing content tests (`test_content`, `test_needs`,
  `test_appearance_content`) are the proof. Decide whether a lint test should flag files in
  `sim/` over ~350 lines.
- Schedule it before T-0001, T-0006 and T-0018 add more, and update their "Change:
  ContentDB" scope lines to name the new loader files.
