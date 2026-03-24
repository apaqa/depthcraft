extends SceneTree

const BUILDING_DATA := preload("res://scripts/building/building_data.gd")
const BUILDING_SAVE := preload("res://scripts/building/building_save.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OVERWORLD_SCENE := preload("res://scenes/overworld/test_overworld.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	BUILDING_SAVE.clear_save()
	await test_building_data_cost()
	await test_building_data_list()
	await test_building_tiles_use_distinct_visual_sources()
	await test_place_building_deducts_resources()
	await test_place_building_only_consumes_costed_resource()
	await test_place_building_fails_without_resources()
	await test_debug_mode_skips_resource_costs()
	await test_left_click_input_places_building()
	await test_remove_building_returns_partial_resources()
	await test_cannot_place_on_occupied_tile()
	await test_invalid_for_player_position()
	await test_home_core_only_once()
	await test_save_and_load_preserves_data()
	await test_building_collision_flags()
	await test_build_mode_only_in_overworld()
	BUILDING_SAVE.clear_save()
	_report_results()


func test_building_data_cost() -> void:
	var building: Dictionary = BUILDING_DATA.get_building("wood_wall")
	_assert(int(building["cost"]["wood"]) == 2, "Wood wall should cost 2 wood.")


func test_building_data_list() -> void:
	var buildings: Array[Dictionary] = BUILDING_DATA.get_all_buildings()
	_assert(buildings.size() >= 5, "Building data should expose all buildable tiles.")


func test_building_tiles_use_distinct_visual_sources() -> void:
	var wood_floor: Dictionary = BUILDING_DATA.get_building("wood_floor")
	var stone_floor: Dictionary = BUILDING_DATA.get_building("stone_floor")
	var wood_wall: Dictionary = BUILDING_DATA.get_building("wood_wall")
	var stone_wall: Dictionary = BUILDING_DATA.get_building("stone_wall")
	var wood_door: Dictionary = BUILDING_DATA.get_building("wood_door")
	_assert(int(wood_floor["tile_source_id"]) == 3, "Wood floor should use the dedicated brighter build-floor tile.")
	_assert(int(stone_floor["tile_source_id"]) == 4, "Stone floor should use the distinct stone build-floor tile.")
	_assert(int(wood_wall["tile_source_id"]) == 106, "Wood wall should use the wooden barricade tile.")
	_assert(int(stone_wall["tile_source_id"]) == 107, "Stone wall should use the distinct stone wall tile.")
	_assert(int(wood_door["tile_source_id"]) == 108, "Wood door should use the door tile.")


func test_place_building_deducts_resources() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 5)
	var result: bool = setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	_assert(result, "Placing a wood wall with resources should succeed.")
	_assert(setup.player.inventory.get_item_count("wood") == 3, "Placing a wood wall should deduct 2 wood.")
	await _cleanup_setup(setup)


func test_place_building_only_consumes_costed_resource() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 10)
	setup.player.inventory.add_item("stone", 5)
	var result: bool = setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	_assert(result, "Placing a wood wall with mixed inventory resources should succeed.")
	_assert(setup.player.inventory.get_item_count("wood") == 8, "Placing a wood wall should only remove 2 wood.")
	_assert(setup.player.inventory.get_item_count("stone") == 5, "Placing a wood wall should not affect stone.")
	await _cleanup_setup(setup)


func test_place_building_fails_without_resources() -> void:
	var setup := await _create_overworld_setup()
	_assert(not setup.building_system.place_building(Vector2i(2, 2), "wood_wall"), "Placement should fail without enough resources.")
	await _cleanup_setup(setup)


func test_debug_mode_skips_resource_costs() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 1)
	setup.building_system.toggle_debug_mode()
	var result: bool = setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	_assert(result, "Debug mode should allow building without enough resources.")
	_assert(setup.player.inventory.get_item_count("wood") == 1, "Debug mode should not consume resources.")
	setup.building_system.toggle_debug_mode()
	await _cleanup_setup(setup)


func test_left_click_input_places_building() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 5)
	setup.building_system.toggle_build_mode()

	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = Vector2(40, 40)
	mouse_event.global_position = mouse_event.position
	Input.parse_input_event(mouse_event)
	await process_frame
	var placed_before: int = setup.building_system.placed_buildings.size()

	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = mouse_event.position
	click_event.global_position = mouse_event.position
	Input.parse_input_event(click_event)
	await process_frame

	_assert(setup.building_system.placed_buildings.size() == placed_before + 1, "Left click in build mode should place a building.")
	await _cleanup_setup(setup)


func test_remove_building_returns_partial_resources() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 5)
	setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	var removed: bool = setup.building_system.remove_building(Vector2i(2, 2))
	_assert(removed, "Removing a placed building should succeed.")
	_assert(setup.player.inventory.get_item_count("wood") == 4, "Removing a wood wall should refund 1 wood.")
	await _cleanup_setup(setup)


func test_cannot_place_on_occupied_tile() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 10)
	setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	_assert(not setup.building_system.place_building(Vector2i(2, 2), "wood_floor"), "Cannot place on an occupied tile.")
	await _cleanup_setup(setup)


func test_invalid_for_player_position() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 3)
	var player_tile: Vector2i = setup.building_system._world_to_tile(setup.player.global_position)
	_assert(not setup.building_system.is_valid_placement(player_tile, "wood_wall"), "Cannot place a building on the player's tile.")
	await _cleanup_setup(setup)


func test_home_core_only_once() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 20)
	setup.player.inventory.add_item("stone", 10)
	_assert(setup.building_system.place_home_core(Vector2i(3, 3)), "First home core placement should succeed.")
	_assert(not setup.building_system.place_home_core(Vector2i(4, 4)), "Home core can only be placed once.")
	await _cleanup_setup(setup)


func test_save_and_load_preserves_data() -> void:
	var setup := await _create_overworld_setup()
	setup.player.inventory.add_item("wood", 20)
	setup.player.inventory.add_item("stone", 10)
	setup.building_system.place_building(Vector2i(2, 2), "wood_wall")
	setup.building_system.place_home_core(Vector2i(3, 3))

	var loaded: Dictionary = BUILDING_SAVE.load_buildings()
	_assert(loaded["buildings"].has(Vector2i(2, 2)), "Saved data should include placed buildings.")
	_assert(loaded["core_position"] != Vector2.ZERO, "Saved data should include the home core position.")
	await _cleanup_setup(setup)


func test_building_collision_flags() -> void:
	var wall: Dictionary = BUILDING_DATA.get_building("stone_wall")
	var floor_building: Dictionary = BUILDING_DATA.get_building("stone_floor")
	_assert(bool(wall["has_collision"]), "Stone wall should have collision.")
	_assert(not bool(floor_building["has_collision"]), "Stone floor should not have collision.")


func test_build_mode_only_in_overworld() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	_assert(not player.building_system.toggle_build_mode(), "Build mode should not activate before entering an overworld level.")
	player.queue_free()
	await process_frame


func _create_overworld_setup() -> Dictionary:
	BUILDING_SAVE.clear_save()
	var level = OVERWORLD_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(level)
	root.add_child(player)
	await process_frame
	level.place_player(player)
	player.building_system.set_active_level("overworld", level)
	player.building_system.exit_build_mode()
	player.inventory.items.clear()
	return {
		"level": level,
		"player": player,
		"building_system": player.building_system,
	}


func _cleanup_setup(setup: Dictionary) -> void:
	setup["player"].queue_free()
	setup["level"].queue_free()
	await process_frame
	BUILDING_SAVE.clear_save()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All building tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
