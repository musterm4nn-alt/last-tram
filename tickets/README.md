# Tickets

One file per unit of work: `T-NNNN-short-slug.md`. The architect (Opus in Claude Code)
writes them; builders (OpenCode) implement them; the architect reviews and merges.
List them with `tools/tickets.sh` (or `tools/tickets.sh ready`).

## Lifecycle

```
draft ──► todo ──► in-progress ──► review ──► done
                        ▲               │
                        └── changes-requested
         (any state) ──► blocked  (question in the ticket; the architect answers)
```

| Status | Meaning | Set by |
|---|---|---|
| `draft` | Idea and goal only; not specified enough to build | architect |
| `todo` | Fully specified; **ready** once every `depends_on` ticket is `done` | architect |
| `in-progress` | A builder is working on it on branch `t/NNNN-slug` | builder |
| `review` | Builder is finished; waiting for review | builder |
| `changes-requested` | Review found problems; see "Review feedback" | architect |
| `blocked` | Builder needs an answer; see "Questions" | builder |
| `done` | Merged into `main` | architect |

## Format

```markdown
---
id: T-0001
title: Short imperative title
status: todo
milestone: M1
size: M                 # S | M | L
owner: builder          # builder | architect
depends_on: []          # e.g. [T-0003, T-0004]
builder:                # filled by the builder: "<tool> / <model>"
review_rounds: 0        # incremented by the architect per review that asked for changes
---

## Goal
What changes for the game, in one or two sentences.

## Read first
Links to the docs and code that matter (only those).

## Scope
Files and areas to create or change. **Out of scope:** what not to do.

## Specification
Exact interfaces: classes, functions, data fields, events, commands.

## Acceptance criteria
- [ ] Testable statement → how it's proven (test name, command, or screenshot)

## Implementation notes
(builder) What was done, key files, how it was verified, open issues.

## Questions
(builder, when blocked)

## Review feedback
(architect)
```

Rules: tickets are small (ideally under ~300 changed lines), and every acceptance criterion
names its proof. The builder and review-round fields make it easy to see which model does
well on which kind of work.
