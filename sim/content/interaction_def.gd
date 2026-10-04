class_name InteractionDef
extends RefCounted
## One thing a person can do with an object (Sleep on a bed, Grab a snack from a
## fridge...). Defined in data/interactions/*.json. Objects offer the interactions
## whose object_tags overlap their own tags. Exactly one of `duration_minutes`
## (fixed length) or `until_need` (ends when that need reaches 100, between
## `min_minutes` and `max_minutes`) is used.

var id: String = ""
var name: String = ""
## "object" (offered by objects via object_tags) or "person" (done to another person, with
## `social`; T-0038).
var target: String = "object"
## For person-targeted interactions: kind, acceptance and outcomes (null otherwise).
var social: SocialDef = null
## Object tags that offer this interaction (at least one must be used by some object).
var object_tags: PackedStringArray = PackedStringArray()
## Fixed length in game minutes, or 0 when `until_need` is used.
var duration_minutes: int = 0
## Need id this runs until (100), or "" when `duration_minutes` is used.
var until_need: String = ""
## Shortest and longest run for `until_need`, in game minutes.
var min_minutes: int = 0
var max_minutes: int = 0
## Per-game-hour need changes while performing, on top of normal decay.
var need_rates: Dictionary[String, float] = {}
## One-off need gains when the action finishes.
var finish_needs: Dictionary[String, float] = {}
## The need gains autonomy scoring expects (may differ from reality).
var advertise: Dictionary[String, float] = {}
## While the player performs this, the game runs at Session.SKIP_SPEED (sleeping).
var time_skip: bool = false
## The scene to request when it finishes (null for none; T-0043).
var presentation: PresentationDef = null
## Moodlet started when the action finishes ("" for none).
var finish_moodlet: String = ""
## "" or the part of a daily routine this belongs to: "sleep" (scored and ended by the sleep
## window, see Routines) or "out" (going out, T-0052).
var routine: String = ""
## What it costs in euro cents, paid when it starts performing (0 = free; T-0055).
var price: int = 0
## Cents moved from the bank to cash when it finishes (the cash machine; T-0056; 0 = none).
var cash_out: int = 0
## Grocery portions taken when it starts, from the household whose home the target object is
## in (cooking; T-0057).
var uses_groceries: int = 0
## Grocery portions added to the actor's household when it finishes (buying groceries).
var adds_groceries: int = 0
## Sold over a counter (T-0065): only while someone works an on-site shift on the target's
## place (Requirements "not_staffed"). Object targets only.
var staffed: bool = false
## A screen the view opens for the player when it finishes (T-0072: "wardrobe"); the sim
## only emits &"screen_requested" {person_id, screen}.
var opens_screen: String = ""
## Practice (T-0071): skill id -> XP per hour while doing it.
var skill_xp: Dictionary[String, float] = {}
## Its finish_needs grow with this skill (Skills.finish_factor; cooking).
var finish_skill: String = ""
## Place interactions (T-0070): only on these places ([] = everywhere).
var places: PackedStringArray = PackedStringArray()
## Offered only to people who uncovered this discovery (T-0067; Requirements "unknown_secret").
var requires_discovery: String = ""
## Doing it teaches this discovery's clue (T-0068: notice boards and the like).
var teaches_clue: String = ""
## Washing (T-0074): when it finishes, all the person's clothes are clean (Laundry.wash).
var launders: bool = false
## Only for people with no home (T-0066: sleeping rough); Requirements "has_home" otherwise.
var homeless_only: bool = false
## A crime this interaction commits when it finishes (a CrimeDef id; T-0091), or "".
## Free will offers it only to the tempted (T-0097).
var crime: String = ""
## Only in someone else's home (T-0098: a break-in); Requirements "not_a_break_in" elsewhere.
var trespass: bool = false
## A shift at work (T-0059): uses staff slots, lasts until the shift ends, and the job's
## WorkSession drives it. Work has no duration of its own.
var work: bool = false
## A person-targeted interaction done from afar (a phone call, T-0063): no walking, no need to
## stand together; only through its command, never from the person menu or free will.
var remote: bool = false
