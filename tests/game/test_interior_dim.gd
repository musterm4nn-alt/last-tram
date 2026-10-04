extends TestCase
## T-0090: indoors, the street beside the open building's outer walls is darkened, but the
## wall band is not, so outer walls show at full thickness.


func test_a_west_wall_keeps_its_band() -> void:
	var vertical := WallShapes.ARM_N | WallShapes.ARM_S
	assert_eq(InteriorDim2D.ground_rects(vertical, 0), [Rect2i(0, 0, 4, 4), Rect2i(0, 4, 4, 4)] as Array[Rect2i], "NW: only the column left of the band")
	assert_eq(InteriorDim2D.ground_rects(vertical, 2), [Rect2i(0, 8, 4, 4), Rect2i(0, 12, 4, 4)] as Array[Rect2i], "SW")


func test_a_corner_keeps_its_arms() -> void:
	var corner := WallShapes.ARM_E | WallShapes.ARM_S
	assert_eq(InteriorDim2D.ground_rects(corner, 0), [Rect2i(0, 0, 4, 4), Rect2i(4, 0, 4, 4), Rect2i(0, 4, 4, 4)] as Array[Rect2i], "NW of a corner: outside the band")
	assert_eq(InteriorDim2D.ground_rects(corner, 3), [Rect2i(12, 14, 4, 2)] as Array[Rect2i], "SE: between the arms, below the face")


func test_the_band_matches_the_wall_layer() -> void:
	# The band (with its edge) spans the middle 8 px that ground_rects keeps clear.
	assert_eq(WallLayer2D.BAND_FROM - 1, ViewConfig.TILE_PX / 4)
	assert_eq(WallLayer2D.BAND_FROM + WallLayer2D.BAND + 1, ViewConfig.TILE_PX * 3 / 4)


func test_a_bottom_wall_keeps_its_face() -> void:
	var across := WallShapes.ARM_E | WallShapes.ARM_W
	assert_eq(InteriorDim2D.ground_rects(across, 2), [Rect2i(0, 14, 4, 2), Rect2i(4, 14, 4, 2)] as Array[Rect2i], "SW: below the 2-px face")
	assert_eq(InteriorDim2D.ground_rects(across, 0), [Rect2i(0, 0, 4, 4), Rect2i(4, 0, 4, 4)] as Array[Rect2i], "NW: above the band")
