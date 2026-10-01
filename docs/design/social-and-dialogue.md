# Social life and dialogue (M2, deepened in M6)

## Social interactions

Person-targeted interactions (same data format as all interactions):

| Kind | Examples |
|---|---|
| Friendly | chat, joke, compliment, hug, share a drink, ask how they are |
| Romantic | flirt, kiss, ask on a date (the full ladder is in M6; intimacy fades to black) |
| Mean | insult, mock, argue, threaten, shove (fights: M4) |
| Practical | introduce yourself, exchange numbers, ask about someone (gossip), ask for a loan, apologise |
| Transactional (M3/M4) | buy from, hire, bribe, buy drugs |

## Conversations

Two people in a conversation stand or sit together, and each social action takes 1–3 game
minutes. NPCs chain actions while both still have social need or interest. Groups come later.

## Outcomes (systemic, deterministic)

```
acceptance = sigmoid( base(interaction)
                    + relationship(target → actor)
                    + mood(target) + personality compatibility
                    + charisma(actor) + presentation(actor)
                    + context (place, time, intoxication)
                    − target's urgent needs )
```

Rolled with rng stream `"social"`. The outcome (success / fail / awkward / backfire) produces
relationship deltas, memories ("X made me laugh at the Kneipe"), moodlets and skill XP.

Built in T-0038 (`Conversations`, `data/interactions/social.json`): chat, joke, compliment,
insult, argue and flirt, with success and fail outcomes. Awkward and backfire outcomes, charisma
and presentation come later.

## Knowing people

Strangers become acquaintances through familiarity; introducing yourself teaches names;
exchanging numbers adds a phone contact. M3's phone lists contacts and can call them
(T-0063); texts come later.

## Gossip

"Ask about someone" or autonomous gossip shares a **salient memory about a third person**.
The listener stores a *heard* memory (lower salience, source = the speaker) and their opinion
of the third person shifts, scaled by how much they trust the speaker. That's how
reputations, scandals and "everyone knows you stole from the Späti" spread. Distortion
(rumours that grow) comes later.

## Intimacy (M6)

Intimate interactions are social interactions in category `intimate`. They are always
consent-based (the target can refuse), only possible between people who are awake, sober
enough and close enough, never tied to crime or violence, and presented off-screen through a
scene. The owner can add their own adult presentation later with content packs
([content-packs.md](content-packs.md)).

## The seam for LLM dialogue

Every social action produces a **`SocialExchange`** record, emitted as an event:
`{tick, actor, target, interaction, outcome, topic, relationship snapshot, moods, place,
relevant memory ids}`.

A **`DialogueProvider`** turns it into what's shown on screen:

- **`SystemicDialogue`** (M2): icon bubbles plus short template lines from
  `data/dialogue/*.json`, with the topic chosen from memories and interests
  ("…complains about the rent", "…jokes about the tram strike"). Gritty wording is allowed.
- **`LlmDialogue`** (later): builds a prompt from the exchange, both personalities, the top
  relevant memories and the relationship, and asks a model (local via Ollama or an API) for
  1–2 short lines. It is asynchronous, with a timeout and fallback to systemic, cached, and
  switched on by a setting.

**Rule:** the LLM writes words only. Outcomes are always decided by the systemic model, so
gameplay stays deterministic and testable. If the LLM ever influences outcomes, it may only
pick from a fixed list of tags that the sim validates, and that is a separate decision.
