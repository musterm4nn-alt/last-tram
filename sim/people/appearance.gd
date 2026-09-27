class_name Appearance
extends RefCounted
## What a person looks like: body, face and hair. Saved sim state (see Person).
## Ids refer to AppearanceCatalog in ContentDB; validation reports unknown ids.


var skin_tone: String = ""
var height_cm: int = 175
var build: String = ""
var hair_style: String = ""
var hair_colour: String = ""
var eye_colour: String = ""
var facial_hair: String = "none"
var features: PackedStringArray = []


## One message per problem, e.g. "unknown skin tone 'x'".
func validate(content: ContentDB) -> PackedStringArray:
	var problems := PackedStringArray()
	if not content.appearance.skin_tones.has(skin_tone):
		problems.append("unknown skin tone '%s'" % skin_tone)
	if height_cm < content.appearance.height_min or height_cm > content.appearance.height_max:
		problems.append("height %d cm is outside %d–%d" % [height_cm, content.appearance.height_min, content.appearance.height_max])
	if not content.appearance.builds.has(build):
		problems.append("unknown build '%s'" % build)
	if not content.appearance.hair_styles.has(hair_style):
		problems.append("unknown hair style '%s'" % hair_style)
	if not content.appearance.hair_colours.has(hair_colour):
		problems.append("unknown hair colour '%s'" % hair_colour)
	if not content.appearance.eye_colours.has(eye_colour):
		problems.append("unknown eye colour '%s'" % eye_colour)
	if not content.appearance.facial_hair.has(facial_hair):
		problems.append("unknown facial hair '%s'" % facial_hair)
	for feature: String in features:
		if not content.appearance.features.has(feature):
			problems.append("unknown feature '%s'" % feature)
	return problems


func copy() -> Appearance:
	var out := Appearance.new()
	out.skin_tone = skin_tone
	out.height_cm = height_cm
	out.build = build
	out.hair_style = hair_style
	out.hair_colour = hair_colour
	out.eye_colour = eye_colour
	out.facial_hair = facial_hair
	out.features = features.duplicate()
	return out


func to_dict() -> Dictionary:
	return {
		"skin_tone": skin_tone,
		"height_cm": height_cm,
		"build": build,
		"hair_style": hair_style,
		"hair_colour": hair_colour,
		"eye_colour": eye_colour,
		"facial_hair": facial_hair,
		"features": Array(features),
	}


static func from_dict(d: Dictionary) -> Appearance:
	var out := Appearance.new()
	out.skin_tone = String(d.get("skin_tone", ""))
	out.height_cm = int(d.get("height_cm", 175))
	out.build = String(d.get("build", ""))
	out.hair_style = String(d.get("hair_style", ""))
	out.hair_colour = String(d.get("hair_colour", ""))
	out.eye_colour = String(d.get("eye_colour", ""))
	out.facial_hair = String(d.get("facial_hair", "none"))
	out.features = PackedStringArray()
	var stored: Variant = d.get("features", [])
	if stored is Array:
		for entry: Variant in (stored as Array):
			out.features.append(String(entry))
	return out


## Deterministic random appearance; draws from `rng` in field order.
static func random(content: ContentDB, rng: RandomNumberGenerator) -> Appearance:
	var out := Appearance.new()
	var catalog: AppearanceCatalog = content.appearance
	out.skin_tone = _pick(catalog.skin_tones.keys(), rng)
	out.build = _pick(catalog.builds.keys(), rng)
	out.hair_style = _pick(catalog.hair_styles.keys(), rng)
	out.eye_colour = _pick(catalog.eye_colours.keys(), rng)
	out.height_cm = int((rng.randi_range(catalog.height_min, catalog.height_max) + rng.randi_range(catalog.height_min, catalog.height_max)) / 2)
	var natural: Array = []
	var dyed: Array = []
	for id: String in catalog.hair_colours:
		var option: ColorOption = catalog.hair_colours[id]
		if option.natural:
			natural.append(id)
		else:
			dyed.append(id)
	if rng.randf() < 0.85 or dyed.is_empty():
		out.hair_colour = _pick(natural, rng)
	else:
		out.hair_colour = _pick(dyed, rng)
	var beards: Array = []
	for id: String in catalog.facial_hair:
		if id != "none":
			beards.append(id)
	if rng.randf() < 0.6 or beards.is_empty():
		out.facial_hair = "none"
	else:
		out.facial_hair = _pick(beards, rng)
	out.features = PackedStringArray()
	for id: String in catalog.features:
		if rng.randf() < 0.15:
			out.features.append(id)
	return out


static func _pick(ids: Array, rng: RandomNumberGenerator) -> String:
	return String(ids[rng.randi_range(0, ids.size() - 1)])
