extends RefCounted
class_name BuildingSave

const SAVE_PATH := "user://world_save.json"


static func save_buildings(placed_buildings: Dictionary, core_pos: Vector2) -> void:
	var building_data: Dictionary = {}
	for tile_pos: Vector2i in placed_buildings.keys():
		building_data["%d,%d" % [tile_pos.x, tile_pos.y]] = placed_buildings[tile_pos]

	var payload: Dictionary = {
		"core_position": [core_pos.x, core_pos.y],
		"buildings": building_data,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(payload))


static func load_buildings() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {
			"core_position": Vector2.ZERO,
			"buildings": {},
		}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {
			"core_position": Vector2.ZERO,
			"buildings": {},
		}

	var raw_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"core_position": Vector2.ZERO,
			"buildings": {},
		}

	var parsed_dict: Dictionary = parsed
	var runtime_buildings: Dictionary = {}
	for key in parsed_dict.get("buildings", {}).keys():
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2:
			continue
		runtime_buildings[Vector2i(int(parts[0]), int(parts[1]))] = parsed_dict["buildings"][key]

	var core_array: Array = parsed_dict.get("core_position", [0.0, 0.0])
	var core_position: Vector2 = Vector2.ZERO
	if core_array.size() >= 2:
		core_position = Vector2(float(core_array[0]), float(core_array[1]))

	return {
		"core_position": core_position,
		"buildings": runtime_buildings,
	}


static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
