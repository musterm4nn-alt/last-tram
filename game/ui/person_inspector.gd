class_name PersonInspector
extends PanelContainer
## The person inspector (T-0041): a panel on the right with the selected person's name, age,
## mood and moodlets, what they're doing, their household, how they see the player and what
## they remember about the player. Selected by clicking someone in command mode
## (PlayerController); a click on the ground or an object clears it. Reads sim state only.

const WIDTH: float = 270.0
const FONT_SIZE: int = 13
## How many memories about the player it lists.
const MEMORIES_SHOWN: int = 3

## The person shown (0 = none, hidden).
var person_id: int = 0

var _label: Label


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -12 - WIDTH
	offset_right = -12
	offset_top = 214
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 16, 0)
	add_child(_label)
	visible = false


## Shows `id` (0 hides the panel).
func show_person(id: int) -> void:
	person_id = id
	visible = id > 0


func _process(_delta: float) -> void:
	if not visible or Session.sim == null:
		return
	var text := "\n".join(lines(Session.sim, person_id, Session.sim.world.player_id))
	if text.is_empty():
		show_person(0)
	elif _label.text != text:
		_label.text = text


## The panel's lines for `id` as seen by `viewer_id` (pure, for tests). [] for nobody.
static func lines(sim: Sim, id: int, viewer_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	var person := sim.world.get_person(id)
	if person == null:
		return out
	out.append(person.full_name())
	out.append("%d, %s" % [person.age_years, person.pronouns])
	var mood := Mood.compute(person, sim.content)
	var moodlet_names := PackedStringArray()
	for m: Moodlet in person.moodlets:
		var def := sim.content.moodlet(m.id)
		if def != null:
			moodlet_names.append("%s %+d" % [def.name, def.value])
	out.append("Mood: %s%s" % [Mood.label(mood), (" (%s)" % ", ".join(moodlet_names)) if not moodlet_names.is_empty() else ""])
	out.append("Doing: %s" % doing(sim, person))
	out.append("Lives: %s" % home_text(sim, person))
	out.append("Money: %s" % Money.format(person.wallet.total()))
	out.append("Job: %s" % job_text(sim, person))
	if id == viewer_id:
		return out
	out.append("")
	out.append("You: %s" % relationship_label(Social.relationship(person, viewer_id)))
	var about_you := Social.memories_about(person, viewer_id)
	for m: Memory in about_you.slice(0, MEMORIES_SHOWN):
		out.append("  - %s" % sim.content.dialogue.memories.get(m.kind, m.kind.replace("_", " ")))
	if about_you.is_empty():
		out.append("  Remembers nothing about you yet.")
	return out


## What the person is doing: the front action's name ("walking there" while routing),
## "Walking", or "Nothing".
static func doing(sim: Sim, person: Person) -> String:
	if not person.action_queue.is_empty():
		var action: Action = person.action_queue[0]
		var def := sim.content.interaction(action.interaction_id)
		var name := def.name if def != null else action.interaction_id
		var other := sim.world.get_person(action.target_id)
		if other != null:
			name += " with %s" % other.display_name()
		return name + (" (on the way)" if action.state != Action.PERFORMING else "")
	if not person.path.is_empty():
		return "Walking"
	return "Nothing"


## "Office clerk (Mon–Fri 9–17)", "Retired" (at retirement age without a job) or "Unemployed".
static func job_text(sim: Sim, person: Person) -> String:
	var described := Jobs.describe(sim.content, person)
	if not described.is_empty():
		return described
	return "Retired" if person.age_years >= sim.content.economy.retirement_age else "Unemployed"


## "Haus 9, 1st floor, with Mira" style: the home place and the other household members.
static func home_text(sim: Sim, person: Person) -> String:
	var lot: Lot = sim.world.lots.get(person.home_lot_id)
	var place := sim.content.place(lot.place_id) if lot != null else null
	var text := place.name if place != null else "nowhere"
	var household: Household = sim.world.households.get(person.household_id)
	if household != null:
		var others := PackedStringArray()
		for member_id: int in household.member_ids:
			if member_id != person.id and sim.world.get_person(member_id) != null:
				others.append(sim.world.get_person(member_id).display_name())
		if not others.is_empty():
			text += ", with %s" % ", ".join(others)
	return text


## How a relationship reads in words, from the viewer's side of it.
static func relationship_label(r: Relationship) -> String:
	if r == null or r.familiarity < 10.0:
		return "a stranger"
	if r.romance >= 50.0:
		return "in love with you" if r.friendship >= 0.0 else "it's complicated"
	if r.friendship <= -50.0:
		return "can't stand you"
	if r.friendship <= -20.0:
		return "dislikes you"
	if r.friendship >= 60.0:
		return "a close friend"
	if r.friendship >= 25.0:
		return "a friend"
	return "knows you" if r.familiarity >= 40.0 else "knows you by sight"
