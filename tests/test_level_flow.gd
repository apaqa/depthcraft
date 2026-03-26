extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_level_transition_keeps_player_and_inventory()
	await test_generated_dungeon_has_spawn_exit_and_tiles()
	await test_overworld_visual_layers()
	await test_menu_close_restores_player_movement_flag()
	_report_results()


func test_level_transition_keeps_player_and_inventory() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	main.change_level("dungeon")
	var player = main.player
	player.inventory.add_item("wood", 3)
	main.change_level("overworld")
	await process_frame

	_assert(is_instance_valid(player), "Player should remain valid after level transition.")
	_assert(player.get_parent() == main.current_level, "Player should be parented to the active level after transition.")
	_assert(main.current_level_id == "overworld", "Main should track the overworld as the active level.")
	_assert(player.inventory.get_item_count("wood") == 3, "Inventory should persist across level transitions.")

	main.change_level("dungeon")
	await process_frame
	_assert(player.get_parent() == main.current_level, "Player should reattach to the dungeon level after returning.")

	main.queue_free()
	await process_frame


func test_generated_dungeon_has_spawn_exit_and_tiles() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	await process_frame
	var floor_tiles: Array = dungeon.floor_data.get("floor_tiles", [])
	var wall_tiles: Array = dungeon.floor_data.get("wall_tiles", [])
	_assert(not floor_tiles.is_empty(), "Generated dungeon should contain carved floor tiles.")
	_assert(not wall_tiles.is_empty(), "Generated dungeon should contain wall tiles.")
	_assert(dungeon.get_node("WallCollisionRoot").get_child_count() == wall_tiles.size(), "Each dungeon wall tile should spawn an explicit collision blocker.")

	var spawn_point: Vector2 = dungeon.floor_data.get("spawn_point", Vector2.ZERO)
	var exit_point: Vector2 = dungeon.floor_data.get("exit_point", Vector2.ZERO)
	var spawn_tile := Vector2i(int(floor(spawn_point.x / 16.0)), int(floor(spawn_point.y / 16.0)))
	var exit_tile := Vector2i(int(floor(exit_point.x / 16.0)), int(floor(exit_point.y / 16.0)))
	_assert(spawn_point != Vector2.ZERO, "Generated dungeon should provide a spawn point.")
	_assert(exit_point != Vector2.ZERO, "Generated dungeon should provide an exit point.")
	_assert(dungeon.tile_map_layer.get_cell_source_id(spawn_tile) != -1, "Spawn tile should be rendered in the dungeon tilemap.")
	_assert(dungeon.tile_map_layer.get_cell_source_id(exit_tile) != -1, "Exit tile should be rendered in the dungeon tilemap.")

	dungeon.queue_free()
	await process_frame


func test_overworld_visual_layers() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	main.change_level("overworld")
	await process_frame

	var overworld = main.current_level
	_assert(overworld.get_node("BuildingLayer").z_index == 0, "Building layer should render at ground level so built tiles stay visible.")
	_assert(overworld.get_node("BuildingContainer") != null, "Overworld should expose a building container for sprite-based placements.")
	_assert(overworld.get_node("TileMapLayer").modulate == Color(0.7, 0.85, 0.55, 1), "Overworld ground should be brightened for outdoor contrast.")
	_assert(main.player.z_index == 1, "Player should render above the building layer.")

	main.queue_free()
	await process_frame


func test_menu_close_restores_player_movement_flag() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var hud = main.hud
	var player = main.player
	hud._on_crafting_requested(null)
	_assert(player.in_menu, "Opening a menu should mark the player as being in a menu.")
	hud.crafting_menu.close_menu()
	await process_frame
	_assert(not player.in_menu, "Closing a menu should immediately restore movement.")

	main.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All level flow tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)

