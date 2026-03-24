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
var placed_buildings: Dictionary = {}
var selected_building_index: int = 0
var preview = null
var home_core_position: Vector2 = Vector2.ZERO
var home_core_instance = null
var debug_mode: bool = false
var _loaded_from_save: bool = false


func _ready() -> void:
	_ensure_preview()
	build_state_changed.emit()


func set_active_level(level_id: String, level) -> void:
	active_level_id = level_id
	active_level = level
	building_layer = null

	if active_level != null:
		building_layer = active_level.get_node_or_null("BuildingLayer")

	if active_level_id != "overworld":
		exit_build_mode()
		return

	if not _loaded_from_save:
		var save_data: Dictionary = BUILDING_SAVE.load_buildings()
		placed_buildings = save_data.get("buildings", {})
		home_core_position = save_data.get("core_position", Vector2.ZERO)
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
			print("BUILD: left click detected")
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
	return active_level_id == "overworld" and building_layer != null


func get_selected_building() -> Dictionary:
	var buildings := BUILDING_DATA.get_all_buildings()
	if buildings.is_empty():
		return {}
	return buildings[selected_building_index]


func get_selected_building_id() -> String:
	var building := get_selected_building()
	return str(building.get("id", ""))


func cycle_selected_building(direction: int) -> void:
	var buildings := BUILDING_DATA.get_all_buildings()
	if buildings.is_empty():
		return

	selected_building_index = wrapi(selected_building_index + direction, 0, buildings.size())
	if state == BuildState.REMOVING:
		state = BuildState.PLACING
	build_state_changed.emit()


func get_hovered_tile_pos() -> Vector2i:
	var mouse_world_pos: Vector2 = player.get_global_mouse_position()
	return Vector2i(floori(mouse_world_pos.x / TILE_SIZE), floori(mouse_world_pos.y / TILE_SIZE))


func get_preview_modulate(tile_pos: Vector2i) -> Color:
	if state == BuildState.REMOVING:
		if placed_buildings.has(tile_pos):
			return Color(1.0, 0.75, 0.35, 0.5)
		return Color(1.0, 0.3, 0.3, 0.5)

	if is_valid_placement(tile_pos, get_selected_building_id()):
		return Color(0.3, 1.0, 0.3, 0.5)
	return Color(1.0, 0.3, 0.3, 0.5)


func get_selected_building_texture() -> Texture2D:
	if building_layer == null:
		return null

	var building := get_selected_building()
	if building.is_empty():
		return null

	var source := building_layer.tile_set.get_source(int(building["tile_source_id"]))
	if source == null:
		return null
	return source.texture


func place_building(tile_pos: Vector2i, building_id: String) -> bool:
	var building: Dictionary = BUILDING_DATA.get_building(building_id)
	if building.is_empty():
		print("BUILD: missing building data for ", building_id)
		return false

	var is_valid := is_valid_placement(tile_pos, building_id)
	print("BUILD: validation result = ", is_valid)
	if not is_valid:
		print("BUILD: placement blocked for ", building_id, " at ", tile_pos)
		return false

	if not _consume_cost(building["cost"]):
		print("BUILD: cost check failed for ", building_id, " at ", tile_pos)
		return false

	print("BUILD: placing ", building_id, " at ", tile_pos)
	print("BUILD: layer=", building_layer, " source_id=", int(building["tile_source_id"]), " atlas=", building["tile_atlas_coords"])
	building_layer.set_cell(tile_pos, int(building["tile_source_id"]), building["tile_atlas_coords"], 0)
	print("BUILD: set_cell called on layer")
	placed_buildings[tile_pos] = building_id
	_auto_save()
	build_state_changed.emit()
	return true


func remove_building(tile_pos: Vector2i) -> bool:
	if not placed_buildings.has(tile_pos):
		return false

	var building_id := str(placed_buildings[tile_pos])
	var building: Dictionary = BUILDING_DATA.get_building(building_id)
	building_layer.erase_cell(tile_pos)
	placed_buildings.erase(tile_pos)
	_refund_partial_cost(building.get("cost", {}))
	_auto_save()
	build_state_changed.emit()
	return true


func is_valid_placement(tile_pos: Vector2i, building_id: String = "") -> bool:
	if not can_use_build_mode():
		return false

	if building_layer.get_cell_source_id(tile_pos) != -1:
		return false

	if placed_buildings.has(tile_pos):
		return false

	if tile_pos == _get_player_tile_pos():
		return false

	if _has_blocking_world_object(tile_pos):
		return false

	var target_building_id := building_id
	if target_building_id == "":
		target_building_id = get_selected_building_id()

	var building: Dictionary = BUILDING_DATA.get_building(target_building_id)
	if building.is_empty():
		return false

	return _has_cost(building["cost"])


func can_place_home_core(tile_pos: Vector2i) -> bool:
	if not can_use_build_mode() or has_home_core():
		return false

	if tile_pos == _get_player_tile_pos():
		return false

	if building_layer.get_cell_source_id(tile_pos) != -1:
		return false

	if placed_buildings.has(tile_pos):
		return false

	if _has_blocking_world_object(tile_pos):
		return false

	return _has_cost(HOME_CORE_COST)


func place_home_core(tile_pos: Vector2i) -> bool:
	if not can_place_home_core(tile_pos):
		return false

	if not _consume_cost(HOME_CORE_COST):
		return false

	home_core_position = _tile_to_world_center(tile_pos)
	_spawn_home_core()
	print("Home Core placed at position (%d, %d)" % [int(home_core_position.x), int(home_core_position.y)])
	_auto_save()
	build_state_changed.emit()
	return true


func has_home_core() -> bool:
	return home_core_position != Vector2.ZERO


func get_ui_state() -> Dictionary:
	var building := get_selected_building()
	return {
		"build_mode": is_build_mode_active(),
		"remove_mode": is_remove_mode(),
		"building": building,
		"can_afford": _has_cost(building.get("cost", {})),
		"has_core": has_home_core(),
		"debug_mode": debug_mode,
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
	BUILDING_SAVE.save_buildings(placed_buildings, home_core_position)


func _apply_saved_state_to_level() -> void:
	if building_layer == null:
		return

	building_layer.clear()
	for tile_pos in placed_buildings.keys():
		var building_id := str(placed_buildings[tile_pos])
		var building := BUILDING_DATA.get_building(building_id)
		if building.is_empty():
			continue
		building_layer.set_cell(tile_pos, int(building["tile_source_id"]), building["tile_atlas_coords"], 0)

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


func _ensure_preview() -> void:
	if preview != null and is_instance_valid(preview):
		return

	preview = BUILD_PREVIEW_SCENE.instantiate()
	preview.set_building_system(self)

	var preview_parent = get_tree().current_scene
	if preview_parent == null:
		preview_parent = get_tree().root
	preview_parent.call_deferred("add_child", preview)
