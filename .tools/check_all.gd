extends Node

func _ready() -> void:
	var dir_targets := ["res://scripts", "res://tests"]
	var paths: Array[String] = []
	for root in dir_targets:
		_collect_gd(root, paths)
	paths.sort()
	var had_error := false
	for path in paths:
		var res := load(path)
		if res == null:
			printerr("PARSE_FAIL ", path)
			had_error = true
		else:
			print("PARSE_OK ", path)
	await get_tree().process_frame
	get_tree().quit(1 if had_error else 0)

func _collect_gd(root: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path := root.path_join(name)
		if dir.current_is_dir():
			_collect_gd(path, out)
		elif name.ends_with('.gd'):
			out.append(path)
	dir.list_dir_end()