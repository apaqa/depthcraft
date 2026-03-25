extends RefCounted
class_name PlayerSave

const SAVE_PATH := "user://player_save.json"


static func save_state(payload: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.flush()


static func load_state() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(absolute_path):
		return {}
	var raw_bytes := FileAccess.get_file_as_bytes(absolute_path)
	var raw_text := raw_bytes.get_string_from_utf8()
	if raw_text == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw_text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func clear_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string("{}")
		file.flush()
