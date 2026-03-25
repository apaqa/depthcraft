extends SceneTree

const DUNGEON_GENERATOR := preload("res://scripts/dungeon/dungeon_generator.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	test_generate_floor_creates_rooms()
	test_rooms_do_not_overlap()
	test_spawn_and_exit_are_distinct()
	test_spawn_and_exit_are_on_floor_tiles()
	test_all_rooms_are_connected_by_walkable_path()
	test_deeper_floor_increases_enemy_hint()
	_report_results()


func test_generate_floor_creates_rooms() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(1)
	_assert(floor_data.get("rooms", []).size() >= 1, "Dungeon generator should create at least one room.")
	_assert(floor_data.get("floor_tiles", []).size() > 0, "Dungeon generator should carve floor tiles.")
	_assert(floor_data.get("wall_tiles", []).size() > 0, "Dungeon generator should surround floors with walls.")


func test_rooms_do_not_overlap() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var rooms: Array = generator.generate_floor(2).get("rooms", [])
	for index in range(rooms.size()):
		for other_index in range(index + 1, rooms.size()):
			var padded := Rect2i(rooms[index].position - Vector2i.ONE, rooms[index].size + Vector2i.ONE * 2)
			_assert(not padded.intersects(rooms[other_index]), "Generated rooms should not overlap or touch directly.")


func test_spawn_and_exit_are_distinct() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(3)
	_assert(floor_data.get("spawn_point", Vector2.ZERO) != floor_data.get("exit_point", Vector2.ZERO), "Spawn and exit points should be different.")


func test_spawn_and_exit_are_on_floor_tiles() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(1)
	var walkable := _to_tile_set(floor_data.get("floor_tiles", []))
	_assert(walkable.has(_world_to_tile(floor_data.get("spawn_point", Vector2.ZERO))), "Spawn point should land on a walkable floor tile.")
	_assert(walkable.has(_world_to_tile(floor_data.get("exit_point", Vector2.ZERO))), "Exit point should land on a walkable floor tile.")


func test_all_rooms_are_connected_by_walkable_path() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(4)
	var walkable := _to_tile_set(floor_data.get("floor_tiles", []))
	var start_tile := _world_to_tile(floor_data.get("spawn_point", Vector2.ZERO))
	var goal_tile := _world_to_tile(floor_data.get("exit_point", Vector2.ZERO))
	_assert(_has_path(start_tile, goal_tile, walkable), "Spawn and exit should be connected through floor tiles.")


func test_deeper_floor_increases_enemy_hint() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_one: Dictionary = generator.generate_floor(1)
	var floor_five: Dictionary = generator.generate_floor(5)
	_assert(int(floor_five.get("enemy_count_hint", 0)) >= int(floor_one.get("enemy_count_hint", 0)), "Deeper floors should not reduce the enemy count hint.")


func _to_tile_set(tile_array: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for tile: Vector2i in tile_array:
		lookup[tile] = true
	return lookup


func _world_to_tile(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / 16.0)), int(floor(world_position.y / 16.0)))


func _has_path(start_tile: Vector2i, goal_tile: Vector2i, walkable: Dictionary) -> bool:
	if not walkable.has(start_tile) or not walkable.has(goal_tile):
		return false

	var frontier: Array[Vector2i] = [start_tile]
	var visited: Dictionary = {start_tile: true}
	var index := 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if current == goal_tile:
			return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if visited.has(next) or not walkable.has(next):
				continue
			visited[next] = true
			frontier.append(next)
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All dungeon generation tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
