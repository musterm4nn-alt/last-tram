---
description: Turn the owner's bug report or wish into a ticket (or fix it directly if tiny)
argument-hint: what happened / what you want
---
The owner reports: $ARGUMENTS

1. Ask at most one or two clarifying questions if the report is ambiguous. If they mention an
   F9 bug report, find it (the newest folder in the game's user data `bugreports/`) and use
   the replay tool once it exists (T-0015).
2. Reproduce it if you can: a failing test, `tools/simrun.sh`, or a screenshot.
3. If the fix is tiny and obvious (a few lines, no design question), fix it yourself on a
   branch with a regression test, run `tools/check.sh`, merge and push. Otherwise write a
   ticket (`tickets/README.md` format, with a regression test in the acceptance criteria),
   commit it on main and push.
4. If it's really a design change, update the relevant doc in docs/ as well.
5. Reply in plain language: what's wrong, what will happen, and what the owner should do next.
