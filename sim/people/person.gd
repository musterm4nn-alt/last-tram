class_name Person
extends RefCounted
## A resident of the town. The player is a Person too (see World.player_id), and runs on
## exactly the same rules as everyone else.

## Half-size of a person's collision box, in cells.
const RADIUS: float = 0.3
## Everyone in the game is an adult (AGENTS.md content rules).
const MIN_AGE: int = 18
## How many actions the player may queue (visible in command mode, each cancellable).
const MAX_QUEUE: int = 6
## Running speed as a multiple of walk_speed (see move_speed()).
const RUN_FACTOR: float = 2.0
## Fields to_dict() leaves out on purpose (the save-field coverage test checks the rest).
const NOT_SAVED: PackedStringArray = ["prev_pos"]

var id: int = 0
var first_name: String = ""
var last_name: String = ""
## Optional nickname shown instead of the first name (see display_name()).
var nickname: String = ""
## Gender id from AppearanceCatalog.genders.
var gender: String = ""
## Pronoun set id from AppearanceCatalog.pronouns.
var pronouns: String = ""
## Age in years. Everyone in the game is an adult: this never stores less than MIN_AGE,
## whatever a spec, a save or a bug tries to set.
var age_years: int = MIN_AGE:
	set(value):
		age_years = maxi(MIN_AGE, value)
## What the person looks like.
var appearance: Appearance = Appearance.new()
## What the person wears.
var outfit: Outfit = Outfit.new()
## Who the person is: seven axes, −100..+100 (old saves: all 0).
var personality: Personality = Personality.new()
## Cash and bank account (T-0054). Change it only through Money.
var wallet: Wallet = Wallet.new()
## Their job (T-0058), or null when they have none.
var job: Employment = null
## Registered as unemployed, so benefit is paid while they have no job (T-0062). Residents are
## registered from the start; the player registers on the phone (T-0064).
var benefit_registered: bool = false
## The day they last applied for a job (-1 = never): one application a day (T-0064).
var applied_day: int = -1
## Id of the Lot the person lives in (0 = none). Private lots let only their residents in.
var home_lot_id: int = 0
## Id of the person's Household (0 = none).
var household_id: int = 0
## This person's view of others, by their id (T-0037).
var relationships: Dictionary[int, Relationship] = {}
## What they remember, at most Social.MEMORY_CAP.
var memories: Array[Memory] = []
## Running moodlets.
var moodlets: Array[Moodlet] = []
## Simulated in the background tier: actions and movement update once per game minute
## (TierSystem, T-0042).
var background: bool = false
## Scene ids of "once" presentations already requested for this person (T-0043).
var scenes_requested: PackedStringArray = PackedStringArray()
## Discovery ids whose clue the person knows, and the ones they uncovered (T-0067; sorted,
## kept to ids content still has by World.from_dict).
var known_clues: PackedStringArray = PackedStringArray()
## Clothes the person owns (T-0072; Wardrobe keeps it sorted) and saved outfits by name.
var wardrobe: Array[WornItem] = []
var outfits: Dictionary[String, Outfit] = {}
## Skill id -> XP (T-0071; Skills turns it into levels).
var skills: Dictionary[String, float] = {}
var discoveries: PackedStringArray = PackedStringArray()
## RoutineDef id ("" = the content's default routine).
var routine_id: String = ""
## Free will found nothing to do: it looks again at this tick (AutonomySystem.RETRY_MINUTES).
var autonomy_retry_tick: int = 0
## Floor the person is on (the z of their cell).
var level: int = 0
## Feet position in cell units: cell (3, 4) spans x 3..4, y 4..5, so its centre is (3.5, 4.5).
var pos: Vector2 = Vector2.ZERO
## Last movement direction, for sprites. Always one of the four cardinal directions.
var facing: Vector2 = Vector2.DOWN
## Direct-control walking direction (length 0..1). Set by SetMoveIntentCommand.
var move_intent: Vector2 = Vector2.ZERO
## Walking speed in cells per game minute. At 1x speed that is cells per real second.
var walk_speed: float = 4.5
## True while the person runs (the player holds Shift). Set by SetRunningCommand.
var running: bool = false
## Remaining cells to walk through, set by WalkToCommand and followed by MovementSystem.
## Saved as a list of Ser.cell().
var path: Array[Vector3i] = []
## Needs 0-100 (100 = fully satisfied). Keys are need ids from data/needs.json.
var needs: Dictionary[String, float] = {}
## Queued interactions; the front action (index 0) is the current one.
var action_queue: Array[Action] = []
## Free will: when idle for a while, the person looks after their own needs (T-0025).
var free_will: bool = true
## Tick of the last direct input (a player command) for this person; autonomy waits
## AutonomySystem.IDLE_MINUTES after it.
var last_input_tick: int = 0

## NOT saved: position before the latest step, only used to draw smooth movement.
var prev_pos: Vector2 = Vector2.ZERO


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


## Nickname when set, else the first name.
func display_name() -> String:
	return nickname if not nickname.is_empty() else first_name


## Cells per game minute right now: walk_speed, times RUN_FACTOR while running.
func move_speed() -> float:
	return walk_speed * RUN_FACTOR if running else walk_speed


func cell() -> Vector3i:
	return Vector3i(floori(pos.x), floori(pos.y), level)


func to_dict() -> Dictionary:
	var needs_out: Dictionary = {}
	for key: String in needs:
		needs_out[key] = needs[key]
	var path_out: Array = []
	for cell: Vector3i in path:
		path_out.append(Ser.cell(cell))
	var queue_out: Array = []
	for action: Action in action_queue:
		queue_out.append(action.to_dict())
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname,
		"gender": gender,
		"pronouns": pronouns,
		"age_years": age_years,
		"appearance": appearance.to_dict(),
		"outfit": outfit.to_dict(),
		"wardrobe": wardrobe.map(func(w: WornItem) -> Dictionary: return w.to_dict()),
		"outfits": _outfits_out(),
		"personality": personality.to_dict(),
		"wallet": wallet.to_dict(),
		"job": job.to_dict() if job != null else null,
		"benefit_registered": benefit_registered,
		"applied_day": applied_day,
		"home_lot_id": home_lot_id,
		"household_id": household_id,
		"autonomy_retry_tick": autonomy_retry_tick,
		"routine_id": routine_id,
		"background": background,
		"scenes_requested": Array(scenes_requested),
		"known_clues": Array(known_clues),
		"skills": _skills_out(),
		"discoveries": Array(discoveries),
		"relationships": _relationships_out(),
		"memories": memories.map(func(m: Memory) -> Dictionary: return m.to_dict()),
		"moodlets": moodlets.map(func(m: Moodlet) -> Dictionary: return m.to_dict()),
		"level": level,
		"pos": Ser.vec2(pos),
		"facing": Ser.vec2(facing),
		"move_intent": Ser.vec2(move_intent),
		"walk_speed": walk_speed,
		"running": running,
		"path": path_out,
		"needs": needs_out,
		"action_queue": queue_out,
		"free_will": free_will,
		"last_input_tick": last_input_tick,
	}


## Saved outfits sorted by name (stable save text).
func _outfits_out() -> Dictionary:
	var names: Array = outfits.keys()
	names.sort()
	var out: Dictionary = {}
	for name: String in names:
		out[name] = outfits[name].to_dict()
	return out


## Skills sorted by id (stable save text).
func _skills_out() -> Dictionary:
	var ids: Array = skills.keys()
	ids.sort()
	var out: Dictionary = {}
	for id: String in ids:
		out[id] = skills[id]
	return out


## Relationships as a list sorted by the other person's id (stable save text).
func _relationships_out() -> Array:
	var ids: Array = relationships.keys()
	ids.sort()
	return ids.map(func(id: int) -> Dictionary: return relationships[id].to_dict())


static func from_dict(d: Dictionary) -> Person:
	var p := Person.new()
	p.id = int(d["id"])
	p.first_name = String(d["first_name"])
	p.last_name = String(d["last_name"])
	p.nickname = String(d.get("nickname", ""))
	p.gender = String(d.get("gender", ""))
	p.pronouns = String(d.get("pronouns", ""))
	p.age_years = int(d.get("age_years", 18))
	var appearance_data: Variant = d.get("appearance", {})
	if appearance_data is Dictionary:
		p.appearance = Appearance.from_dict(appearance_data)
	var outfit_data: Variant = d.get("outfit", {})
	if outfit_data is Dictionary:
		p.outfit = Outfit.from_dict(outfit_data)
	for entry: Variant in d.get("wardrobe", []):
		if entry is Dictionary:
			p.wardrobe.append(WornItem.from_dict(entry))
	var outfits_data: Variant = d.get("outfits", {})
	if outfits_data is Dictionary:
		for name: Variant in outfits_data:
			if outfits_data[name] is Dictionary:
				p.outfits[String(name)] = Outfit.from_dict(outfits_data[name])
	var personality_data: Variant = d.get("personality", {})
	if personality_data is Dictionary:
		p.personality = Personality.from_dict(personality_data)
	var wallet_data: Variant = d.get("wallet", {})
	if wallet_data is Dictionary:
		p.wallet = Wallet.from_dict(wallet_data)
	if d.get("job") is Dictionary:
		p.job = Employment.from_dict(d["job"])
	p.benefit_registered = bool(d.get("benefit_registered", false))
	p.applied_day = int(d.get("applied_day", -1))
	p.home_lot_id = int(d.get("home_lot_id", 0))
	p.household_id = int(d.get("household_id", 0))
	p.autonomy_retry_tick = int(d.get("autonomy_retry_tick", 0))
	p.routine_id = String(d.get("routine_id", ""))
	p.background = bool(d.get("background", false))
	for scene_id: Variant in d.get("scenes_requested", []):
		p.scenes_requested.append(String(scene_id))
	var skills_data: Variant = d.get("skills", {})
	if skills_data is Dictionary:
		for id: Variant in skills_data:
			p.skills[String(id)] = float(skills_data[id])
	for id: Variant in d.get("known_clues", []):
		p.known_clues.append(String(id))
	for id: Variant in d.get("discoveries", []):
		p.discoveries.append(String(id))
	for entry: Variant in d.get("relationships", []):
		var r := Relationship.from_dict(entry)
		p.relationships[r.other_id] = r
	for entry: Variant in d.get("memories", []):
		p.memories.append(Memory.from_dict(entry))
	for entry: Variant in d.get("moodlets", []):
		p.moodlets.append(Moodlet.from_dict(entry))
	p.level = int(d["level"])
	p.pos = Ser.to_vec2(d["pos"])
	p.facing = Ser.to_vec2(d["facing"])
	p.move_intent = Ser.to_vec2(d["move_intent"])
	p.walk_speed = float(d["walk_speed"])
	p.running = bool(d.get("running", false))
	p.prev_pos = p.pos
	p.path = []
	var path_data: Variant = d.get("path", [])
	if path_data is Array:
		for entry: Variant in (path_data as Array):
			p.path.append(Ser.to_cell(entry))
	p.action_queue = []
	var queue_data: Variant = d.get("action_queue", [])
	if queue_data is Array:
		for entry: Variant in (queue_data as Array):
			if entry is Dictionary:
				p.action_queue.append(Action.from_dict(entry))
	p.free_will = bool(d.get("free_will", true))
	p.last_input_tick = int(d.get("last_input_tick", 0))
	p.needs = {}
	var stored: Variant = d.get("needs", {})
	if stored is Dictionary:
		for key: Variant in (stored as Dictionary):
			p.needs[String(key)] = float((stored as Dictionary)[key])
	return p
