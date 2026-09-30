class_name SaveFile
extends RefCounted
## Writes a complete save beside the destination, then atomically replaces it.
## A failed write or rename leaves the previous save intact.


## Returns OK only after all bytes were written, flushed and moved into place.
func write(path: String, text: String) -> Error:
	var destination := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if result != OK:
		return result
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := text.to_utf8_buffer()
	_store(file, bytes)
	file.flush()
	result = file.get_error()
	if file.get_length() != bytes.size():
		result = ERR_FILE_CANT_WRITE
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		DirAccess.remove_absolute(temporary)
	return result


func _store(file: FileAccess, bytes: PackedByteArray) -> void:
	file.store_buffer(bytes)
