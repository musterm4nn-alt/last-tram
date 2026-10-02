class_name DiscoveryEffect
extends RefCounted
## One effect of uncovering a discovery (T-0067, docs/design/discoveries.md → Effects).
## Which fields matter depends on `kind`; DiscoveryLoader validates them.

const NOTE: String = "note"
const MONEY: String = "money"
const MOODLET: String = "moodlet"
const CONTACT: String = "contact"
const UNLOCK: String = "unlock_interaction"
## Every kind content may use. "item" waits for M4's inventory (D29).
const KINDS: PackedStringArray = [NOTE, MONEY, MOODLET, CONTACT, UNLOCK]

## One of KINDS.
var kind: String = NOTE
## note: the notebook line.
var text: String = ""
## money: cents found (once per world).
var cents: int = 0
## moodlet: the moodlet given.
var moodlet_id: String = ""
## contact: the place whose residents (a home) or staff (a workplace) you now know.
var place_id: String = ""
## unlock_interaction: the interaction (with requires_discovery = this discovery) it opens.
var interaction_id: String = ""
