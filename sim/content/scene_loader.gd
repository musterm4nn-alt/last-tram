class_name SceneLoader
extends RefCounted
## Loads every .json file in data/scenes/ into ContentDB.scenes (T-0043), and reads the
## "presentation" block of interactions (read_presentation).

## Template words the view can fill in (SceneText).
const PLACEHOLDERS: PackedStringArray = ["actor", "target", "place", "actor.they", "actor.them", "actor.their", "actor.themself", "target.they", "target.them", "target.their", "target.themself"]


static func load(db: ContentDB, reader: ContentReader, dir: String) -> void:
	var listing := DirAccess.open(dir)
	if listing == null:
		reader.error("%s: folder not found" % dir)
		return
	var files := listing.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() != "json":
			continue
		var path := dir.path_join(file)
		var root: Variant = reader.read_json(path)
		if not root is Dictionary:
			continue
		for entry: Variant in reader.read_arr(root, "scenes", path):
			if not entry is Dictionary:
				reader.error("%s: every scene must be an object" % path)
				continue
			var d: Dictionary = entry
			var scene := SceneDef.new()
			scene.id = reader.read_str(d, "id", path)
			var ctx := "%s: scene '%s'" % [path, scene.id]
			scene.adult = reader.read_bool(d, "adult", ctx)
			if scene.adult:
				reader.error("%s: the core game has no adult scenes" % ctx)
			scene.pages = reader.read_str_array(d, "pages", ctx)
			if scene.pages.is_empty():
				reader.error("%s: needs at least one page" % ctx)
			for page: String in scene.pages:
				for problem: String in unknown_placeholders(page):
					reader.error("%s: unknown placeholder {%s}" % [ctx, problem])
			if scene.id.is_empty() or db.scenes.has(scene.id):
				reader.error("%s: empty or duplicate id" % ctx)
				continue
			db.scenes[scene.id] = scene


## The {placeholders} in `text` that SceneText cannot fill.
static func unknown_placeholders(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var at := text.find("{")
	while at >= 0:
		var end := text.find("}", at)
		if end < 0:
			break
		var word := text.substr(at + 1, end - at - 1)
		if not PLACEHOLDERS.has(word):
			out.append(word)
		at = text.find("{", end)
	return out


## An interaction's optional "presentation" block (scene ids are checked after scenes load).
static func read_presentation(reader: ContentReader, d: Dictionary, ctx: String) -> PresentationDef:
	var block := reader.read_obj(d, "presentation", ctx)
	var p := PresentationDef.new()
	var pctx := ctx + " presentation"
	p.scene_id = reader.read_str(block, "scene", pctx)
	p.when = String(block.get("when", "finish"))
	if p.when != "finish":
		reader.error("%s: 'when' must be \"finish\"" % pctx)
	if block.has("player_only"):
		p.player_only = reader.read_bool(block, "player_only", pctx)
	if block.has("chance"):
		p.chance = reader.read_num(block, "chance", pctx)
		if p.chance <= 0.0 or p.chance > 1.0:
			reader.error("%s: 'chance' must be within 0 (excluded) and 1" % pctx)
	if block.has("day"):
		p.day = reader.read_int(block, "day", pctx)
	if block.has("once"):
		p.once = reader.read_bool(block, "once", pctx)
	return p
