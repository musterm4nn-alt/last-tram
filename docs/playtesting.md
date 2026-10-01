# Agent playtests

The owner's playbook "play" steps can be played by an agent: Opus runs **Muse Spark 1.3**
(free, xhigh) in OpenCode, unattended, and reads its report. It doesn't replace the owner's
own playtests at milestone ends; it catches what tests miss in between (confusing moments,
balance, residents who never use a new thing).

## Running it

```bash
opencode run -m "opencode/muse-spark-1.3-contributor-free#xhigh" --auto --title "Playtest: <step>" "$(cat out/<prompt>.md)" > out/<name>.log 2>&1
```

Run it in the background from a worktree whose code is the build to test, and don't change
that worktree's files while it plays (build the next ticket in a second worktree). A run takes
about 30–60 minutes. Afterwards, check `git status`: the playtester may only write in `out/`.

## The prompt

Copy the last one (`out/muse_playtest_shops_prompt.md`, kept here in outline) and change the
"What's new" part:
1. **Role:** playtester only. Never edit, create or delete anything outside `out/`, and no git.
2. **What's new:** the playbook step's text plus the facts a player would need (prices, cells
   of the new objects, opening hours, ids).
3. **How to play:**
   - `tools/screenshot.sh` with the options at the top of `game/main.gd`. `--walk-to` needs
     about 1600 frames to cross the town. A long `--advance` lets free will move the player,
     so the camera may not be where you expect, and `--interact` on an off-screen object
     clamps the menu into a corner.
   - Headless scripts in `out/`: the `extends SceneTree` pattern with
     `quit.call_deferred(0)` first, `SimFactory.new_game`, `QueueInteractionCommand`,
     `sim.run_minutes`, then read state and `sim.events.drain()`. **Game-layer classes
     (`Hud`, `InteractionMenu`, anything under `game/`) reference the `Session` autoload and
     don't compile in these scripts.** Use the sim-side rules instead: `Requirements.check`,
     `Money`, `Lots`, `Groceries`.
   - `tools/simrun.sh --days=7` for the whole town's numbers.
4. **What to do:** play the step as the owner would, then poke at the edges (being broke,
   closing times, walking away, save and load mid-action, what residents do).
5. **Report** in `out/playtest-<topic>.md`: Summary, Bugs (severity, steps, expected, a
   reproducing command), Confusing or unfun, Balance (numbers), Ideas, What you tested.

## After the report

Fix small things directly (with tests), turn bigger ones into tickets, note what the
playtest found in the ticket or commit, and tell the owner the highlights in game terms.

## History

- 2026-10-01, "Play: shopping in the Altstadt" (T-0054..T-0056): shopping worked end to end.
  Found: residents never used the new counters (fixed by T-0057); closed places didn't say
  when they open, both counters were labelled "Cou", and leaving a paid meal half-eaten said
  nothing (fixed together right after); the café gets almost no evening visitors (a known
  gap); money is too loose to bite until wages and rent arrive.
