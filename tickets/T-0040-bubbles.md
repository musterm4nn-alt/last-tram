---
id: T-0040
title: Speech and thought bubbles
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0038]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Short bubbles over people: a template line from `data/dialogue/*.json` for each social
exchange ("...jokes about the tram", "...complains about the rent"), and thought bubbles
when a need goes critical ("Hungry..."). View only: bubbles read events and never change the
sim.

## Scope
Create `data/dialogue/lines.json`, `sim/content/dialogue_def.gd`, `dialogue_loader.gd`,
`game/dialogue/dialogue_provider.gd`, `systemic_dialogue.gd`, `game/ui/bubbles_layer.gd`,
`tests/game/test_bubbles.gd`. Change `sim/content/content_db.gd`, `game/main.gd`.

## Specification
- `ContentDB.dialogue` (`DialogueDef`): topics, lines per person interaction and outcome
  (validated: person-targeted interactions, known outcomes, non-empty), and a thought per need.
- `DialogueProvider` (the LLM seam: `line_for(exchange, sim)`, `thought_for(need)`);
  `SystemicDialogue` picks a line and a `{topic}` from a hash of the exchange, so the same
  exchange always gets the same words, and it never uses the sim's random streams.
- `BubblesLayer`: `social_exchange` → the actor's speech bubble, `need_critical` → a thought
  bubble. Each lasts 3.5 s (fading in its last second), only for people on the viewed floor.
  The newest is drawn first, and a bubble that would cover it waits.

## Acceptance criteria
- [x] Dialogue covers every social interaction and outcome and every need →
  `test_bubbles.gd`.
- [x] Lines fill in a topic, repeat for the same exchange and vary between exchanges.
- [x] Events make bubbles that fade; other events don't.
- [x] Screenshot `out/t0040.png` (Mon 21:17): bubbles over people at the Kneipe and on the
  Altmarkt, none overlapping.

## Implementation notes
- The first screenshot showed bubbles piling up at the busy Kneipe; overlapping ones are now
  skipped until there's room.
- Verified: `tools/check.sh` 443 passed, 0 failed.

## Questions

## Review feedback
