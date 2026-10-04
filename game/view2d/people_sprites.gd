class_name PeopleSprites
extends RefCounted
## PixelLab test: recoloured person sheets. A base body's mask marks each pixel's group
## (skin, hair, top, bottom) and brightness; a person's sheet is the base with those groups
## painted in their colours, shaded the same. Sheets are cached by base and colours.

const LONG_HAIR: Array[String] = ["long", "shoulder", "bob", "ponytail", "bun", "braids"]
const HEAVY: Array[String] = ["stocky", "heavy"]
const BEARDS: Array[String] = ["short_beard", "full_beard", "goatee"]

static var _cache: Dictionary = {}


## The sheet for a person: their base body in their colours.
static func texture(people: Dictionary, content: ContentDB, appearance: Appearance, outfit: Outfit) -> Texture2D:
	var bases: Dictionary = people["bases"]
	var base := base_for(appearance, bases)
	var top_slot := "outer" if outfit.get_item("outer") != null else "top"
	var colors: Array[Color] = [
		PersonDrawer2D.skin_color(content, appearance.skin_tone),
		PersonDrawer2D.hair_color(content, appearance.hair_colour),
		PersonDrawer2D.worn_color(content, outfit, top_slot),
		PersonDrawer2D.worn_color(content, outfit, "bottom"),
	]
	var key := base
	for c: Color in colors:
		key += "|" + c.to_html(false)
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(recolor(bases[base]["image"], bases[base]["mask"], colors))
	return _cache[key]


## Which base body suits an appearance (the bases a set has: base_a, base_b, base_c).
static func base_for(appearance: Appearance, bases: Dictionary) -> String:
	if appearance.hair_style in LONG_HAIR and bases.has("base_b"):
		return "base_b"
	if (appearance.build in HEAVY or appearance.facial_hair in BEARDS) and bases.has("base_c"):
		return "base_c"
	return "base_a"


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
