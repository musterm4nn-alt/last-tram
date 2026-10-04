class_name PeopleSprites
extends RefCounted
## PixelLab test: recoloured person sheets. A base body's mask marks each pixel's group
## (skin, hair, top, bottom) and brightness; a person's sheet is the base with those groups
## painted in their colours, shaded the same. Sheets are cached by base and colours.

const LONG_HAIR: Array[String] = ["long", "shoulder", "bob", "braids"]
const TIED_HAIR: Array[String] = ["ponytail", "bun"]
const CURLY_HAIR: Array[String] = ["afro", "curly_short", "dreadlocks"]
const HEAVY: Array[String] = ["stocky", "heavy"]
const BEARDS: Array[String] = ["short_beard", "full_beard", "goatee"]
## Taller than this (cm) and slim: the tall body.
const TALL_CM: int = 180

## Hair darker than this merges with the outline.
const MIN_HAIR_V: float = 0.2
## Colours closer than this (RGB distance) read as one at 16 px.
const MIN_DISTANCE: float = 0.18

static var _cache: Dictionary = {}


## The sheet for a person: their base body in their colours.
static func texture(people: Dictionary, content: ContentDB, appearance: Appearance, outfit: Outfit, gender: String) -> Texture2D:
	var bases: Dictionary = people["bases"]
	var base := base_for(appearance, gender, bases)
	var top_slot := "outer" if outfit.get_item("outer") != null else "top"
	var colors: Array[Color] = [
		PersonDrawer2D.skin_color(content, appearance.skin_tone),
		PersonDrawer2D.hair_color(content, appearance.hair_colour),
		PersonDrawer2D.worn_color(content, outfit, top_slot),
		PersonDrawer2D.worn_color(content, outfit, "bottom"),
	]
	colors = readable(colors)
	var key := base
	for c: Color in colors:
		key += "|" + c.to_html(false)
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(recolor(bases[base]["image"], bases[base]["mask"], colors))
	return _cache[key]


## Keeps a look readable at 16 px: very dark hair is lifted off the black outline, hair that
## matches the top is shaded apart from it, and trousers too close to the top get darker
## (or lighter, when both are dark). `colors` is skin, hair, top, bottom.
static func readable(colors: Array[Color]) -> Array[Color]:
	var out: Array[Color] = colors.duplicate()
	var hair: Color = out[1]
	if hair.v < MIN_HAIR_V:
		hair = Color.from_hsv(hair.h, hair.s, MIN_HAIR_V)
	if _distance(hair, out[2]) < MIN_DISTANCE:
		hair = hair.darkened(0.35) if hair.v > 0.35 else hair.lightened(0.35)
	out[1] = hair
	var bottom: Color = out[3]
	if _distance(bottom, out[2]) < MIN_DISTANCE:
		bottom = bottom.darkened(0.4) if bottom.v > 0.3 else bottom.lightened(0.3)
	out[3] = bottom
	return out


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Which base body suits a person (only the bases the set has): a long hair, b long hair,
## c heavy or bearded or bald, d curly hair, e tied-up hair, f short-haired woman, g tall
## and slim; a otherwise.
static func base_for(appearance: Appearance, gender: String, bases: Dictionary) -> String:
	var wanted := "base_a"
	if appearance.hair_style in TIED_HAIR:
		wanted = "base_e"
	elif appearance.hair_style in LONG_HAIR:
		wanted = "base_b"
	elif appearance.hair_style in CURLY_HAIR:
		wanted = "base_d"
	elif appearance.build in HEAVY or appearance.facial_hair in BEARDS or appearance.hair_style == "bald":
		wanted = "base_c"
	elif appearance.build == "slim" and appearance.height_cm >= TALL_CM:
		wanted = "base_g"
	elif gender == "woman":
		wanted = "base_f"
	return wanted if bases.has(wanted) else "base_a"


## The base image with mask groups 1-4 painted in colors[0..3], keeping each pixel's shade.
static func recolor(image: Image, mask: Image, colors: Array[Color]) -> Image:
	var out := image.duplicate() as Image
	for y: int in out.get_height():
		for x: int in out.get_width():
			var m := mask.get_pixel(x, y)
			var group := roundi(m.r8 / 50.0)
			if m.a < 0.5 or group < 1 or group > colors.size():
				continue
			var base := colors[group - 1]
			var ratio := m.g8 / 127.5
			out.set_pixel(x, y, Color.from_hsv(base.h, base.s, clampf(base.v * ratio, 0.0, 1.0), out.get_pixel(x, y).a))
	return out
