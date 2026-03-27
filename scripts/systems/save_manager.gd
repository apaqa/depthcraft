extends Node

const FORMAT_VERSION: int = 1
const SAVE_SLOT_TEMPLATE: String = "user://save_slot_%d.json"
const BUILDING_SAVE = preload("res://scripts/building/building_save.gd")
const PLAYER_SAVE = preload("res://scripts/player/player_save.gd")

var _pending_load_slot: int = 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _pending_load_slot <= 0:
		return
	if _get_player() == null:
		return
	var slot_to_load: int = _pending_load_slot
	_pending_load_slot = 0
	load_game(slot_to_load)


# ─── Public API ────────────────────────────────────────────────────────────────

func save_game(slot: int) -> void:
	var player: Node = _get_player()
	var main_node: Node = get_tree().current_scene
	var payload: Dictionary = {
		"version": FORMAT_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"player": _serialize_player(player),
		"inventory": _serialize_inventory(player),
		"equipment": _serialize_equipment(player),
		"currency": _serialize_currency(player),
		"buildings": _serialize_buildings(player),
		"progress": _serialize_progress(main_node),
	}
	_write_json(SAVE_SLOT_TEMPLATE % slot, payload)
	print("SaveManager: saved slot %d" % slot)


func queue_load_game(slot: int) -> bool:
	var data: Dictionary = _read_json(SAVE_SLOT_TEMPLATE % slot)
	if data.is_empty():
		push_warning("SaveManager: slot %d not found or empty" % slot)
		_pending_load_slot = 0
		return false
	_synchronize_legacy_player_state(data)
	_pending_load_slot = slot
	return true


func load_game(slot: int) -> void:
	var data: Dictionary = _read_json(SAVE_SLOT_TEMPLATE % slot)
	if data.is_empty():
		push_warning("SaveManager: slot %d not found or empty" % slot)
		return
	var player: Node = _get_player()
	var main_node: Node = get_tree().current_scene
	var player_data: Dictionary = data.get("player", {}) as Dictionary
	var inventory_data: Array = data.get("inventory", []) as Array
	var equipment_data: Dictionary = data.get("equipment", {}) as Dictionary
	var currency_data: Dictionary = data.get("currency", {}) as Dictionary
	var building_data: Dictionary = data.get("buildings", {}) as Dictionary
	var progress_data: Dictionary = data.get("progress", {}) as Dictionary
	_synchronize_legacy_player_state(data)
	_restore_player(player_data, player)
	_restore_inventory(inventory_data, player)
	_restore_currency(currency_data, player)
	_restore_equipment(equipment_data, player)
	_restore_buildings(building_data, player)
	_restore_progress(progress_data, main_node)
	_finalize_player_restore(player_data, player)
	_refresh_loaded_scene(main_node)
	print("SaveManager: loaded slot %d" % slot)


func has_save(slot: int) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(SAVE_SLOT_TEMPLATE % slot)
	return FileAccess.file_exists(abs_path)


func delete_save(slot: int) -> void:
	var abs_path: String = ProjectSettings.globalize_path(SAVE_SLOT_TEMPLATE % slot)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


## Returns a lightweight dict suitable for displaying a save-slot summary in a menu.
func get_save_meta(slot: int) -> Dictionary:
	var data: Dictionary = _read_json(SAVE_SLOT_TEMPLATE % slot)
	if data.is_empty():
		return {}
	var progress: Dictionary = data.get("progress", {}) as Dictionary
	var player_data: Dictionary = data.get("player", {}) as Dictionary
	var currency: Dictionary = data.get("currency", {}) as Dictionary
	return {
		"timestamp": int(data.get("timestamp", 0)),
		"current_day": int(progress.get("current_day", 1)),
		"deepest_floor": int(progress.get("deepest_floor_reached", 1)),
		"player_hp": int(player_data.get("current_hp", 0)),
		"player_max_hp": int(player_data.get("max_hp", 100)),
		"class_id": str(player_data.get("current_class_id", "")),
		"gold": int(currency.get("gold", 0)),
		"silver": int(currency.get("silver", 0)),
		"copper": int(currency.get("copper", 0)),
	}


# ─── Serialization ─────────────────────────────────────────────────────────────

func _serialize_player(player: Node) -> Dictionary:
	if player == null:
		return {}
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	var class_id: String = ""
	if class_system != null:
		var raw_class: Variant = class_system.get("current_class_id")
		if raw_class != null:
			class_id = str(raw_class)
	var pos: Vector2 = Vector2.ZERO
	var raw_pos: Variant = player.get("global_position")
	if raw_pos is Vector2:
		pos = raw_pos as Vector2
	var talent_strings: Array[String] = []
	var raw_talents: Variant = player.get("unlocked_talents")
	if raw_talents is Array:
		for t: Variant in (raw_talents as Array):
			talent_strings.append(str(t))
	var raw_hp: Variant = player.get("current_hp")
	var raw_max_hp: Variant = player.get("max_hp")
	return {
		"current_hp": int(raw_hp) if raw_hp != null else 100,
		"max_hp": int(raw_max_hp) if raw_max_hp != null else 100,
		"position_x": float(pos.x),
		"position_y": float(pos.y),
		"unlocked_talents": talent_strings,
		"current_class_id": class_id,
	}


func _serialize_inventory(player: Node) -> Array:
	if player == null:
		return []
	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("get_state"):
		return []
	var state_variant: Variant = inventory.call("get_state")
	if typeof(state_variant) != TYPE_ARRAY:
		return []
	var state_arr: Array = state_variant as Array
	var result: Array = []
	for item_variant: Variant in state_arr:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		result.append(_clean_stack(item_variant as Dictionary))
	return result


func _serialize_equipment(player: Node) -> Dictionary:
	if player == null:
		return {}
	var equipment_system: Node = player.get_node_or_null("EquipmentSystem")
	if equipment_system == null or not equipment_system.has_method("serialize_state"):
		return {}
	var raw_state: Variant = equipment_system.call("serialize_state")
	if typeof(raw_state) != TYPE_DICTIONARY:
		return {}
	var state: Dictionary = raw_state as Dictionary
	var equipped_raw: Dictionary = state.get("equipped", {}) as Dictionary
	var equipped_clean: Dictionary = {}
	for slot_name: Variant in equipped_raw.keys():
		var item_variant: Variant = equipped_raw[slot_name]
		if typeof(item_variant) == TYPE_DICTIONARY:
			equipped_clean[str(slot_name)] = _clean_stack(item_variant as Dictionary)
		else:
			equipped_clean[str(slot_name)] = {}
	return {"equipped": equipped_clean}


func _serialize_currency(player: Node) -> Dictionary:
	if player == null:
		return {"gold": 0, "silver": 0, "copper": 0}
	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("get_item_count"):
		return {"gold": 0, "silver": 0, "copper": 0}
	return {
		"gold": int(inventory.call("get_item_count", "gold")),
		"silver": int(inventory.call("get_item_count", "silver")),
		"copper": int(inventory.call("get_item_count", "copper")),
	}


func _serialize_buildings(player: Node) -> Dictionary:
	if player == null:
		return {}
	var building_system: Node = player.get_node_or_null("BuildingSystem")
	if building_system == null:
		return {}

	# Serialize placed_buildings: Vector2i keys → "x,y" string keys
	var buildings_out: Dictionary = {}
	var placed_raw: Variant = building_system.get("placed_buildings")
	if typeof(placed_raw) == TYPE_DICTIONARY:
		var placed: Dictionary = placed_raw as Dictionary
		var inst_raw: Variant = building_system.get("building_instances")
		var instances: Dictionary = {}
		if typeof(inst_raw) == TYPE_DICTIONARY:
			instances = inst_raw as Dictionary
		for tile_key: Variant in placed.keys():
			var tile_x: int = 0
			var tile_y: int = 0
			if tile_key is Vector2i:
				var tv: Vector2i = tile_key as Vector2i
				tile_x = tv.x
				tile_y = tv.y
			elif typeof(tile_key) == TYPE_STRING:
				var parts: PackedStringArray = str(tile_key).split(",")
				if parts.size() != 2:
					continue
				tile_x = int(parts[0])
				tile_y = int(parts[1])
			else:
				continue
			var rec_variant: Variant = placed[tile_key]
			if typeof(rec_variant) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = (rec_variant as Dictionary).duplicate(true)
			# Pull fresh serialize_data from live instance
			var live_inst: Variant = instances.get(tile_key, null)
			if live_inst is Node and is_instance_valid(live_inst as Node):
				var live_node: Node = live_inst as Node
				if live_node.has_method("serialize_data"):
					record["data"] = live_node.call("serialize_data")
			var record_data: Dictionary = record.get("data", {}) as Dictionary
			record["position"] = [tile_x, tile_y]
			record["level"] = int(record_data.get("upgrade_level", 1))
			record["current_hp"] = int(record_data.get("current_hp", 0))
			buildings_out["%d,%d" % [tile_x, tile_y]] = record

	# Core position
	var core_raw: Variant = building_system.get("home_core_position")
	var core_pos: Vector2 = Vector2.ZERO
	if core_raw is Vector2:
		core_pos = core_raw as Vector2

	# Facilities (same Array format as BuildingSystem._serialize_facilities)
	var facilities_out: Array = []
	var fac_raw: Variant = building_system.get("placed_facilities")
	var finst_raw: Variant = building_system.get("facility_instances")
	var finst_map: Dictionary = {}
	if typeof(finst_raw) == TYPE_DICTIONARY:
		finst_map = finst_raw as Dictionary
	if typeof(fac_raw) == TYPE_DICTIONARY:
		var placed_fac: Dictionary = fac_raw as Dictionary
		for fac_key: Variant in placed_fac.keys():
			if not fac_key is Vector2i:
				continue
			var fac_tile: Vector2i = fac_key as Vector2i
			var frec_variant: Variant = placed_fac[fac_key]
			if typeof(frec_variant) != TYPE_DICTIONARY:
				continue
			var fac_rec: Dictionary = (frec_variant as Dictionary).duplicate(true)
			var finst_variant: Variant = finst_map.get(fac_key, null)
			if finst_variant is Node and is_instance_valid(finst_variant as Node):
				var finst_node: Node = finst_variant as Node
				if finst_node.has_method("serialize_data"):
					fac_rec["data"] = finst_node.call("serialize_data")
			fac_rec["position"] = [fac_tile.x, fac_tile.y]
			var facility_data: Dictionary = fac_rec.get("data", {}) as Dictionary
			fac_rec["level"] = int(facility_data.get("upgrade_level", 1))
			fac_rec["current_hp"] = int(facility_data.get("current_hp", 0))
			facilities_out.append(fac_rec)

	return {
		"buildings": buildings_out,
		"home_core_position": [float(core_pos.x), float(core_pos.y)],
		"facilities": facilities_out,
	}


func _serialize_progress(main_node: Node) -> Dictionary:
	if main_node == null:
		return {"current_day": 1, "deepest_floor_reached": 1}
	var raw_day: Variant = main_node.get("current_day")
	var raw_floor: Variant = main_node.get("deepest_dungeon_floor_reached")
	return {
		"current_day": int(raw_day) if raw_day != null else 1,
		"deepest_floor_reached": int(raw_floor) if raw_floor != null else 1,
	}


# ─── Restoration ───────────────────────────────────────────────────────────────

func _restore_player(data: Dictionary, player: Node) -> void:
	if data.is_empty() or player == null:
		return
	var px: float = float(data.get("position_x", 0.0))
	var py: float = float(data.get("position_y", 0.0))
	player.set("global_position", Vector2(px, py))
	var talent_strings: Array[String] = []
	var raw_talents: Variant = data.get("unlocked_talents", [])
	if raw_talents is Array:
		for t: Variant in (raw_talents as Array):
			talent_strings.append(str(t))
	player.set("unlocked_talents", talent_strings)
	# Rebuild talent bonuses in player_stats
	var player_stats: Node = player.get_node_or_null("PlayerStats")
	if player_stats != null and player_stats.has_method("rebuild_talent_bonuses"):
		player_stats.call("rebuild_talent_bonuses", talent_strings)
	var class_id: String = str(data.get("current_class_id", ""))
	if class_id != "":
		var class_system: Node = get_node_or_null("/root/ClassSystem")
		if class_system != null and class_system.has_method("save_class"):
			class_system.call("save_class", class_id)


func _restore_inventory(data: Array, player: Node) -> void:
	if player == null:
		return
	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("load_state"):
		return
	inventory.call("load_state", data)


func _restore_currency(data: Dictionary, player: Node) -> void:
	if player == null:
		return
	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory == null:
		return
	if not inventory.has_method("get_item_count") or not inventory.has_method("remove_item") or not inventory.has_method("add_item"):
		return
	for coin_id: String in ["gold", "silver", "copper"]:
		var existing_amount: int = int(inventory.call("get_item_count", coin_id))
		if existing_amount > 0:
			inventory.call("remove_item", coin_id, existing_amount)
		var target_amount: int = int(data.get(coin_id, 0))
		if target_amount > 0:
			inventory.call("add_item", coin_id, target_amount)


func _restore_equipment(data: Dictionary, player: Node) -> void:
	if data.is_empty() or player == null:
		return
	var equipment_system: Node = player.get_node_or_null("EquipmentSystem")
	if equipment_system == null or not equipment_system.has_method("load_state"):
		return
	equipment_system.call("load_state", data)
	# Sync equipment bonuses back to player_stats
	var player_stats: Node = player.get_node_or_null("PlayerStats")
	if player_stats != null and player_stats.has_method("set_equipment_bonuses"):
		if equipment_system.has_method("get_total_bonus_map"):
			var bonus_map: Dictionary = equipment_system.call("get_total_bonus_map") as Dictionary
			player_stats.call("set_equipment_bonuses", bonus_map)
	if player.has_signal("stats_changed"):
		player.emit_signal("stats_changed")


func _restore_buildings(data: Dictionary, player: Node) -> void:
	if data.is_empty():
		return

	# Reconstruct Vector2i-keyed placed_buildings from "x,y" string keys
	var buildings_raw: Dictionary = data.get("buildings", {}) as Dictionary
	var placed_buildings: Dictionary = {}
	for key_v: Variant in buildings_raw.keys():
		var parts: PackedStringArray = str(key_v).split(",")
		if parts.size() != 2:
			continue
		var tile_pos: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var rec_v: Variant = buildings_raw[key_v]
		if typeof(rec_v) == TYPE_DICTIONARY:
			var saved_record: Dictionary = (rec_v as Dictionary).duplicate(true)
			var saved_record_data: Dictionary = saved_record.get("data", {}) as Dictionary
			if not saved_record_data.has("upgrade_level") and saved_record.has("level"):
				saved_record_data["upgrade_level"] = int(saved_record.get("level", 1))
			if not saved_record_data.has("current_hp") and saved_record.has("current_hp"):
				saved_record_data["current_hp"] = int(saved_record.get("current_hp", 0))
			saved_record["data"] = saved_record_data
			saved_record.erase("position")
			saved_record.erase("level")
			saved_record.erase("current_hp")
			placed_buildings[tile_pos] = saved_record

	# Core position
	var core_v: Variant = data.get("home_core_position", [0.0, 0.0])
	var core_pos: Vector2 = Vector2.ZERO
	if core_v is Array:
		var core_arr: Array = core_v as Array
		if core_arr.size() >= 2:
			core_pos = Vector2(float(core_arr[0]), float(core_arr[1]))

	# Facilities array (same format as BuildingSystem._serialize_facilities output)
	var fac_v: Variant = data.get("facilities", [])
	var facilities_array: Array = []
	if fac_v is Array:
		facilities_array = (fac_v as Array).duplicate()

	# Write to BuildingSave for persistence across scene reloads
	BUILDING_SAVE.save_buildings(placed_buildings, core_pos, facilities_array)

	if player == null:
		return

	# Reconstruct placed_facilities dict for in-memory use
	var placed_facilities: Dictionary = {}
	for fac_variant: Variant in facilities_array:
		if typeof(fac_variant) != TYPE_DICTIONARY:
			continue
		var fac: Dictionary = fac_variant as Dictionary
		var pos_v: Variant = fac.get("position", [])
		if not pos_v is Array:
			continue
		var pos_arr: Array = pos_v as Array
		if pos_arr.size() < 2:
			continue
		var fac_tile: Vector2i = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		var fac_rec: Dictionary = fac.duplicate(true)
		var fac_data: Dictionary = fac_rec.get("data", {}) as Dictionary
		if not fac_data.has("upgrade_level") and fac_rec.has("level"):
			fac_data["upgrade_level"] = int(fac_rec.get("level", 1))
		if not fac_data.has("current_hp") and fac_rec.has("current_hp"):
			fac_data["current_hp"] = int(fac_rec.get("current_hp", 0))
		fac_rec["data"] = fac_data
		fac_rec.erase("position")
		fac_rec.erase("level")
		fac_rec.erase("current_hp")
		placed_facilities[fac_tile] = fac_rec

	# Apply directly to BuildingSystem
	var building_system: Node = player.get_node_or_null("BuildingSystem")
	if building_system == null:
		return
	building_system.set("placed_buildings", placed_buildings)
	building_system.set("home_core_position", core_pos)
	building_system.set("placed_facilities", placed_facilities)
	building_system.set("_loaded_from_save", true)

	# Re-instantiate buildings if currently in overworld
	var lvl_id_v: Variant = building_system.get("active_level_id")
	var lvl_v: Variant = building_system.get("active_level")
	if str(lvl_id_v) == "overworld" and lvl_v != null:
		building_system.call("_apply_saved_state_to_level")


func _restore_progress(data: Dictionary, main_node: Node) -> void:
	if data.is_empty() or main_node == null:
		return
	main_node.set("current_day", int(data.get("current_day", 1)))
	main_node.set("deepest_dungeon_floor_reached", int(data.get("deepest_floor_reached", 1)))


func _finalize_player_restore(player_data: Dictionary, player: Node) -> void:
	if player == null:
		return
	if player.has_method("_refresh_all_stats"):
		player.call("_refresh_all_stats")
	var restored_max_hp: int = int(player.get("max_hp"))
	if restored_max_hp <= 0:
		restored_max_hp = int(player_data.get("max_hp", 100))
		player.set("max_hp", restored_max_hp)
	var restored_current_hp: int = clampi(int(player_data.get("current_hp", restored_max_hp)), 0, restored_max_hp)
	player.set("current_hp", restored_current_hp)
	if player.has_signal("stats_changed"):
		player.emit_signal("stats_changed")
	if player.has_signal("hp_changed"):
		player.emit_signal("hp_changed", restored_current_hp, restored_max_hp)
	if player.has_method("_save_persistent_state"):
		player.call("_save_persistent_state")


func _refresh_loaded_scene(main_node: Node) -> void:
	if main_node == null:
		return
	var current_day: int = int(main_node.get("current_day"))
	var deepest_floor: int = int(main_node.get("deepest_dungeon_floor_reached"))
	QuestManager.set_day(current_day)
	var hud_value: Variant = main_node.get("hud")
	if hud_value is Node:
		var hud_node: Node = hud_value as Node
		if hud_node.has_method("update_day_label"):
			hud_node.call("update_day_label", current_day)
		var class_label_value: Variant = hud_node.get("class_label")
		if class_label_value is Label:
			var class_label: Label = class_label_value as Label
			var class_system: Node = get_node_or_null("/root/ClassSystem")
			class_label.text = class_system.call("get_class_display_name") if class_system != null and class_system.has_method("get_class_display_name") else ""
	var current_level_value: Variant = main_node.get("current_level")
	if current_level_value is Node:
		var current_level: Node = current_level_value as Node
		if current_level.has_method("set_day_count"):
			current_level.call("set_day_count", current_day)
		if current_level.has_method("set_deepest_floor_reached"):
			current_level.call("set_deepest_floor_reached", deepest_floor)


# ─── JSON Cleaning ─────────────────────────────────────────────────────────────
# Strips non-serializable values (Texture2D, Node, Resource, Color→array, etc.)

func _clean_stack(stack: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for key_v: Variant in stack.keys():
		var key: String = str(key_v)
		var val: Variant = stack[key_v]
		if val == null:
			clean[key] = null
		elif val is Color:
			var c: Color = val as Color
			clean[key] = [float(c.r), float(c.g), float(c.b), float(c.a)]
		elif val is Vector2:
			var v: Vector2 = val as Vector2
			clean[key] = [float(v.x), float(v.y)]
		elif val is Vector2i:
			var vi: Vector2i = val as Vector2i
			clean[key] = [int(vi.x), int(vi.y)]
		elif val is Object:
			pass  # skip Texture2D, Node, Resource and any other GDScript Object
		elif val is Array:
			clean[key] = _clean_array(val as Array)
		elif val is Dictionary:
			clean[key] = _clean_stack(val as Dictionary)
		else:
			clean[key] = val
	return clean


func _clean_array(arr: Array) -> Array:
	var result: Array = []
	for element: Variant in arr:
		if element == null:
			result.append(null)
		elif element is Color:
			var c: Color = element as Color
			result.append([float(c.r), float(c.g), float(c.b), float(c.a)])
		elif element is Vector2:
			var v: Vector2 = element as Vector2
			result.append([float(v.x), float(v.y)])
		elif element is Object:
			pass  # skip non-serializable objects
		elif element is Array:
			result.append(_clean_array(element as Array))
		elif element is Dictionary:
			result.append(_clean_stack(element as Dictionary))
		else:
			result.append(element)
	return result


# ─── Helpers ───────────────────────────────────────────────────────────────────

func _get_player() -> Node:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node


func _synchronize_legacy_player_state(data: Dictionary) -> void:
	var player_data: Dictionary = data.get("player", {}) as Dictionary
	var unlocked_talents: Array[String] = []
	var raw_talents: Variant = player_data.get("unlocked_talents", [])
	if raw_talents is Array:
		for talent_id: Variant in raw_talents:
			unlocked_talents.append(str(talent_id))
	var equipment_data: Dictionary = data.get("equipment", {}) as Dictionary
	PLAYER_SAVE.save_state({
		"unlocked_talents": unlocked_talents,
		"equipment": equipment_data.duplicate(true),
	})
	var class_id: String = str(player_data.get("current_class_id", ""))
	if class_id == "":
		return
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	if class_system != null and class_system.has_method("save_class"):
		class_system.call("save_class", class_id)


func _write_json(path: String, data: Dictionary) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open '%s' for writing" % abs_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()


func _read_json(path: String) -> Dictionary:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return {}
	var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_path)
	if raw_bytes.is_empty():
		return {}
	var raw_text: String = raw_bytes.get_string_from_utf8()
	if raw_text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary
