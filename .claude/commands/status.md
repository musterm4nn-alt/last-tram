---
description: Plain-language project status, milestone progress and how each builder model is doing
---
Give the owner a short, plain-language status report (no code):

1. Current milestone and what the game can do right now (docs/roadmap.md + merged tickets).
2. Board summary from `tools/tickets.sh`: done / in review / ready / blocked / draft counts
   for the current milestone, and what's blocking progress, if anything.
3. Builder scoreboard: for each `builder` value in done tickets, the number of tickets, total
   `review_rounds`, and tickets per size. One sentence on which model seems better for what.
4. Health: run `tools/check.sh` on main and report pass/fail. Run `tools/simrun.sh --days=1`
   and mention anything odd.
5. A suggested next step.

$ARGUMENTS
