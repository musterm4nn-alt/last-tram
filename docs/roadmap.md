# Roadmap

Milestones are ordered so each one builds on the last, and each ends with something the owner
can **play**. Ticket-level detail is written one milestone at a time (see
[workflow.md](workflow.md)); this page is the big picture.

Legend: ✅ done · ▶ current · ◻ planned

| # | Milestone | You can… | Status |
|---|---|---|---|
| M0 | Foundation | walk around the Altstadt; save and load | ✅ |
| M1 | A Day at Home | create your character, then live a full day in your flat: sleep, eat, shower, relax | ▶ |
| M2 | The Neighbours | watch ~30 residents live their lives, meet them, make friends and enemies | ◻ |
| M3 | Making a Living | get a job, earn, shop, pay rent (or don't) | ◻ |
| ◆ | Art direction gate | pick the art style from real side-by-side tests | ◻ |
| M4 | The Other Side | steal, fight, deal, get seen, get chased, get arrested | ◻ |
| M5 | Home Sweet Home | redecorate, rebuild, buy property; add your own content packs | ◻ |
| M6 | Love & Relationships | date, move in, marry, share a flat, play as your partner | ◻ |
| M7 | Getting Around | ride trams and buses to a second district | ◻ |

The order puts the social systems (M2) before crime, because crime needs witnesses and gossip,
and money (M3) before crime, because money is the motive. Build mode (M5) comes after objects,
ownership and money exist.

---

## M0 · Foundation ✅

The walking skeleton, which proves the architecture end to end.

- Godot 4.7 project; pure-logic `sim/` separate from the `game/` view
  ([architecture.md](architecture.md)).
- Fixed-step deterministic clock, seeded random streams, commands in, events out.
- Data-driven content (`data/`) with validation; Altstadt district as an ASCII map.
- Direct control (WASD) with wall collision; camera, HUD, F3 debug overlay.
- Versioned save/load with migrations, fixture saves and a "save mid-run equals uninterrupted
  run" test.
- Tooling: `tools/check.sh` (import + tests + architecture lint), `tools/simrun.sh` (headless
  sim), `tools/screenshot.sh`, pre-commit hook, ticket system.

## M1 · A Day at Home ▶

**Goal:** make your character, then the core Sims loop in one flat. Needs go down, you use
objects to fill them, and time passes.

- **Main menu and character creator**: name, gender and pronouns, age (18+), body, skin, hair,
  eyes, facial hair, features, and a starter outfit, with a live preview and randomise buttons
  ([design/character-and-appearance.md](design/character-and-appearance.md)). A name screen
  comes first, then the full creator.
- World objects from data (bed, fridge, stove, shower, sink, sofa, TV, kitchen table, and a
  desk with a laptop for video calls, the only way to fill Social until the phone in M3)
  with placeholder visuals.
- Grid pathfinding; click to walk.
- Needs (hunger, energy, hygiene, fun, social, comfort) and mood; needs panel.
- Interactions and the action queue: walk to the object, use it, finish, cancel.
- Control modes: direct (WASD + `E` to interact) and command (`Tab`: click objects for a menu,
  click the ground to walk). The player gets the same menu both ways.
- Free will: when idle, the player looks after their own needs (on/off in the Esc menu).
- Sleep fast-forward; autosave and save slots; Esc menu.
- **Bug report key (F9)** that captures a save, the command log and a screenshot, plus a
  headless replay tool, so any bug the owner hits can be reproduced by an agent.

**Done when:** a 3-day headless run with free will on keeps every need out of the red; the
owner creates a character and plays through a full day in the flat; save/load mid-action
continues identically.

## M2 · The Neighbours

**Goal:** the town is alive.

- Multi-storey buildings: levels, stairs, floor switching, roof cut-away.
- Places become lots (world state: owner, access rules, opening hours).
- Resident generation: names, personalities, looks and outfits (the same model as the
  player's), households including couples and flatmates, homes (~30 residents in Altstadt,
  all adults).
- Personality in the character creator: choose your character's traits.
- NPC autonomy with the same interactions the player uses; daily routines.
- **Simulation tiers:** full detail near the player, cheap background simulation elsewhere,
  with a fidelity dial that can be set to "full lives for everyone"
  ([design/simulation-tiers.md](design/simulation-tiers.md)).
- Social interactions v1 (chat, joke, compliment, insult, argue, flirt), relationships,
  memories, moodlets, thought/speech bubbles.
- Person inspector: click anyone to see their needs, mood, relationship to you and what they
  remember.
- **Scenes:** short text moments (with optional images) in a popup, triggered by interactions
  and events. They're flavour for now, and the base for the owner's own content later
  ([design/content-packs.md](design/content-packs.md)).

**Done when:** a 7-day headless run with 30 residents stays healthy (everyone eats, sleeps at
home, socialises, and relationships form); sim cost is within budget; the owner can watch the
town for an evening and it looks alive.

## M3 · Making a Living

**Goal:** money matters.

- Cash (wallet) and bank account; a ledger of every transaction.
- Shops and services (Späti, Imbiss, café, Kneipe): opening hours, staffed counters, buying
  food, drinks and items; inventory; fridge stock.
- Jobs and careers behind the `WorkSession` interface: "rabbit hole" (disappear into the
  building) and "on-site" (stand at a counter) implementations; performance, promotion, firing,
  applying.
- NPCs hold jobs (shopkeepers, bar staff, office workers, police officers).
- Rent, bills and eviction; unemployment benefit (keeps the economy from collapsing).
- Smartphone UI v1: contacts, jobs, bank, map.
- Clothes and looks: clothes shops, a wardrobe at home with saved outfits, clothes that get
  dirty (the Waschsalon), a barber. **Backgrounds** in the character creator (Newcomer, Local,
  Student, Ex-con, Burnout) set your starting money, skills and contacts.

**Done when:** a 30-day headless run keeps the economy stable (no mass bankruptcy or
evictions), and the player can get hired, get paid, pay rent and get fired.

## ◆ Art direction gate

After M3 the systems are real enough to judge a look. Opus (the art owner) produces the same
scene (Altmarkt + Haus 12, day and night) in two or three routes, for example:
1. an asset pack (LimeZu Modern Interiors/Exteriors, or Kenney),
2. AI-drawn pixel art made in Aseprite,
3. ChatGPT Images concepts cleaned up and palette-locked in Aseprite.

The owner picks one. Art production then runs alongside M4 and later, handled by Opus in
Claude Code. See [art.md](art.md).

## M4 · The Other Side

**Goal:** crime and consequences.

- Health, injuries, knock-outs, hospital. NPC death is permanent; the player respawns in
  hospital with a bill. Newcomers move into empty homes.
- Fights; weapons later.
- Crimes: trespassing, shoplifting, pickpocketing, burglary, mugging, assault, vandalism,
  buying, selling and using drugs.
- Witnesses (line of sight, awareness) and their reactions: flee, intervene, film, call the
  police, ignore.
- Police: officers as NPCs with a job, patrols, dispatch, wanted level (0–5), foot chases,
  arrest, fines, jail (time skip), criminal record.
- Reputation spreads by gossip; underworld contacts; illegal jobs (dealer, fence).
- NPCs commit crimes on their own when needs, personality and opportunity line up.
- Intoxication and addiction v1.
- Clothes matter for crime: hoods, caps and masks make you harder to identify, changing clothes
  helps you lose the police's description, and fights damage clothes and can leave scars.

**Done when:** crime → witness → report → police → consequences works end to end and persists
through save/load; NPC crime happens at believable rates in long headless runs.

## M5 · Home Sweet Home

**Goal:** build and own.

- Build/buy mode: buy, place, rotate, move and sell objects; walls, doors, windows, flooring,
  wallpaper, stairs and storeys.
- Renting versus owning: what tenants may change, deposits, landlords.
- Property listings and buying or selling homes.
- Home comfort score that affects mood.
- **Town editor:** build mode without limits that saves back to the district files, so the
  owner can hand-craft the town in-game.
- **Content packs:** add or override objects, clothes, interactions, dialogue, scenes and
  images with data-only packs from the game's data folder; a Packs screen; an example pack;
  and a plain-language guide (`docs/modding.md`) for the owner.

## M6 · Love & Relationships

**Goal:** relationships that go the distance.

- Romance ladder: flirt, date, partner, move in, marry; jealousy, cheating, breakups, divorce.
  Intimacy is off-screen (fade to black).
- **Adult content packs** setting (off by default, 18+ confirmation): the owner's own adult
  packs can replace the off-screen scene, within engine-enforced rules (adults only, mutual
  consent, never tied to crime or violence).
- Attraction settings in the character creator (who your character is attracted to).
- Households: couples and flatmates, merging, moving out, shared money.
- Switch control to another household member (your partner or a flatmate).
- Adult relatives (parents, siblings, cousins), a family tree, inheritance. Ageing setting
  (off / slow / normal) moves adults through young adult, adult and elder.
- **No children and no pregnancy**, per the content rules in [vision.md](vision.md), enforced by
  tests.

## M7 · Getting Around

**Goal:** a bigger town.

- Trams and buses: lines, stops, timetables, vehicles on track and road, boarding.
- Route planning for NPCs (walk vs. transit); transit in the background tier.
- Fare dodging and ticket inspectors.
- District 2, connected by tram (for example a Plattenbau estate or the harbour), with new
  jobs and homes.

## Later (unordered backlog)

- Bikes, e-scooters, cars: driving, parking, traffic, car theft (the vehicle model from M7 is
  built to allow this).
- Gangs, turf and factions.
- Playable jobs (barista, taxi, delivery runs) behind the `WorkSession` interface.
- LLM-generated dialogue behind the `DialogueProvider` interface.
- 3D low-poly isometric view as a second `view3d/` (the sim is unchanged).
- Business ownership (buy the Späti).
- Weather, seasons, holidays, events (strikes, football nights, Christmas market).
- Music, ambience, sound effects.
- Metro (level −1), more districts.
- Phone: messaging, social media, dating app.
- More looks: tattoos, piercings, makeup, hair that grows, tan, a body that changes with
  fitness and food. Large layered character portraits (the "paper doll").
