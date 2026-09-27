class_name GenderOption
extends RefCounted
## One gender the character creator offers, from data/appearance/appearance.json.

var id: String = ""
var name: String = ""
## Id of a PronounSet in AppearanceCatalog.pronouns.
var default_pronouns: String = ""
## Keys of ContentDB.first_names, in the order the creator offers them.
var name_lists: PackedStringArray = PackedStringArray()
