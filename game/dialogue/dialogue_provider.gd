class_name DialogueProvider
extends RefCounted
## Turns a social exchange (the data of a &"social_exchange" event) into words to show
## (docs/design/social-and-dialogue.md → "The seam for LLM dialogue"). Words only: outcomes
## are always decided by the sim. SystemicDialogue is the M2 provider; an LLM one may follow.


## The line to show over the actor, or "" for none.
func line_for(_exchange: Dictionary, _sim: Sim) -> String:
	return ""


## The thought for an urgent need, or "" for none.
func thought_for(_need_id: String) -> String:
	return ""
