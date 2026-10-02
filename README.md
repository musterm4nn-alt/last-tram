# Last Tram

A single-player, top-down, open-world **life sim sandbox** set in a gritty modern European
town: The Sims meets GTA. Work, love, build a home, or live on the other side of the law,
while everyone else in town lives their own life and remembers what you did.

Built with **Godot 4.7**, entirely by AI agents: Claude Code (Opus 5.5) is the architect,
reviewer, artist and (for now) the builder; Muse Spark 1.3 in OpenCode playtests.

![The Altstadt district, placeholder graphics (M0)](docs/img/m0-altstadt.png)

## Play the current build

```bash
tools/run.sh
```

Or open Godot → **Import** → `project.godot` → press **F5**. On the owner's Mac, the
**Last Tram** icon on the desktop (`~/Desktop/Last Tram.command`) imports and runs the
main checkout. After cloning on a new machine, run `tools/setup.sh` once (it enables the
pre-commit check). Claude Code cloud sessions do this automatically at startup
(`.claude/settings.json`).

Keys (as the HUD shows them):

- Direct mode: WASD move · Shift run · E use · R/F stairs · Tab command mode · M map · P phone · Space pause · 1-3 speed · Wheel zoom · F5 save · F8 load · Esc menu · F9 report a bug
- Command mode: Click an object to use it, the ground to walk · Shift run · WASD / right-drag pan · R/F floors · Tab direct mode · M map · P phone · Space pause · 1-3 speed · Wheel zoom · Esc menu · F9 report a bug

## Where things are

| | |
|---|---|
| [docs/vision.md](docs/vision.md) | What the game is: pillars, tone, rules |
| [docs/roadmap.md](docs/roadmap.md) | Milestones M0–M7 and what you can do after each |
| [docs/workflow.md](docs/workflow.md) | **How to drive the agents** (start here) |
| [Last Tram Playbook](https://claude.ai/artifact/LPBmF4KMEeaBRh5zrJNEk8) | The owner's step-by-step route: what to do next, where, with which model (private) |
| [docs/playtesting.md](docs/playtesting.md) | Agent playtests: how Muse plays a build and reports |
| [docs/design/](docs/design/) | How each system works (time, world, people, character and looks, actions, tiers, jobs, social, crime, building, transport, UI, content packs) |
| [docs/architecture.md](docs/architecture.md) | How the code is organised and why |
| [docs/art.md](docs/art.md) | Art direction and the art pipeline |
| [tickets/](tickets/) | The work queue (`tools/tickets.sh`) |
| [AGENTS.md](AGENTS.md) / [CLAUDE.md](CLAUDE.md) | Rules for the AI agents |

## Status

M0, M1 and M2 are done. **M3 · Making a Living** is in progress. See the
[roadmap](docs/roadmap.md).
