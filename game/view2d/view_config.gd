class_name ViewConfig
extends RefCounted
## Sizes and colours of the 2D view. The sim works in cells; only the view knows pixels,
## so changing TILE_PX (e.g. to 32 for a different art pack) touches nothing in sim/.

const TILE_PX: int = 16
const ZOOM_LEVELS: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0]
const DEFAULT_ZOOM_INDEX: int = 2
const OUTLINE_COLOR: Color = Color("#141414")
## Small yellow triangle above the player's head (the player no longer has a yellow body).
const PLAYER_MARKER_COLOR: Color = Color("#f2c14e")
## Visible fallback for unknown content ids, so mistakes show up in screenshots.
const UNKNOWN_ID_COLOR: Color = Color("#ff00ff")
## Body width in cells per build id (unknown id → DEFAULT_BUILD_WIDTH).
const DEFAULT_BUILD_WIDTH: float = 0.52
const BUILD_WIDTH: Dictionary = {
	"slim": 0.44,
	"average": 0.52,
	"athletic": 0.56,
	"stocky": 0.60,
	"heavy": 0.66,
}
## Hair style id → placeholder shape (unknown id → "cap").
const HAIR_SHAPE: Dictionary = {
	"bald": "none",
	"buzz": "thin",
	"short": "cap",
	"side_part": "cap",
	"undercut": "cap",
	"curly_short": "cap",
	"bob": "sides",
	"shoulder": "sides",
	"long": "long",
	"braids": "long",
	"dreadlocks": "long",
	"ponytail": "tail",
	"bun": "bun",
	"afro": "afro",
	"mohawk": "mohawk",
}
