class_name CharacterSpec
extends RefCounted
## Describes a character before the game starts: what the character creator fills in.
## Validates itself, can make a random one, and creates the player via apply_to().
## Everyone in the game is an adult (age 18+); validation never allows younger ages.


var first_name: String = ""
var last_name: String = ""
var nickname: String = ""
var gender: String = ""
var pronouns: String = ""
var age_years: int = 18
var appearance: Appearance = Appearance.new()
var outfit: Outfit = Outfit.new()


## One message per problem with names, gender, pronouns, age, appearance and outfit.
func validate(content: ContentDB) -> PackedStringArray:
	var problems := PackedStringArray()
	if not Names.is_valid(first_name, 24):
		problems.append("first name '%s' is not a valid name (1..24 letters)" % first_name)
	if not Names.is_valid(last_name, 24):
		problems.append("last name '%s' is not a valid name (1..24 letters)" % last_name)
	if not nickname.is_empty() and not Names.is_valid(nickname, 16):
		problems.append("nickname '%s' is not a valid name (1..16 letters)" % nickname)
	if not content.appearance.genders.has(gender):
		problems.append("unknown gender '%s'" % gender)
	if not content.appearance.pronouns.has(pronouns):
		problems.append("unknown pronouns '%s'" % pronouns)
	if age_years < Person.MIN_AGE:
		problems.append("age %d is below %d (everyone in the game is an adult)" % [age_years, Person.MIN_AGE])
	elif age_years < content.appearance.age_min or age_years > content.appearance.age_max:
		problems.append("age %d is outside %d–%d" % [age_years, content.appearance.age_min, content.appearance.age_max])
	for problem: String in appearance.validate(content):
		problems.append(problem)
	for problem: String in outfit.validate(content):
		problems.append(problem)
	return problems


## The default player from data/appearance/default_player.json (via ContentDB).
static func default_player(content: ContentDB) -> CharacterSpec:
	return CharacterSpec.from_dict(content.default_player)


## Deterministic random character. Draws from `rng` in this order: gender, pronouns, name
## list, first name, last name, age, then Appearance.random() and Outfit.random().
static func random(content: ContentDB, rng: RandomNumberGenerator) -> CharacterSpec:
	var out := CharacterSpec.new()
	var catalog: AppearanceCatalog = content.appearance
	var gender_ids := catalog.genders.keys()
	out.gender = String(gender_ids[rng.randi_range(0, gender_ids.size() - 1)])
	var gender_opt: GenderOption = catalog.genders[out.gender]
	if rng.randf() < 0.9:
		out.pronouns = gender_opt.default_pronouns
	else:
		var pronoun_ids := catalog.pronouns.keys()
		out.pronouns = String(pronoun_ids[rng.randi_range(0, pronoun_ids.size() - 1)])
	var list_id := String(gender_opt.name_lists[rng.randi_range(0, gender_opt.name_lists.size() - 1)])
	var firsts: PackedStringArray = content.first_names[list_id]
	out.first_name = String(firsts[rng.randi_range(0, firsts.size() - 1)])
	out.last_name = String(content.last_names[rng.randi_range(0, content.last_names.size() - 1)])
	out.nickname = ""
	# Never below 18, even if the content's age range were wrong.
	out.age_years = rng.randi_range(maxi(Person.MIN_AGE, catalog.age_min), maxi(Person.MIN_AGE, catalog.age_max))
	out.appearance = Appearance.random(content, rng)
	out.outfit = Outfit.random(content, rng)
	return out


## Copies everything onto `person` (appearance/outfit via copy()).
func apply_to(person: Person) -> void:
	person.first_name = first_name
	person.last_name = last_name
	person.nickname = nickname
	person.gender = gender
	person.pronouns = pronouns
	person.age_years = age_years
	person.appearance = appearance.copy()
	person.outfit = outfit.copy()


func to_dict() -> Dictionary:
	return {
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname,
		"gender": gender,
		"pronouns": pronouns,
		"age_years": age_years,
		"appearance": appearance.to_dict(),
		"outfit": outfit.to_dict(),
	}


static func from_dict(d: Dictionary) -> CharacterSpec:
	var out := CharacterSpec.new()
	out.first_name = String(d.get("first_name", ""))
	out.last_name = String(d.get("last_name", ""))
	out.nickname = String(d.get("nickname", ""))
	out.gender = String(d.get("gender", ""))
	out.pronouns = String(d.get("pronouns", ""))
	out.age_years = int(d.get("age_years", 18))
	var appearance_data: Variant = d.get("appearance", {})
	if appearance_data is Dictionary:
		out.appearance = Appearance.from_dict(appearance_data)
	var outfit_data: Variant = d.get("outfit", {})
	if outfit_data is Dictionary:
		out.outfit = Outfit.from_dict(outfit_data)
	return out
