extends TestCase
## T-0020: the name screen enables Start only for valid names (the look is screenshots).


func test_prefilled_names_can_start() -> void:
	var screen := _make_screen()
	assert_false(screen._start.disabled, "Alex Novak should be a valid start: " + screen._error.text)
	_drop(screen)


func test_bad_name_disables_start_and_shows_error() -> void:
	var screen := _make_screen()
	screen._first.text = "Al3x"
	screen._refresh()
	assert_true(screen._start.disabled)
	assert_false(screen._error.text.is_empty())
	_drop(screen)


func test_empty_nickname_is_fine() -> void:
	var screen := _make_screen()
	screen._nick.text = ""
	screen._refresh()
	assert_false(screen._start.disabled)
	_drop(screen)


func _make_screen() -> NameScreen:
	# _ready() is called directly: control building needs no tree, and this keeps the
	# test independent of main-loop init order. The Session autoload is not readied
	# before tests run, so its content is seeded from the shared test content.
	Session.content = content()
	var screen := NameScreen.new()
	screen._ready()
	return screen


func _drop(screen: NameScreen) -> void:
	screen.free()
