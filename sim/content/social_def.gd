class_name SocialDef
extends RefCounted
## The social part of a person-targeted interaction (T-0038): its kind, how easily it lands,
## and what each outcome does. See Conversations for the acceptance roll.

const KINDS: PackedStringArray = ["friendly", "mean", "romantic"]
const OUTCOMES: PackedStringArray = ["success", "fail"]

## "friendly", "mean" or "romantic" (changes which personality and relationship values count).
var kind: String = "friendly"
## Starting point of the acceptance roll (logistic: 0 is a coin toss, +2 is about 88%).
var base: float = 0.0
## Outcome id ("success", "fail") -> what it does.
var outcomes: Dictionary[String, SocialOutcomeDef] = {}
