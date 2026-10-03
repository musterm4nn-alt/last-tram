extends TestCase
## T-0083: the world's tint, darkness, lit windows and light map follow the clock.

## A room (wood floor, lit indoors) with a window, next to a cobbled square.
const ROWS: PackedStringArray = [
	"#####::::::::::::",
	"#...W::::::::::::",
	"#.@.#::::::::::::",
	"#####::::::::::::",
	":::::::::::::::::",
	":::::::::::::::::",
]


func test_tint_keyframes() -> void:
	assert_eq(DayNight.tint(12 * 60), DayNight.DAY)
	assert_eq(DayNight.tint(23 * 60), DayNight.NIGHT)
	assert_eq(DayNight.tint(3 * 60), DayNight.NIGHT)
	var evening := DayNight.tint(20 * 60)
	assert_true(evening != DayNight.DUSK and evening != DayNight.NIGHT, "between dusk and night: %s" % evening)
	assert_true(evening.get_luminance() < DayNight.DUSK.get_luminance() and evening.get_luminance() > DayNight.NIGHT.get_luminance(),
			"darker than dusk, lighter than night: %s" % evening)
	_assert_close(DayNight.tint(1439), DayNight.tint(0), "continuous across midnight")
	_assert_close(DayNight.tint(-60), DayNight.tint(23 * 60), "minutes wrap")
	for minute: int in range(0, 1440, 5):
		_assert_close(DayNight.tint(minute), DayNight.tint(minute + 1), "no jumps at %d" % minute, 0.02)


func test_darkness() -> void:
	assert_eq(DayNight.darkness(12 * 60), 0.0)
	assert_eq(DayNight.darkness(0), 1.0)
	assert_eq(DayNight.darkness(4 * 60), 1.0)
	var evening := DayNight.darkness(20 * 60)
	assert_true(evening > 0.35 and evening < 1.0, "%f" % evening)
	assert_true(DayNight.darkness(6 * 60) > 0.0 and DayNight.darkness(6 * 60) < 1.0, "dawn")


func test_window_share() -> void:
	var lit_at_nine := 0
	for i: int in 1000:
		var cell := Vector2i(i % 40, i / 40)
		assert_eq(DayNight.window_lit(cell, 21 * 60), DayNight.window_lit(cell, 21 * 60), "stable")
		assert_false(DayNight.window_lit(cell, 12 * 60), "no lit windows at noon")
		if DayNight.window_lit(cell, 21 * 60):
			lit_at_nine += 1
	assert_true(lit_at_nine > 640 and lit_at_nine < 760, "about 70 %% at 21:00: %d of 1000" % lit_at_nine)
	assert_eq(DayNight.window_share(3 * 60), 5)
	assert_eq(DayNight.window_share(23 * 60 + 30), 30)


func test_light_map() -> void:
	var sim := SimFactory.from_rows(content(), ROWS)
	var lamps: Array[Vector2i] = [Vector2i(14, 4)]
	var image := DayNight.light_map(sim.world.grid, 0, lamps, 21 * 60)
	var px := DayNight.LIGHT_PX
	assert_eq(image.get_size(), Vector2i(17 * px, 6 * px))
	var indoor := _at(image, Vector2i(2, 1))
	_assert_close(indoor, Color(DayNight.INDOOR_LIGHT.r, DayNight.INDOOR_LIGHT.g, DayNight.INDOOR_LIGHT.b), "indoor is lit", 0.01)
	var lamp := _at(image, Vector2i(14, 4))
	assert_true(lamp.r > 0.85 and lamp.r > lamp.b * 2.0, "orange under the lamp: %s" % lamp)
	assert_eq(_at(image, Vector2i(8, 5)), Color.BLACK, "dark on the square away from the lamp")
	assert_eq(_at(image, Vector2i(0, 0)), Color.BLACK, "walls away from any light stay dark")
	var by_day := DayNight.light_map(sim.world.grid, 0, lamps, 12 * 60)
	assert_eq(_at(by_day, Vector2i(5, 1)), Color.BLACK, "no lit windows by day (the window is at (4, 1))")


func test_lamp_cells_reads_street_lamps() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var cells := NightLights2D.lamp_cells(sim.world, 0)
	assert_true(cells.size() >= 20, "%d lamps" % cells.size())
	assert_true(cells.has(Vector2i(19, 24)), "the lamp at the Altmarkt's corner")
	assert_eq(NightLights2D.lamp_cells(sim.world, 1).size(), 0, "none upstairs")


## The light map pixel in the middle of a cell.
func _at(image: Image, cell: Vector2i) -> Color:
	var c := image.get_pixelv(cell * DayNight.LIGHT_PX + Vector2i(DayNight.LIGHT_PX / 2, DayNight.LIGHT_PX / 2))
	return Color(c.r, c.g, c.b)


func _assert_close(a: Color, b: Color, message: String, tolerance: float = 0.0001) -> void:
	assert_true(absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance,
			"%s: %s vs %s" % [message, a, b])
