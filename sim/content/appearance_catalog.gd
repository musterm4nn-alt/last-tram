class_name AppearanceCatalog
extends RefCounted
## Every choice the character creator offers, loaded from data/appearance/appearance.json.
## The dictionaries keep the file order: the creator shows options in that order.

var age_min: int = 18
var age_max: int = 100
var height_min: int = 120
var height_max: int = 230
var genders: Dictionary[String, GenderOption] = {}
var pronouns: Dictionary[String, PronounSet] = {}
var skin_tones: Dictionary[String, ColorOption] = {}
var hair_colours: Dictionary[String, ColorOption] = {}
var eye_colours: Dictionary[String, ColorOption] = {}
var hair_styles: Dictionary[String, NamedOption] = {}
var builds: Dictionary[String, NamedOption] = {}
var facial_hair: Dictionary[String, NamedOption] = {}
var features: Dictionary[String, NamedOption] = {}
