# Last Tram: Vision

> Miss the last tram and the night decides what happens next.

**Last Tram** is a single-player, top-down, open-world **life sim sandbox** set in a gritty,
modern-day European town. It mixes **The Sims** (needs, careers, relationships, building a home)
with **GTA / BitLife** (crime, police, a town that reacts to you). There is no story and no
ending. You live whatever life you like, and so does everyone else in town.

It is a personal project and an experiment: the whole game is built by AI agents (Claude Code +
OpenCode), directed and playtested by its owner, who does not read code.

## The player fantasy

- **Live any life.** Hold down a job at the café, climb a career, rent a flat and make it
  yours, fall in love and move in together. Or sell pills behind the Späti, burgle the
  neighbours and run from the Polizei. Or both on the same day.
- **Be who you want.** Create your character in detail: name, age, body, face, hair,
  clothes. Your look keeps changing as you live: a haircut, new clothes, a scar from a bad
  night. See [design/character-and-appearance.md](design/character-and-appearance.md).
- **A town that lives without you.** Every resident has needs, a home, a job, a routine,
  friends and grudges. Stand still for a day and the town keeps going.
- **Everything is remembered.** People remember what you did to them and what they saw you
  do, and they tell others. Your reputation is what the town says about you.
- **Play your way.** Walk around directly (WASD, like GTA), or switch to Sims-style command
  mode and click to give orders. Pause any time. Walk away and your character looks after
  themselves.

## The four pillars

All four are core. They are built in phases (see [roadmap.md](roadmap.md)) on a shared
simulation foundation.

| Pillar | What it means |
|---|---|
| **Making a living** | Jobs and careers, wages, rent and bills, shops, unemployment benefit, buying property. Money is pressure, and pressure drives choices (including crime). |
| **People** | Friends, rivals, flatmates, dating, partners, marriage, adult relatives, gossip. Relationships and memories are simulated for everyone, not only the player. |
| **The other side** | Crime and police: theft, burglary, fights, drugs, fare dodging, witnesses, a wanted level, arrest, jail, a criminal record, the underworld. NPCs commit crimes too. |
| **Home** | Rent or buy a place, then furnish, decorate and rebuild it. Build mode with walls, doors, flooring, furniture and extra storeys. |

Underneath all four: **a living, systemic town.** Behaviour comes from needs + personality +
memory + circumstances, not from scripts.

## Design principles

1. **Systemic over scripted.** No quest scripts. Stories come from systems colliding: a
   broke resident with low honesty sees an open window.
2. **Everyone is a person.** The player is a resident like any other and runs on the same
   rules. NPCs can do anything the player can, including crime.
3. **Consequences persist.** Memories, reputation, records, debts, injuries, relationships.
4. **Readable simulation.** You should be able to tell *why* someone did something
   (a thought bubble, a needs panel, a memory list, the debug overlay).
5. **Built to be replaced.** Placeholders everywhere by design: placeholder art, "rabbit hole"
   jobs, systemic dialogue, a 2D view. Each sits behind an interface so the real thing can
   replace it later (3D isometric view, playable jobs, LLM dialogue). See
   [architecture.md](architecture.md#built-to-be-replaced).
6. **The owner playtests, the agents prove.** Every feature ships with automated tests and,
   when visual, a screenshot. Nobody needs to read code to know the game works.

## Setting and tone

- **Place:** a fictional, mid-sized Central-European city (working name **TBD**). Its flavour
  is German, Dutch, Czech and Polish: Altbau apartment blocks, cobbled squares, trams, canals,
  Spätis and Kneipen, Döner shops, a laundromat, the Polizei. Currency is the euro. Brands and
  names are fictional.
- **First district:** *Altstadt*: the canal, Hauptstraße with the tram line, the Altmarkt
  square, St. Nikolai church, Café Wolke, Kneipe Zum Anker, Späti Kaya, Imbiss Anadolu, a
  police post, and the player's ground-floor flat in Haus 12. More districts are added over
  time.
- **Look** (picked at the art gate, 3 October 2026, D35): top-down 3/4 pixel art drawn by
  Opus in a muted urban palette (route B), with people, their animations and objects made with
  PixelLab and recoloured to match. "B fits better."
- **Tone:** gritty and mature, with a wry sense of humour. Violence, drugs, gangs, poverty,
  eviction, addiction and adult themes are all in scope.
- **Hard content rules** (non-negotiable, for every agent):
  - **There are no children or teenagers in the game.** Every person is an adult (18+).
  - **No pregnancy or childbirth**, and so no adoption and no family with kids.
  - No sexual-violence mechanics of any kind.
  - Romance is in (dating, partners, moving in, marriage); intimacy happens off-screen
    (fade to black).
  - The core game never contains explicit content. The owner can add their own content
    later, including adult content packs (data only, off by default), and the engine holds
    that content to these rules too: adults only, mutual consent, never tied to crime or
    violence. See [design/content-packs.md](design/content-packs.md).

## Time and space

- **Time:** 1 game minute = 1 real second at 1x, so a day lasts 24 real minutes. Pause, 1x,
  2x, 3x, plus fast-forward while sleeping or working. Weeks matter (weekends, Sunday closing).
- **Lifespan:** an **ageless sandbox**. There is no forced ending, and ageing is a setting
  (off by default). If you die, you wake up in hospital with a bill; NPC deaths are permanent,
  and newcomers move into empty homes. With no births, newcomers moving to town are how the
  population renews.
- **Space:** a hand-made town on a grid (1 cell = about 1 m) with multiple floors per
  building. Interiors are seamless: no loading screens, and roofs hide when you are inside.

## Not planned for now

Multiplayer, code mods (content packs are data only), a procedurally generated city, realistic 3D graphics, voice acting,
console ports, monetisation, and a Steam release polish pass. Some of these may come later;
none should shape today's code, except that it must stay clean enough to allow them.

## Open decisions (the owner decides later)

- City name and exact country flavour.
- Whether and when to switch the view to 3D low-poly isometric.
- LLM dialogue: which model (local or API), and how much it may influence outcomes.
