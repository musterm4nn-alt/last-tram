class_name LintUtil
extends RefCounted
## Helpers for the lint tests: find source files and strip comments/strings from code.


## All .gd files under `dir`, recursively, sorted.
static func gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(gd_files(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	out.sort()
	return out


## The code part of a line: comments removed and string contents blanked, so rules only
## match real code ("# never use randi()" or "\"Time.\"" do not count).
static func code_only(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote.is_empty():
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
			out += c
		else:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
				out += c
		i += 1
	return out
