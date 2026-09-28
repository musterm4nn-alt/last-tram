class_name SaveList
extends VBoxContainer
## A list of save files as buttons, for saving into a slot or loading any save. Used by the
## Esc menu (PauseMenu) and the main menu's Load game. Emits chosen(path) or back_pressed.

## A row was chosen: save into / load from this file.
signal chosen(path: String)
## "Back" was pressed.
signal back_pressed

const ROW_SIZE: Vector2 = Vector2(420, 40)


## Rows to show (pure, for tests). Each row: {"path": String, "label": String}.
## for_save = true: the three slots, always ("Slot 1 · empty" when missing).
## for_save = false: only files that exist, in all_paths() order, named "Quicksave",
## "Slot 1".."Slot 3", "Autosave 1", "Autosave 2". Existing files show their game and real time.
static func rows(saves: SaveSlots, for_save: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var named: Array[Array] = []
	if not for_save:
		named.append([saves.quicksave_path(), "Quicksave"])
	for index: int in range(1, SaveSlots.SLOT_COUNT + 1):
		named.append([saves.slot_path(index), "Slot %d" % index])
	if not for_save:
		for index: int in range(1, SaveSlots.AUTOSAVE_COUNT + 1):
			named.append([saves.autosave_path(index), "Autosave %d" % index])
	for entry: Array in named:
		var path: String = entry[0]
		var name: String = entry[1]
		if FileAccess.file_exists(path):
			out.append({"path": path, "label": "%s · %s · %s" % [
				name, SaveSlots.describe_game_time(path), SaveSlots.describe_real_time(path)]})
		elif for_save:
			out.append({"path": path, "label": "%s · empty" % name})
	return out


## Rebuilds the buttons from rows() plus a Back button at the end. An empty load list shows
## one disabled "No saves yet" button.
func show_rows(saves: SaveSlots, for_save: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var shown := rows(saves, for_save)
	for row: Dictionary in shown:
		var button := _button(String(row["label"]))
		button.pressed.connect(_on_row.bind(String(row["path"])))
	if shown.is_empty():
		_button("No saves yet").disabled = true
	var back := _button("Back")
	back.pressed.connect(func() -> void: back_pressed.emit())


## The first button, for keyboard focus when the list is shown.
func first_button() -> Button:
	for child: Node in get_children():
		if child is Button and not (child as Button).disabled:
			return child
	return null


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ROW_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(button)
	return button


func _on_row(path: String) -> void:
	chosen.emit(path)
