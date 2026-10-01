---
id: T-0065
title: Staffed counters - shopkeepers behind the counters
status: draft
milestone: M3
size: L
owner: builder
depends_on: [T-0060, T-0057]
builder:
review_rounds: 0
---

## Goal
Shops are run by people. The Späti clerk, the Imbiss cook, the bartender and (new) the barista
at Café Wolke stand behind their counters during their shifts, visible, and the counters sell
only while someone is serving. If the late-shift clerk is ill, asleep or fired, the Späti
can't sell anything. This is the second `WorkSession`: on-site work.

## Read first
D10, D29; `docs/design/jobs-and-economy.md` → Shops and services; T-0059 (slot roles,
`WorkSessions`).

## Design (draft: detailed when its dependencies are merged)
- `OnSiteWork`: like `RabbitHoleWork` but visible, standing on a staff slot facing the
  customers. `WorkSessions` maps "on_site" to it.
- `InteractionDef.staffed: bool` on every counter purchase (snack, beer, Döner, fries,
  groceries, drinks and coffee). `Requirements`: `not_staffed` ("nobody's serving") unless
  someone performs on-site work on the same lot right now.
- A café counter at Café Wolke with barista positions (data); the Kneipe's pub tables and the
  café tables count as staffed through their lot.
- Positions cover the opening hours (tune `jobs.json` and the routines so shops are staffed
  while open). The HUD's place line says "Späti Kaya (nobody serving)" when it's open but
  unstaffed.
- simrun: the share of open minutes each shop was staffed.

## Acceptance (sketch)
- A clerk on shift stands behind the counter and you can buy; without them you can't, with
  the reason. Over 7 days, each shop is staffed for at least 90% of its open hours, and
  `--check-m2` still passes (people still eat). Screenshot of the clerk behind the Späti
  counter.

## Implementation notes

## Questions

## Review feedback
