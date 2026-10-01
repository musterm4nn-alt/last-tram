class_name SocialOutcomeDef
extends RefCounted
## What one outcome of a social interaction does to both people (T-0038).

## Changes to the actor's view of the target (Relationship value -> amount).
var actor: Dictionary[String, float] = {}
## Changes to the target's view of the actor.
var target: Dictionary[String, float] = {}
## Moodlets started on the actor / the target ("" for none).
var actor_moodlet: String = ""
var target_moodlet: String = ""
## One-off need gains for the target (the actor's come from need_rates while performing).
var target_needs: Dictionary[String, float] = {}
## Both remember it as this memory kind, with this valence (−100..100).
var memory: String = ""
var valence: int = 0
