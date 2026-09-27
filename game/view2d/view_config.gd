class_name ViewConfig
extends RefCounted
## Sizes and colours of the 2D view. The sim works in cells; only the view knows pixels,
## so changing TILE_PX (e.g. to 32 for a different art pack) touches nothing in sim/.

const TILE_PX: int = 16
const ZOOM_LEVELS: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0]
const DEFAULT_ZOOM_INDEX: int = 2

const PLAYER_COLOR: Color = Color("#f2c14e")
const NPC_COLOR: Color = Color("#7fb3d5")
const SKIN_COLOR: Color = Color("#e0b089")
const OUTLINE_COLOR: Color = Color("#141414")
