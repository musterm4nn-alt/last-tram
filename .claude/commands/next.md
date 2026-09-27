---
description: Decide what happens next (write/refine tickets) and tell the owner which ticket to give a builder
---
You are the architect (see CLAUDE.md). The owner wants to know what to do next.

1. Run `tools/tickets.sh` and `git status`/`git log --oneline -10` to see where things stand.
2. If anything is in `review`, say so first: it should be reviewed with `/review-ticket` before
   more building. If anything is `blocked`, read its Questions and answer them in the ticket
   (update the spec), set it back to `todo`, and commit.
3. If fewer than 2 tickets are ready (`tools/tickets.sh ready`), turn the next `draft` tickets
   of the current milestone into fully specified `todo` tickets (re-read the merged code they
   build on first; follow tickets/README.md and the ticket-writing rules in CLAUDE.md). If the
   milestone has no drafts left, check the milestone's "done when" in docs/roadmap.md and
   propose the next milestone's tickets.
4. Commit ticket changes on `main` (`Tickets: ...`) and push. Add stops for the new tickets
   to the owner's playbook page (see "The owner's playbook page" in CLAUDE.md).
5. Reply to the owner in plain language (no code): what state the project is in, which ticket
   to hand to a builder next (id + one-line summary + suggested model: Muse Spark for L or
   tricky M, DS Flash for S), and the exact prompt to paste into OpenCode:
   `Implement ticket T-XXXX. Follow AGENTS.md.`

$ARGUMENTS
