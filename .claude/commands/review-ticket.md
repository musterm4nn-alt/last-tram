---
description: Review a builder's ticket branch, then merge it or send it back with feedback
argument-hint: T-XXXX
---
Review ticket $ARGUMENTS as the architect, following "Reviewing" in CLAUDE.md.

1. Read `tickets/$ARGUMENTS-*.md` (spec, acceptance criteria, implementation notes). Find the
   branch (`git branch -a | grep -i t/`), check it out, and read `git diff main...HEAD`.
2. Run `tools/check.sh`. For visible changes run the screenshots named in the ticket and look
   at them. For sim changes run `tools/simrun.sh` if it's relevant.
3. Judge: every acceptance criterion met and proven by a test that could actually fail; golden
   rules (AGENTS.md); saved state complete; no scope creep; readable, documented code; data
   validated; no weakened tests; notes are honest.
4. Pass → set `status: done` (keep `builder`, set `review_rounds`), commit on the branch, merge
   with `git checkout main && git merge --no-ff <branch>`, run `tools/check.sh` on main, push
   main, delete the branch locally and on origin. Then check whether later tickets need
   updating to match the real code.
5. Changes needed → write specific "Review feedback" in the ticket (what, where, what done
   looks like), set `status: changes-requested`, increment `review_rounds`, commit, push the
   branch, and check out main again. Trivial fixes you may make yourself instead (note them).
6. Tell the owner in plain language what the game can do now (with a screenshot if visible),
   or what was sent back and why, and what to do next.
