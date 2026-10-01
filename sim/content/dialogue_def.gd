class_name DialogueDef
extends RefCounted
## Text for systemic dialogue (data/dialogue/*.json, T-0040): bubble lines per social
## interaction and outcome, conversation topics, and thought lines for urgent needs. Only the
## view reads it.

## What people talk about ({topic} in lines).
var topics: PackedStringArray = PackedStringArray()
## Interaction id -> outcome id -> lines.
var lines: Dictionary[String, Dictionary] = {}
## Need id -> thought line.
var needs: Dictionary[String, String] = {}
## Memory kind -> how the person inspector words it ("laughed at your joke", T-0041).
var memories: Dictionary[String, String] = {}
