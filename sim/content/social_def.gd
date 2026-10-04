class_name SocialDef
extends RefCounted
## The social part of a person-targeted interaction (T-0038): its kind, how easily it lands,
## and what each outcome does. See Conversations for the acceptance roll.

const KINDS: PackedStringArray = ["friendly", "mean", "romantic", "sneaky"]
const OUTCOMES: PackedStringArray = ["success", "fail"]

## "friendly", "mean" or "romantic" (changes which personality and relationship values count),
## or "sneaky" (T-0096: done behind the target's back; "success" = they don't notice).
var kind: String = "friendly"
## Starting point of the acceptance roll (logistic: 0 is a coin toss, +2 is about 88%).
var base: float = 0.0
## Outcome id ("success", "fail") -> what it does.
var outcomes: Dictionary[String, SocialOutcomeDef] = {}
