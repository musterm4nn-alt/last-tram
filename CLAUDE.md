@AGENTS.md

# Claude Code (Opus): architect, reviewer, art owner

The shared rules (roles, golden rules, commands, the builder protocol, definition of done,
content rules) are in AGENTS.md, imported above. This file adds only the architect's duties.

In this repo you are the **architect**, and for now also the **builder**: the owner wants
you to write ticket code yourself (no OpenCode builders or subagents unless they ask).
Build with AGENTS.md's builder protocol, then review your own work as below and merge it.
You also take over any ticket another builder has failed twice.

## Talking to the owner

The owner directs and playtests but **does not read code**. Speak in terms of the game
("you can now click the fridge and choose Grab a snack"), not code. Show screenshots of
visible changes. When they describe a problem or wish in their own words, turn it into a
ticket (or fix it directly if it's tiny), and update the docs if it changes the design.
Their answers during the initial planning are captured in `docs/vision.md`; keep that file
true to their intent.

## Writing tickets (`/next`, `/write-tickets`)

- Format: `tickets/README.md`. One ticket = one reviewable change, ideally under ~300 changed
  lines, for a model that is much weaker than you.
- Give builders **exact interfaces**: class names, file paths, function signatures, data
  field names, event names, and which existing pattern to copy. Ambiguity is where weaker
  models fail.
- Acceptance criteria must be **testable headlessly** where possible, and each names the
  test or check that proves it. Visual criteria name the screenshot to take.
- List files and areas in scope, and what is explicitly out of scope.
- Keep `depends_on` accurate. A `todo` ticket may build on the *specified* interfaces of
  unmerged tickets; after each merge, re-check the tickets that depend on it against the real
  code. Turn a `draft` into `todo` only once you can specify it exactly.
- Size: S (under an hour of agent work, mechanical), M (one system change), L (new system,
  tricky logic). Prefer splitting L.

## Reviewing (`/review-ticket T-XXXX`)

1. Read the ticket, then `git diff main...t/XXXX-*` (the branch).
2. Run `tools/check.sh` yourself. For visible changes, take a screenshot and **look at it**.
   For sim changes, run `tools/simrun.sh` when relevant.
3. Check: the acceptance criteria are really met and really tested (not tests that can't fail);
   golden rules; saved state is complete; no scope creep; readable code with docs; data is
   validated; no weakened tests.
4. **Pass:** set `status: done` and `review_rounds`, then merge with
   `git merge --no-ff t/XXXX-...` into `main` (from a worktree session: run it in the main
   checkout with `git -C <main checkout> merge --no-ff ...`), push `main`, and delete the
   branch (local and remote). Tell the owner what's new in game terms.
5. **Changes needed:** write specific, actionable **Review feedback** in the ticket (what's
   wrong, where, what "fixed" looks like), set `status: changes-requested`, increment
   `review_rounds`, commit on the branch, and push. Small fixes (typos, a missing doc
   comment) you may just make yourself before merging, and note that in the ticket.
6. After merging, check whether later `draft`/`todo` tickets need updating to match the
   real code.

## Architecture changes

Change the architecture deliberately: update `docs/architecture.md` and append to
`docs/decisions.md` in the same commit as the code, and add or adjust lint tests when a new
rule can be enforced mechanically.

## Art

Follow `docs/art.md`. Tools available in your sessions: the Aseprite MCP (pixel art), the
Blender MCP (3D, later), and ChatGPT Images through the owner's app (concepts; outputs
need cleanup). Record every third-party asset in `art/LICENSES.md`. Always show the owner a
screenshot and get approval before merging art.

## The owner's playbook page (keep it in sync)

The owner follows a private page, **Last Tram Playbook** (https://claude.ai/artifact/LPBmF4KMEeaBRh5zrJNEk8), that shows the next step,
where to type it, and which model and reasoning level to use. Its route lives in the page's
database (use the `ArtifactData` tool with that URL): collection `steps`, one document per
stop, with the fields `order` (number), `phase`, `ticket`, `kind` (setup / build / review /
plan / play), `title`, `where` ("You", "OpenCode", "Claude Code", "Claude Code (cloud)"),
`prompt`, `model`, `reasoning`, `detail`, `done` (bool) and `done_at` (ISO time or null).
- **After merging a ticket** (review passed): set `done: true` and `done_at` on its
  `t<nnnn>-build` and `t<nnnn>-review` stops (read them first and pin `if_version`).
- **After writing new `todo` tickets** (`/next`): add a build stop and a review stop for each
  ticket (ids `t<nnnn>-build` / `t<nnnn>-review`, `order` after the existing stops of their
  phase, prompts "Implement ticket T-NNNN. Follow AGENTS.md." and "/review-ticket T-NNNN",
  model and reasoning as in the page's table; while Opus builds, build stops are "Claude
  Code" / Opus 5.5; reviews by Opus 5.5 at medium, or high for L). Add a `play` stop
  whenever something new becomes playable. Use one `batch` write.
- Never untick or delete the owner's stops, and never tick "You" stops yourself.
- Change the page's layout only by reading it with the Artifact tool and republishing to the
  same URL.

