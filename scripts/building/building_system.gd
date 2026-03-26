extends Node
class_name BuildingSystem

signal build_state_changed

enum BuildState {
	NONE,
	PLACING,
	REMOVING,
}

const BUILDING_DATA := preload("res://scripts/building/building_data.gd")
const BUILDING_SAVE := preload("res://scripts/building/building_save.gd")
const BUILD_PREVIEW_SCENE := preload("res://scenes/building/build_preview.tscn")
const HOME_CORE_SCENE := preload("res://scenes/building/home_core.tscn")
const TILE_SIZE := 16
const HOME_CORE_COST := {"wood": 10, "stone": 5}

@onready var player = get_parent()

var state: int = BuildState.NONE
var active_level_id: String = ""
var active_level = null
var building_layer: TileMapLayer = null
var building_container: Node2D = null
var placed_buildings: Dictionary = {}
var placed_facilities: Dictionary = {}
var selected_category_index: int = 0
var selected_building_indices: Dictionary = {}
var preview = null
var home_core_position: Vector2 = Vector2.ZERO
var home_core_instance = null
var facility_instances: Dictionary = {}
var building_instances: Dictionary = {}
var occupied_positions: Dictionary = {}
var debug_mode: bool = false
var _loaded_from_save: bool = false


func _ready() -> void:
	for category_id in BUILDING_DATA.get_category_ids():
		selected_building_indices[str(category_id)] = 0
	_ensure_preview()
	build_state_changed.emit()


func set_active_level(level_id: String, level) -> void:
	active_level_id = level_id
	active_level = level
	building_layer = null
	building_container = null

	if active_level != null:
		building_layer = active_level.get_node_or_null("BuildingLayer")
		building_container = active_level.get_node_or_null("BuildingContainer")

	if active_level_id != "overworld":
		exit_build_mode()
		return

	if not _loaded_from_save:
		var save_data: Dictionary = BUILDING_SAVE.load_buildings()
		placed_buildings = save_data.get("buildings", {})
		home_core_position = save_data.get("core_position", Vector2.ZERO)
		placed_facilities = _normalize_facility_save_data(save_data.get("facilities", []))
		_loaded_from_save = true

	_apply_saved_state_to_level()
	build_state_changed.emit()


func toggle_build_mode() -> bool:
	if not can_use_build_mode():
		return false

	if is_build_mode_active():
		exit_build_mode()
	else:
		state = BuildState.PLACING
		_ensure_preview()
		build_state_changed.emit()

	return true


func exit_build_mode() -> void:
	state = BuildState.NONE
	build_state_changed.emit()


func handle_input(event: InputEvent) -> bool:
	if not is_build_mode_active():
		return false

	if event.is_action_pressed("ui_cancel"):
		exit_build_mode()
		return true

	if event.is_action_pressed("build_next"):
		cycle_selected_building(1)
		return true

	if event.is_action_pressed("build_prev"):
		cycle_selected_building(-1)
		return true

	if event.is_action_pressed("interact"):
		cycle_category(1)
		return true

	if event.is_action_pressed("use_consumable"):
		cycle_category(-1)
		return true

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				select_category(0)
				return true
			KEY_2:
				select_category(1)
				return true
			KEY_3:
				select_category(2)
				return true
			KEY_4:
				select_category(3)
				return true

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		place_home_core(get_hovered_tile_pos())
		return true

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if state == BuildState.REMOVING:
				remove_building(get_hovered_tile_pos())
			else:
				state = BuildState.REMOVING
				build_state_changed.emit()
			return true

		if event.button_index == MOUSE_BUTTON_LEFT:
			if state == BuildState.REMOVING:
				remove_building(get_hovered_tile_pos())
			else:
				place_building(get_hovered_tile_pos(), get_selected_building_id())
			return true

	return false


func toggle_debug_mode() -> void:
	debug_mode = not debug_mode
	print("Debug mode %s" % ("ON" if debug_mode else "OFF"))
	build_state_changed.emit()


func is_debug_mode_enabled() -> bool:
	return debug_mode


func is_build_mode_active() -> bool:
	return state != BuildState.NONE


func is_remove_mode() -> bool:
	return state == BuildState.REMOVING


func can_use_build_mode() -> bool:
	return active_level_id == "overworld" and building_container != null


func get_selected_building() -> Dictionary:
	var buildings := BUILDING_DATA.get_buildings_for_category(get_selected_category_id())
	if buildings.is_empty():
		return {}
	var category_id := get_selected_category_id()
	var selected_index: int = int(selected_building_indices.get(category_id, 0))
	return buildings[clampi(selected_index, 0, buildings.size() - 1)]


func get_selected_building_id() -> String:
	var building := get_selected_building()
	return str(building.get("id", ""))


func cycle_selected_building(direction: int) -> void:
	var category_id := get_selected_category_id()
	var buildings := BUILDING_DATA.get_buildings_for_category(category_id)
	if buildings.is_empty():
		return

	selected_building_indices[category_id] = wrapi(int(selected_building_indices.get(category_id, 0)) + direction, 0, buildings.size())
	if state == BuildState.REMOVING:
		state = BuildState.PLACING
	build_state_changed.emit()


func cycle_category(direction: int) -> void:
	var category_ids := BUILDING_DATA.get_category_ids()
	selected_category_index = wrapi(selected_category_index + direction, 0, category_ids.size())
	if state == BuildState.REMOVING:
		state = BuildState.PLACING
	build_state_changed.emit()


func select_category(category_index: int) -> void:
	var category_ids := BUILDING_DATA.get_category_ids()
	if category_index < 0 or category_index >= category_ids.size():
		return
	selected_category_index = category_index
	if state == BuildState.REMOVING:
		state = BuildState.PLACING
	build_state_changed.emit()


func get_selected_category_id() -> String:
	var category_ids := BUILDING_DATA.get_category_ids()
	return str(category_ids[clampi(selected_category_index, 0, category_ids.size() - 1)])


func get_hovered_tile_pos() -> Vector2i:
	var mouse_world_pos: Vector2 = player.get_global_mouse_position()
	return Vector2i(floori(mouse_world_pos.x / TILE_SIZE), floori(mouse_world_pos.y / TILE_SIZE))


func get_preview_modulate(tile_pos: Vector2i) -> Color:
	if state == BuildState.REMOVING:
		if occupied_positions.has(tile_pos):
			return Color(1.0, 0.75, 0.35, 0.5)
		return Color(1.0, 0.3, 0.3, 0.5)

	if is_valid_placement(tile_pos, get_selected_building_id()):
		return Color(0.3, 1.0, 0.3, 0.5)
	return Color(1.0, 0.3, 0.3, 0.5)


func get_selected_building_texture() -> Texture2D:
	var building := get_selected_building()
	if building.is_empty():
		return null

	if building.has("preview_texture"):
		return building.get("preview_texture", null)

	if building_layer == null:
		return null

	var source := building_layer.tile_set.get_source(int(building["tile_source_id"]))
	if source == null:
		return null
	return source.texture


func get_selected_building_tile_size() -> Vector2i:
	var building := get_selected_building()
	if building.is_empty():
		return Vector2i.ONE
	return _get_building_tile_size(building)


func get_preview_world_position(tile_pos: Vector2i, tile_size: Vector2i = Vector2i.ONE) -> Vector2:
	return _tile_to_world_center_for_size(tile_pos, tile_size)


func place_building(tile_pos: Vector2i, building_id: String) -> bool:
	var building: Dictionary = BUILDING_DATA.get_building(building_id)
	if building.is_empty():
		return false

	var is_valid := is_valid_placement(tile_pos, building_id)
	if not is_valid:
		return false

	if not _consume_cost(building["cost"]):
		return false

	if str(building.get("kind", "tile")) == "facility":
		if not _place_facility(tile_pos, building):
			_refund_full_cost(building["cost"])
			return false
	else:
		if not _place_tile_building(tile_pos, building):
			_refund_full_cost(building["cost"])
			return false
		placed_buildings[tile_pos] = building_id
	_rebuild_occupied_positions()
	_auto_save()
	build_state_changed.emit()
	return true


func remove_building(tile_pos: Vector2i) -> bool:
	var occupied_data: Dictionary = occupied_positions.get(tile_pos, {})
	var origin_tile: Vector2i = tile_pos if occupied_data.is_empty() else occupied_data.get("origin", tile_pos)

	if placed_buildings.has(origin_tile):
		var building_id := str(placed_buildings[origin_tile])
		var building: Dictionary = BUILDING_DATA.get_building(building_id)
		if building_instances.has(origin_tile):
			var placed_instance = building_instances[origin_tile]
			if is_instance_valid(placed_instance):
				placed_instance.queue_free()
			building_instances.erase(origin_tile)
		placed_buildings.erase(origin_tile)
		_rebuild_occupied_positions()
		_refund_partial_cost(building.get("cost", {}))
		_auto_save()
		build_state_changed.emit()
		return true

	if placed_facilities.has(origin_tile):
		var facility_id := str(placed_facilities[origin_tile]["id"])
		var facility_building: Dictionary = BUILDING_DATA.get_building(facility_id)
		if facility_instances.has(origin_tile):
			var instance = facility_instances[origin_tile]
			if is_instance_valid(instance):
				instance.queue_free()
			facility_instances.erase(origin_tile)
		placed_facilities.erase(origin_tile)
		_rebuild_occupied_positions()
		_refund_partial_cost(facility_building.get("cost", {}))
		_auto_save()
		build_state_changed.emit()
		return true

	return false


func is_valid_placement(tile_pos: Vector2i, building_id: String = "") -> bool:
	if not can_use_build_mode():
		return false

	var target_building_id := building_id
	if target_building_id == "":
		target_building_id = get_selected_building_id()

	var building: Dictionary = BUILDING_DATA.get_building(target_building_id)
	if building.is_empty():
		return false

	var tile_size := _get_building_tile_size(building)
	if not _is_area_clear(tile_pos, tile_size):
		return false

	if tile_pos == _get_player_tile_pos():
		return false

	if not _is_area_free_of_world_objects(tile_pos, tile_size):
		return false

	return _has_cost(building["cost"])


func can_place_home_core(tile_pos: Vector2i) -> bool:
	if not can_use_build_mode() or has_home_core():
		return false

	if tile_pos == _get_player_tile_pos():
		return false

	if not _is_area_clear(tile_pos, Vector2i.ONE):
		return false

	if not _is_area_free_of_world_objects(tile_pos, Vector2i.ONE):
		return false

	return _has_cost(HOME_CORE_COST)


func place_home_core(tile_pos: Vector2i) -> bool:
	if not can_place_home_core(tile_pos):
		return false

	if not _consume_cost(HOME_CORE_COST):
		return false

	home_core_position = _tile_to_world_center(tile_pos)
	_spawn_home_core()
	_rebuild_occupied_positions()
	_auto_save()
	build_state_changed.emit()
	return true


func has_home_core() -> bool:
	return home_core_position != Vector2.ZERO


func get_ui_state() -> Dictionary:
	var building := get_selected_building()
	var category_id := get_selected_category_id()
	var category_buildings: Array[Dictionary] = BUILDING_DATA.get_buildings_for_category(category_id)
	var item_names: PackedStringArray = []
	for category_building in category_buildings:
		item_names.append(LocaleManager.L(str(category_building.get("name", ""))))
	return {
		"build_mode": is_build_mode_active(),
		"remove_mode": is_remove_mode(),
		"building": building,
		"can_afford": _has_cost(building.get("cost", {})),
		"has_core": has_home_core(),
		"debug_mode": debug_mode,
		"category_id": category_id,
		"category_name": BUILDING_DATA.get_category_name(category_id),
		"category_index": selected_category_index,
		"category_items": item_names,
		"category_empty": category_buildings.is_empty(),
	}


func _has_cost(cost: Dictionary) -> bool:
	if debug_mode:
		return true

	for resource_id in cost.keys():
		if player.inventory.get_item_count(resource_id) < int(cost[resource_id]):
			return false
	return true


func _consume_cost(cost: Dictionary) -> bool:
	if debug_mode:
		return true

	if not _has_cost(cost):
		return false

	for resource_id in cost.keys():
		player.inventory.remove_item(resource_id, int(cost[resource_id]))
	return true


func _refund_partial_cost(cost: Dictionary) -> void:
	for resource_id in cost.keys():
		var refund_amount := int(floor(float(cost[resource_id]) * 0.5))
		if refund_amount > 0:
			player.inventory.add_item(resource_id, refund_amount)


func _refund_full_cost(cost: Dictionary) -> void:
	for resource_id in cost.keys():
		player.inventory.add_item(resource_id, int(cost[resource_id]))


func _has_blocking_world_object(tile_pos: Vector2i) -> bool:
	if active_level == null:
		return false

	for child in active_level.get_children():
		if child == building_layer:
			continue
		if child == home_core_instance:
			if _world_to_tile(child.global_position) == tile_pos:
				return true
			continue
		if child.has_method("hit") or (child.has_method("get_interaction_prompt") and child.get_node_or_null("InteractionArea") != null):
			if _world_to_tile(child.global_position) == tile_pos:
				return true

	return false


func _get_player_tile_pos() -> Vector2i:
	return _world_to_tile(player.global_position)


func _world_to_tile(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func _tile_to_world_center(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE / 2, tile_pos.y * TILE_SIZE + TILE_SIZE / 2)


func _auto_save() -> void:
	BUILDING_SAVE.save_buildings(placed_buildings, home_core_position, _serialize_facilities())


func _apply_saved_state_to_level() -> void:
	if active_level == null:
		return

	if building_layer != null:
		building_layer.clear()
	for tile_pos in facility_instances.keys():
		var existing = facility_instances[tile_pos]
		if is_instance_valid(existing):
			existing.queue_free()
	facility_instances.clear()
	for tile_pos in building_instances.keys():
		var building_instance = building_instances[tile_pos]
		if is_instance_valid(building_instance):
			building_instance.queue_free()
	building_instances.clear()
	occupied_positions.clear()

	for tile_pos in placed_buildings.keys():
		var building_id := str(placed_buildings[tile_pos])
		var building := BUILDING_DATA.get_building(building_id)
		if building.is_empty():
			continue
		_place_tile_building(tile_pos, building)

	for tile_pos in placed_facilities.keys():
		var facility_data: Dictionary = placed_facilities[tile_pos]
		var facility_building := BUILDING_DATA.get_building(str(facility_data.get("id", "")))
		if facility_building.is_empty():
			continue
		_spawn_facility_instance(tile_pos, facility_building, facility_data.get("data", {}))

	_rebuild_occupied_positions()
	_spawn_home_core()


func _spawn_home_core() -> void:
	if active_level == null:
		return

	if home_core_instance != null and is_instance_valid(home_core_instance):
		home_core_instance.queue_free()
		home_core_instance = null

	if home_core_position == Vector2.ZERO:
		return

	home_core_instance = HOME_CORE_SCENE.instantiate()
	active_level.add_child(home_core_instance)
	home_core_instance.place_at(home_core_position)
	if home_core_instance.has_signal("destroyed") and not home_core_instance.destroyed.is_connected(_on_home_core_destroyed):
		home_core_instance.destroyed.connect(_on_home_core_destroyed)
	if active_level != null and active_level.has_method("clear_base_area_around"):
		active_level.clear_base_area_around(home_core_position)


func _ensure_preview() -> void:
	if preview != null and is_instance_valid(preview):
		return

	preview = BUILD_PREVIEW_SCENE.instantiate()
	preview.set_building_system(self)

	var preview_parent = get_tree().current_scene
	if preview_parent == null:
		preview_parent = get_tree().root
	preview_parent.call_deferred("add_child", preview)


func _place_facility(tile_pos: Vector2i, building: Dictionary) -> bool:
	placed_facilities[tile_pos] = {
		"id": str(building["id"]),
		"data": {},
	}
	if _spawn_facility_instance(tile_pos, building, {}):
		return true
	placed_facilities.erase(tile_pos)
	return false


func _spawn_facility_instance(tile_pos: Vector2i, building: Dictionary, data: Dictionary) -> bool:
	if active_level == null:
		return false

	var scene_path := str(building.get("scene_path", ""))
	if scene_path == "":
		return false

	var scene: PackedScene = load(scene_path)
	if scene == null:
		return false

	if facility_instances.has(tile_pos):
		var existing = facility_instances[tile_pos]
		if is_instance_valid(existing):
			existing.queue_free()

	var instance = scene.instantiate()
	instance.global_position = _tile_to_world_center_for_size(tile_pos, _get_building_tile_size(building))
	active_level.add_child(instance)
	if instance.has_method("load_from_data"):
		instance.load_from_data(data)
	if instance.has_signal("chest_changed") and not instance.chest_changed.is_connected(_on_facility_changed):
		instance.chest_changed.connect(_on_facility_changed.bind(tile_pos))
	if instance.has_signal("farm_changed") and not instance.farm_changed.is_connected(_on_facility_changed):
		instance.farm_changed.connect(_on_facility_changed.bind(tile_pos))
	facility_instances[tile_pos] = instance
	return true


func _place_tile_building(tile_pos: Vector2i, building: Dictionary) -> bool:
	if building_container == null:
		return false

	if building_instances.has(tile_pos):
		var existing = building_instances[tile_pos]
		if is_instance_valid(existing):
			existing.queue_free()

	var placed_root := Node2D.new()
	placed_root.position = _tile_to_world_center(tile_pos)
	placed_root.z_index = 0
	placed_root.name = "%s_%d_%d" % [str(building.get("id", "building")), tile_pos.x, tile_pos.y]

	var sprite := Sprite2D.new()
	sprite.texture = building.get("preview_texture", null)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	placed_root.add_child(sprite)

	if bool(building.get("has_collision", false)):
		var blocker := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16, 16)
		collision.shape = shape
		blocker.add_child(collision)
		placed_root.add_child(blocker)

	building_container.add_child(placed_root)
	building_instances[tile_pos] = placed_root
	return true


func _on_facility_changed(tile_pos: Vector2i) -> void:
	if not placed_facilities.has(tile_pos):
		return
	var instance = facility_instances.get(tile_pos, null)
	if instance != null and instance.has_method("serialize_data"):
		var record: Dictionary = placed_facilities[tile_pos]
		record["data"] = instance.serialize_data()
		placed_facilities[tile_pos] = record
	_auto_save()


func _on_home_core_destroyed() -> void:
	home_core_position = Vector2.ZERO
	home_core_instance = null
	_rebuild_occupied_positions()
	_auto_save()
	build_state_changed.emit()


func has_functional_core() -> bool:
	return home_core_instance != null and is_instance_valid(home_core_instance) and home_core_position != Vector2.ZERO


func get_home_core():
	if has_functional_core():
		return home_core_instance
	return null


func _serialize_facilities() -> Array:
	var payload: Array = []
	for tile_pos in placed_facilities.keys():
		var record: Dictionary = placed_facilities[tile_pos].duplicate(true)
		record["position"] = [tile_pos.x, tile_pos.y]
		var instance = facility_instances.get(tile_pos, null)
		if instance != null and instance.has_method("serialize_data"):
			record["data"] = instance.serialize_data()
		payload.append(record)
	return payload


func _normalize_facility_save_data(saved_facilities: Array) -> Dictionary:
	var normalized: Dictionary = {}
	for facility_variant in saved_facilities:
		if typeof(facility_variant) != TYPE_DICTIONARY:
			continue
		var facility: Dictionary = facility_variant
		var pos_data = facility.get("position", [])
		if pos_data is Array and pos_data.size() >= 2:
			normalized[Vector2i(int(pos_data[0]), int(pos_data[1]))] = {
				"id": str(facility.get("id", "")),
				"data": facility.get("data", {}),
			}
	return normalized


func _is_position_occupied(tile_pos: Vector2i) -> bool:
	return occupied_positions.has(tile_pos)


func _get_building_tile_size(building: Dictionary) -> Vector2i:
	return building.get("tile_size", Vector2i.ONE)


func _is_area_clear(origin_tile: Vector2i, tile_size: Vector2i) -> bool:
	for occupy_tile: Vector2i in _get_occupied_tiles(origin_tile, tile_size):
		if occupied_positions.has(occupy_tile):
			return false
	return true


func _is_area_free_of_world_objects(origin_tile: Vector2i, tile_size: Vector2i) -> bool:
	for occupy_tile: Vector2i in _get_occupied_tiles(origin_tile, tile_size):
		if occupy_tile == _get_player_tile_pos():
			return false
		if _has_blocking_world_object(occupy_tile):
			return false
	return true


func _get_occupied_tiles(origin_tile: Vector2i, tile_size: Vector2i) -> Array[Vector2i]:
	var occupied_tiles: Array[Vector2i] = []
	for x in range(tile_size.x):
		for y in range(tile_size.y):
			occupied_tiles.append(Vector2i(origin_tile.x + x, origin_tile.y + y))
	return occupied_tiles


func _tile_to_world_center_for_size(tile_pos: Vector2i, tile_size: Vector2i) -> Vector2:
	return Vector2(
		tile_pos.x * TILE_SIZE + float(tile_size.x * TILE_SIZE) * 0.5,
		tile_pos.y * TILE_SIZE + float(tile_size.y * TILE_SIZE) * 0.5
	)


func _rebuild_occupied_positions() -> void:
	occupied_positions.clear()
	for tile_pos in placed_buildings.keys():
		var building_id := str(placed_buildings[tile_pos])
		var building := BUILDING_DATA.get_building(building_id)
		if building.is_empty():
			continue
		_register_occupied_tiles(tile_pos, building_id, _get_building_tile_size(building), "tile")
	for tile_pos in placed_facilities.keys():
		var facility_id := str(placed_facilities[tile_pos].get("id", ""))
		var facility_building := BUILDING_DATA.get_building(facility_id)
		if facility_building.is_empty():
			continue
		_register_occupied_tiles(tile_pos, facility_id, _get_building_tile_size(facility_building), "facility")
	if home_core_position != Vector2.ZERO:
		var core_tile := _world_to_tile(home_core_position)
		occupied_positions[core_tile] = {
			"id": "home_core",
			"origin": core_tile,
			"kind": "core",
		}


func _register_occupied_tiles(origin_tile: Vector2i, building_id: String, tile_size: Vector2i, kind: String) -> void:
	for occupy_tile: Vector2i in _get_occupied_tiles(origin_tile, tile_size):
		occupied_positions[occupy_tile] = {
			"id": building_id,
			"origin": origin_tile,
			"kind": kind,
		}

