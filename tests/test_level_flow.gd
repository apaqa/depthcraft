extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_level_transition_keeps_player_and_inventory()
	await test_dungeon_border_has_no_empty_cells()
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


func test_dungeon_border_has_no_empty_cells() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon.build_test_room()

	for x in range(dungeon.ROOM_SIZE.x):
		_assert(dungeon.tile_map_layer.get_cell_source_id(Vector2i(x, 0)) != -1, "Top border should be fully walled.")
		_assert(dungeon.tile_map_layer.get_cell_source_id(Vector2i(x, dungeon.ROOM_SIZE.y - 1)) != -1, "Bottom border should be fully walled.")

	for y in range(dungeon.ROOM_SIZE.y):
		_assert(dungeon.tile_map_layer.get_cell_source_id(Vector2i(0, y)) != -1, "Left border should be fully walled.")
		_assert(dungeon.tile_map_layer.get_cell_source_id(Vector2i(dungeon.ROOM_SIZE.x - 1, y)) != -1, "Right border should be fully walled.")

	dungeon.queue_free()
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
