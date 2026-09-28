# Workflow: how to build Last Tram with AI agents

This page is for **the owner**: what to type, where, and in what order. You never need to read
code. The agents prove their work with tests, checks and screenshots.

**Your playbook:** [Last Tram Playbook](https://claude.ai/artifact/LPBmF4KMEeaBRh5zrJNEk8) is a private page that shows your next step,
the exact text to paste, and which model and reasoning level to use. Claude Code keeps it up
to date as tickets are merged and planned.

## Who does what

| Who | Tool | Job |
|---|---|---|
| **You** | your head, the game | Decide what the game should be. Playtest. Report what feels wrong. Approve art. |
| **Opus 5.5** (architect) | Claude Code | Plans milestones, writes tickets, designs interfaces, reviews and merges every ticket, does all art, and fixes anything a builder can't. |
| **Builders**: DS v4.1 Flash, Muse Spark 1.3 | OpenCode | Implement one ticket at a time on a branch, with tests. |

Only one agent works at a time, so there are never conflicts.

## The loop

```
  ┌──────────────► 1. PLAN (Claude Code)  /next
  │                     Opus makes sure the next tickets are written and says which to build.
  │                          │
  │                          ▼
  │               2. BUILD (OpenCode)  "Implement ticket T-0003."
  │                     Builder branches, codes, tests, runs checks, commits, sets status: review.
  │                          │
  │                          ▼
  │               3. REVIEW (Claude Code)  /review-ticket T-0003
  │                     Opus checks the work, then either merges it
  │                     or writes feedback (status: changes-requested) → back to 2.
  │                          │
  └──────────────────────────┘
          At the end of a milestone: /status, then you play the build.
```

### 1. Plan: in Claude Code

Type **`/next`**. Opus checks the board, writes or refines the next tickets if needed, and
tells you in plain words which ticket to hand to a builder (and which model it suits).

### 2. Build: in OpenCode

Start a **fresh session per ticket** (clean context works best) and type:

> Implement ticket T-0003. Follow AGENTS.md.

or simply:

> Do the next ready ticket. Follow AGENTS.md.

If the ticket came back with review feedback:

> Ticket T-0003 has review feedback. Address it. Follow AGENTS.md.

The builder works on a branch and ends by setting the ticket to `review`. If it gets stuck it
sets `blocked` and writes its question in the ticket. Take that to Claude Code.

**Which builder?** Tickets carry a size (S/M/L). Start with Muse Spark (xhigh) for L and
tricky M tickets and DS v4.1 Flash for S tickets, then adjust based on how they do. Each
ticket records the builder and how many review rounds it needed, and `/status` summarises
which model does best. That's part of the experiment.

### 3. Review: in Claude Code

Type **`/review-ticket T-0003`**. Opus reads the ticket and the diff, runs the checks, and
takes screenshots if the change is visible. Then it either:
- **merges** it into `main`, pushes to GitHub, and tells you what's new in plain words, or
- **sends it back** with specific feedback in the ticket (go to step 2 again).

If a builder fails the same ticket twice, Opus takes it over or splits it.

## Playing the current build

- In a terminal in the project folder: `tools/run.sh` (add `--debug` for the F3 overlay).
- Or open **Godot** → Import → choose `~/last-tram/project.godot` → press **F5**.

Keys so far: WASD to move, Space to pause, 1/2/3 for speed, mouse wheel to zoom, F5 to save,
F8 to load, F3 for the debug overlay, Tab for command mode (click the ground to walk there;
WASD or dragging with the right mouse button looks around).

## Reporting problems and wishes

- Just describe it to Claude Code in your own words: "The character walks through the
  fridge", "Nights feel too short", "I want to be able to smoke on the balcony". Opus turns
  it into a ticket, or fixes it directly if it's tiny.
- From M1 on: press **F9** in the game when something goes wrong. It saves a bug report
  (save file, recent inputs, screenshot) that an agent can replay exactly. Tell Claude Code
  "I pressed F9 because …".
- Design changes ("let's make NPCs gossip more") go to Opus too. It will update the docs
  and the plan.

## Art

All art goes through Claude Code (Opus). You approve it. Until the art gate after M3
everything is placeholder shapes on purpose. See [art.md](art.md).

## Safety nets (why nothing can quietly break)

- Every commit runs `tools/check.sh` automatically: all tests, compile checks and
  architecture rules. A failing commit is blocked.
- Builders never touch `main`; Opus reviews everything before merging.
- Everything is on GitHub (private), so any mistake can be rolled back.
- Saves are versioned, so old saves keep working as the game grows.

## Useful commands (for agents, or you if you're curious)

| Command | What it does |
|---|---|
| `tools/check.sh` | Import + all tests + architecture lint (runs on every commit) |
| `tools/test.sh --filter=save` | Only tests matching "save" |
| `tools/run.sh --debug` | Play the game |
| `tools/screenshot.sh out/x.png --zoom=0` | Save a screenshot and quit |
| `tools/simrun.sh --days=1` | Run the town headless and print a report |
| `tools/tickets.sh ready` | Tickets a builder can start now |
