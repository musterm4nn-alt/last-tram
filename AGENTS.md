# AGENTS.md: rules for every AI agent working on Last Tram

**Last Tram** is a single-player, top-down, open-world life sim (The Sims × GTA) set in a
gritty modern European town, built with **Godot 4.7 and typed GDScript**.

The owner **does not read code**. Your tests, `tools/check.sh`, screenshots and ticket notes
are the only proof that your work is correct, so make that proof real.

## Roles

- **Architect / reviewer / art: Claude Code (Opus).** Writes tickets, designs interfaces,
  reviews and merges to `main`, owns `docs/architecture.md`, `docs/decisions.md`, this file,
  and all art.
- **Builders: OpenCode models.** Implement **one ticket at a time**, on a branch, with tests.
- One agent works at a time.

## What to read

1. This file.
2. The ticket you're working on (`tickets/T-XXXX-*.md`), and **only** the docs it links.
3. [docs/conventions.md](docs/conventions.md) (how code, data and tests look) and
   [docs/cookbook.md](docs/cookbook.md) (step-by-step recipes). Read these before your first
   change.

Other docs, for when a ticket points you there: [vision](docs/vision.md) ·
[roadmap](docs/roadmap.md) · [architecture](docs/architecture.md) ·
[decisions](docs/decisions.md) · [design/](docs/design/) · [art](docs/art.md) ·
[workflow](docs/workflow.md).

## Commands

| Command | Use |
|---|---|
| `tools/check.sh` | Import + **all** tests + architecture lint. **Must pass before every commit** (the pre-commit hook runs it). |
| `tools/test.sh --filter=<text>` | Only matching tests, while you work. After adding files, use `check.sh`. |
| `tools/screenshot.sh out/<name>.png [--debug] [--zoom=N] [--walk=X,Y]` | Render the game to a PNG. Required for visible changes: **open the image and look at it**. |
| `tools/simrun.sh --days=1` | Run the sim headless and print a report. |
| `tools/tickets.sh [ready\|todo\|review\|...]` | List tickets and their status. |
| `tools/run.sh` | Start the game in a window. |

## The golden rules

1. **`sim/` is pure logic:** `RefCounted` only; no Nodes, scenes, signals, `Input`, `OS`,
   `Time`, `Engine`, `await`, or global random. (Lint-enforced.)
2. **`game/` never writes sim state.** It reads state and sends Commands with
   `Session.submit(...)`. Only `Session` steps the sim.
3. **Entities are referenced by int id** in saved state, never by object reference.
4. **Everything in the sim is saved.** New field → `to_dict()`/`from_dict()`. Changing the save
   shape → bump `SAVE_VERSION` + migration + fixture (see the cookbook).
5. **Determinism:** same seed + same commands = same result. Random numbers only from
   `sim.rng.stream("<system>")`.
6. **Content lives in `data/` JSON**, validated by `ContentDB`, not hard-coded.
7. **Static typing everywhere** (untyped declarations don't compile here).
8. **Every ticket adds tests** that prove its acceptance criteria.

## Builder protocol (implementing a ticket)

1. Pick the ticket you were given. If told "next ready ticket", run `tools/tickets.sh ready`
   and take the first one. Only tickets with `status: todo` whose `depends_on` are all `done`
   are ready.
2. `git checkout main && git checkout -b t/NNNN-short-slug`. (If the branch already exists
   because the ticket came back from review, check it out and read the "Review feedback"
   section first.)
3. In the ticket's front matter set `status: in-progress` and `builder: <tool> / <model>`.
4. Implement **exactly** the scope. Stay inside the files and areas the ticket names. If you
   must touch something else, explain why in your notes.
5. Write the tests from the acceptance criteria. Run `tools/check.sh` until it passes.
6. Visible change? Run `tools/screenshot.sh out/tNNNN.png ...`, open the PNG, and check it
   shows what the ticket asks.
7. Fill in the ticket's **Implementation notes**: what you did, key files, how you verified
   it (commands and results), anything uncertain or left out.
8. Set `status: review`. Commit (`T-NNNN: summary`), including the ticket file and any new
   `.uid` files. Push the branch: `git push -u origin HEAD`.
9. Stop. **Don't merge into `main`**, and don't start another ticket.

**Stuck?** (The ticket is unclear or contradicts the code, the design seems wrong, or you've
tried twice and the tests still fail.) Set `status: blocked`, write your question under
**Questions** in the ticket, commit, push, and stop. Asking is better than guessing.

## Definition of done

- Every acceptance criterion is met and covered by a test (or a screenshot for purely visual
  criteria).
- `tools/check.sh` passes; nothing unrelated changed; no debug prints or commented-out code.
- New classes and public functions have `##` doc comments; new data is validated.
- The ticket's notes let a reviewer verify the work without guessing.

## Never

- Never weaken, skip or delete a test to make it pass. Never `git commit --no-verify`.
- Never commit to `main` or merge (builders). Never force-push. Never rewrite history.
- Never edit `docs/architecture.md`, `docs/decisions.md`, `AGENTS.md`, `CLAUDE.md` or
  `project.godot`, unless your ticket explicitly says so.
- Never add plugins or addons, download code, or add third-party assets.
- Never create or edit art (Opus owns art).
- Never mix in unrelated refactors or "improvements".

## Content rules (game design, non-negotiable)

- There are **no children or teenagers** in the game. Every person is 18 or older; never
  generate, author or allow a younger age.
- **No pregnancy or childbirth** (and no adoption).
- No sexual-violence mechanics of any kind. No nudity or sexual content in character
  customisation.
- Romance is between adults, and intimacy fades to black.
