extends TestCase
## T-0002: object placeholders derive their label, colour and geometry from content,
## and the container rebuilds from world state without duplicating views.

const ROOM: PackedStringArray = [
	"################",
	"#..............#",
	"#...@..........#",
	"#..............#",
	"################",
]

var _old_content: ContentDB
var _old_sim: Sim
var _old_level: int = 0
var _old_show_slots: bool = false


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_level = Session.viewed_level
	_old_show_slots = ObjectView2D.show_slots


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.viewed_level = _old_level
	ObjectView2D.show_slots = _old_show_slots


func test_short_label_uses_last_word_up_to_three_chars() -> void:
	assert_eq(ObjectView2D.short_label("Fridge"), "Fri")
	assert_eq(ObjectView2D.short_label("Double bed"), "Bed")
	assert_eq(ObjectView2D.short_label("Sofa"), "Sof")
	assert_eq(ObjectView2D.short_label("Television"), "Tel")
	assert_eq(ObjectView2D.short_label("TV"), "TV")
	assert_eq(ObjectView2D.short_label("x"), "X")
	assert_eq(ObjectView2D.short_label(""), "")


func test_label_color_contrasts_with_fill() -> void:
	assert_eq(ObjectView2D.label_color(Color("#2d3436")), Color.WHITE, "white on the dark TV")
	assert_eq(ObjectView2D.label_color(Color("#dfe6e9")), ViewConfig.OUTLINE_COLOR, "dark on the pale fridge")


func test_footprint_rect_covers_cells() -> void:
	var single: Array[Vector3i] = [Vector3i(2, 3, 0)]
	assert_eq(ObjectView2D.footprint_rect(single, 16), Rect2(32, 48, 16, 16))
	var bed: Array[Vector3i] = [Vector3i(5, 6, 0), Vector3i(6, 6, 0), Vector3i(5, 7, 0), Vector3i(6, 7, 0)]
	assert_eq(ObjectView2D.footprint_rect(bed, 16), Rect2(80, 96, 32, 32))


func test_rebuild_creates_one_view_per_object_and_clears() -> void:
	var views := _views_with_two_objects()
	assert_eq(views._views.size(), 2)
	var old_views: Array[ObjectView2D] = views._views.values()
	views.rebuild()
	assert_eq(views._views.size(), 2, "rebuild must clear first, not duplicate")
	for old: ObjectView2D in old_views:
		assert_true(old.is_queued_for_deletion(), "old views must be freed, or they keep drawing")
		assert_false(views._views.values().has(old), "rebuild must make new views")
	views.free()


func test_added_and_removed_events_update_views() -> void:
	var db := content()
	var sim := SimFactory.from_rows(db, ROOM)
	Session.content = db
	Session.sim = sim
	Session.viewed_level = 0
	var first := _place(sim, "fridge", Vector3i(7, 2, 0))
	assert_true(sim.world.add_object(first))
	var views := ObjectsView2D.new()
	views.rebuild()
	assert_eq(views._views.size(), 1)
	var second := _place(sim, "sofa", Vector3i(10, 2, 0))
	assert_true(sim.world.add_object(second))
	views._on_sim_event({"type": &"object_added", "data": {"object_id": second.id}})
	assert_eq(views._views.size(), 2)
	assert_true(views._views.has(second.id))
	sim.world.remove_object(second.id)
	views._on_sim_event({"type": &"object_removed", "data": {"object_id": second.id}})
	assert_eq(views._views.size(), 1)
	assert_true(views._views.has(first.id))
	views.free()


func test_view_visible_only_on_its_level() -> void:
	var views := _views_with_two_objects()
	var id: int = views._views.keys()[0]
	var view: ObjectView2D = views._views[id]
	Session.viewed_level = 0
	view._process(0.0)
	assert_true(view.visible, "level 0 object on level 0")
	Session.viewed_level = 1
	view._process(0.0)
	assert_false(view.visible, "level 0 object hidden on level 1")
	views.free()


## T-0081
func test_object_view_sits_on_footprint_bottom() -> void:
	var views := _views_with_two_objects()
	for id: int in views._views:
		var view: ObjectView2D = views._views[id]
		var rect := ObjectView2D.footprint_rect(Session.sim.world.get_object(id).cells(Session.content), ViewConfig.TILE_PX)
		assert_eq(view.position, Vector2(rect.position.x, rect.end.y), "bottom-left of the footprint")
	var fridge: ObjectView2D = views._views[views._views.keys()[0]]
	assert_eq(fridge.position, Vector2(7 * 16, 3 * 16), "the 1x1 fridge at (7, 2)")
	views.free()


## T-0081
func test_depth_parent_sorts_objects_and_people() -> void:
	var depth := DepthLayer2D.new()
	assert_true(depth.y_sort_enabled)
	assert_eq(depth.objects.get_parent(), depth)
	assert_eq(depth.people.get_parent(), depth)
	assert_true(depth.objects.y_sort_enabled, "objects sort with the people, not as one block")
	assert_true(depth.people.y_sort_enabled)
	depth.free()


func _views_with_two_objects() -> ObjectsView2D:
	var db := content()
	var sim := SimFactory.from_rows(db, ROOM)
	Session.content = db
	Session.sim = sim
	Session.viewed_level = 0
	assert_true(sim.world.add_object(_place(sim, "fridge", Vector3i(7, 2, 0))))
	assert_true(sim.world.add_object(_place(sim, "sofa", Vector3i(10, 2, 0))))
	var views := ObjectsView2D.new()
	views.rebuild()
	return views


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	return obj
