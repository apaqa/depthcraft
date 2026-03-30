extends SceneTree

func _initialize() -> void:
	var dir: DirAccess = DirAccess.open("res://scripts")
	_scan_dir(dir, "res://scripts")
	quit()

func _scan_dir(dir: DirAccess, path: String) -> void:
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			var full: String = path + "/" + fname
			if dir.current_is_dir():
				var sub: DirAccess = DirAccess.open(full)
				_scan_dir(sub, full)
			elif fname.ends_with(".gd"):
				var s: GDScript = load(full)
				if s == null:
					print("LOAD_FAIL: " + full)
		fname = dir.get_next()
