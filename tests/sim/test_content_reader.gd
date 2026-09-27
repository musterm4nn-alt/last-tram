extends TestCase
## T-0022: ContentReader reports problems instead of crashing, and ContentDB's index
## helpers keep the id and glyph lookups in step with the lists.


func test_readers_report_problems_and_return_defaults() -> void:
	var reader := ContentReader.new()
	assert_eq(reader.read_str({}, "id", "ctx"), "")
	assert_near(reader.read_num({"n": "x"}, "n", "ctx"), 0.0)
	assert_eq(reader.read_json("res://no/such.json"), null)
	assert_has(reader.errors, "ctx: 'id' must be a string")
	assert_has(reader.errors, "ctx: 'n' must be a number")
	assert_has(reader.errors, "res://no/such.json: file not found")


func test_load_problems_end_up_in_the_db() -> void:
	var db := ContentDB.new()
	db.load_from("res://tests/fixtures/content_broken")
	assert_false(db.is_valid())
	assert_true("\n".join(db.errors).contains("duplicate terrain id"), "\n".join(db.errors))


func test_add_terrain_and_need_keep_lookups_in_step() -> void:
	var db := ContentDB.new()
	for pair: Array in [["grass", ","], ["stone", "#"]]:
		var t := TerrainDef.new()
		t.id = pair[0]
		t.glyph = pair[1]
		db.add_terrain(t)
	assert_eq(db.terrain_index("stone"), 1)
	assert_eq(db.terrain_index_for_glyph(","), 0)
	assert_eq(db.terrain_index("mud"), -1)
	var n := NeedDef.new()
	n.id = "fun"
	db.add_need(n)
	assert_eq(db.need("fun"), n)
	assert_eq(db.needs.size(), 1)
