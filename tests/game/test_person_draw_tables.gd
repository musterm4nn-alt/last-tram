extends TestCase
## T-0019: the placeholder drawing tables cover every build and hair style the content
## allows, so nobody silently falls back to the default shape. (The drawing itself is
## verified with screenshots, see the ticket.)


func test_every_build_has_a_width() -> void:
	for build: String in content().appearance.builds:
		assert_true(ViewConfig.BUILD_WIDTH.has(build), "build '%s' has no width" % build)
		var width: float = float(ViewConfig.BUILD_WIDTH[build])
		assert_true(width > 0.3 and width < 0.8, "build '%s' has an odd width %s" % [build, width])


func test_every_hair_style_has_a_known_shape() -> void:
	var known := ["none", "thin", "cap", "sides", "long", "tail", "bun", "afro", "mohawk"]
	for style: String in content().appearance.hair_styles:
		assert_true(ViewConfig.HAIR_SHAPE.has(style), "hair style '%s' has no shape" % style)
		assert_has(known, ViewConfig.HAIR_SHAPE.get(style, "cap"))
