# Content packs, scenes and the adult layer

The owner can extend Last Tram **without code**: add or change objects, clothes, interactions,
dialogue and short narrative **scenes** with text and images. That includes, if they choose,
their own **adult content**, which the core game never contains. The engine enforces the hard
content rules on every pack, so no data can switch them off.

## Content packs (M5)

- A pack is a **folder**: a `pack.json` plus data files laid out like the game's `data/`
  folder (`objects/`, `interactions/`, `clothing/items/`, `appearance/`, `names/`,
  `dialogue/`, `scenes/`), and `images/` for scene pictures (PNG).
- **Data only:** JSON and images (audio later). A pack can't contain scripts, and the game
  never runs code from a pack. That's what keeps the rules below enforceable.
- **Where packs live:** outside the repo, in the game's user data folder:
  `user://packs/<pack_id>/`. On macOS that's
  `~/Library/Application Support/Godot/app_userdata/Last Tram/packs/`. A different folder
  can be passed with `--packs-dir=PATH`. Packs are **not in git**, and AI agents never read
  them.
- `pack.json`:
  ```json
  { "id": "my_pack", "name": "My pack", "version": "1.0", "author": "me",
    "description": "What it adds", "adult": false, "load_after": [] }
  ```
- **Loading:** core `data/` first, then each enabled pack in the order set on the Packs
  screen (`load_after` is a hint). A pack can:
  - **add** definitions with new ids;
  - **override** a core or earlier pack definition by repeating its id with
    `"override": true` in that entry (without it, a repeated id is an error);
  - **extend** name lists (new names are appended).
- **Validation:** exactly the same checks as core content. A pack with errors isn't loaded;
  the Packs screen shows its errors in plain language, and the game still runs.
- **Saves** record the active packs (id and version). Loading a save without one of its packs
  shows a warning; things from the missing pack are dropped (unknown ids are skipped, never a
  crash).
- **Determinism:** packs are content, so the same packs + seed + commands give the same
  result. Bug reports record the active packs.
- **Tests and tools never load packs** (core content only), so agents' work never depends on
  them. A safe-for-work example pack in `examples/packs/` shows the format, and a test loads
  it.

## Scenes (M2)

- A **scene** is a short presentation moment: one or more pages of text, each with an
  optional image, shown in a popup. Think of a text adventure or a visual-novel page. The core
  uses scenes for flavour: the first night in the flat, waking up in hospital, getting out of
  jail, a memorable night at the Kneipe.
- Data (`data/scenes/*.json`):
  ```json
  { "id": "first_night_home", "adult": false,
    "pages": [ { "text": "The radiator ticks. Upstairs, someone is arguing about money." } ] }
  ```
- **Text templates:** `{actor}`, `{target}`, `{place}`, and pronoun forms such as
  `{actor.they}`, `{target.them}` and `{target.their}`, filled in from the event with each
  person's pronoun set.
- **Triggers:** an interaction's `presentation` (for example `{"scene": "first_night_home",
  "when": "finish"}`) or a sim event (hospital, jail, first day). The sim only emits
  `scene_requested {scene_id, actor_id, target_id, place_id}`; showing it is the view's job.
- **Scenes never change sim state.** Which text was shown doesn't matter to saves, replays or
  determinism. (Choices with effects may come later, as Commands.)
- **Variants:** a scene may declare `"variant_of": "<scene id>"` with optional conditions
  (kind of place, relationship level, time of day). When a scene is requested, the view picks
  among the base scene and its eligible variants. Adult variants are only eligible when adult
  content is on.

## Intimacy in the core game (M6)

- The romance ladder includes an intimate interaction ("Spend the night together", category
  `intimate`). Its core presentation is the scene **`intimacy_off_screen`**: fade to black, a
  neutral line ("Later…"), and fade back in. Needs, moodlets, memories and the relationship
  change like with any interaction.
- The core game never contains explicit content, and no agent (Opus or builders) writes any,
  including test fixtures and examples.

## The adult layer (M6): for the owner's own packs

- **Setting: "Adult content packs"**, off by default. Turning it on asks for confirmation that
  the player is 18 or older. While it's off, packs marked `"adult": true` and adult scene
  variants are never loaded or shown.
- What an adult pack typically adds: variants of `intimacy_off_screen` (text and images), and
  possibly extra intimate interactions, clothing or appearance options, all as data.
- **Engine-enforced rules.** They apply to every pack and no data can switch them off:
  1. **Adults only:** every person is 18 or older (validation + runtime checks).
  2. **Mutual consent:** intimate interactions always target a person and always go through
     consent. The target can refuse: NPCs decide by relationship, mood and attraction, and when
     the player is the target, the player is asked. No field can skip this.
  3. **Capacity:** intimate interactions are unavailable when either person is asleep,
     unconscious, heavily intoxicated, restrained or in custody, or when the relationship is
     below the romance threshold.
  4. **Never tied to crime or violence:** intimate interactions can't have a `crime` field, and
     validation rejects adult scenes attached to anything that isn't a consensual intimate
     interaction.
  5. **Data only:** packs can't add new mechanics that get around 1–4. There's also no
     pregnancy system to hook into (see [vision.md](../vision.md)).
- Where the rules live: `sim/social/intimacy_rules.gd` (runtime) and `ContentDB` validation,
  covered by tests with deliberately invalid fixture packs (neutral placeholder text only).

## For the owner: adding your own content later

The full plain-language guide (`docs/modding.md`) arrives with M5. The short version:
1. Create a folder in the game's `packs/` folder, and put a `pack.json` in it.
2. Add JSON files laid out like the game's `data/` folder. The easiest way is to copy the
   example pack from `examples/packs/` and change it.
3. Start the game, open **Packs** in the main menu, and enable your pack. Any mistakes are
   listed in plain words.
4. For adult content: set `"adult": true` in `pack.json`, switch on **Adult content packs** in
   Settings, and add scene variants for `intimacy_off_screen`, with your own text and images.
