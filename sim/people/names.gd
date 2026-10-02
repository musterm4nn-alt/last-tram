class_name Names
extends RefCounted
## Helpers for people's names. Content lives in data/names/names.json; everyone in the game
## is an adult, and a name is 1..MAX_LENGTH characters.

## Longest name the game accepts, in characters.
const MAX_LENGTH: int = 24

## Letters (any language, e.g. "Jürgen", "Łukasz"; combining accents allowed), spaces,
## hyphens and apostrophes; must start with a letter.
static var _valid_name_regex: RegEx = RegEx.create_from_string("^\\p{L}[\\p{L}\\p{M} '\\-]*$")  # lint-ok: a compiled pattern


## True when `text` is a usable name, e.g. "Anne-Marie", "O'Neill", "Nguyễn".
static func is_valid(text: String, max_length: int = MAX_LENGTH) -> bool:
	if text.length() < 1 or text.length() > max_length:
		return false
	return _valid_name_regex.search(text) != null
