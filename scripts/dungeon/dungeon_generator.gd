extends RefCounted
class_name DungeonGenerator

const MAP_SIZE := Vector2i(50, 50)
const MIN_ROOM_SIZE := Vector2i(5, 5)
const MAX_ROOM_SIZE := Vector2i(10, 10)
const CORRIDOR_HALF_WIDTH := 1


func generate_floor(floor_number: int) -> Dictionary:
	var room_count := clampi(4 + floor_number, 5, 8)
	var rooms: Array[Rect2i] = []
	var floor_tiles: Dictionary = {}
	var corridors: Array = []

	var attempts := 0
	while rooms.size() < room_count and attempts < room_count * 20:
		attempts += 1
		var room_size := Vector2i(
			randi_range(MIN_ROOM_SIZE.x, MAX_ROOM_SIZE.x),
			randi_range(MIN_ROOM_SIZE.y, MAX_ROOM_SIZE.y)
		)
		var room_pos := Vector2i(
			randi_range(2, MAP_SIZE.x - room_size.x - 3),
			randi_range(2, MAP_SIZE.y - room_size.y - 3)
		)
		var room := Rect2i(room_pos, room_size)
		if _overlaps_existing(room, rooms):
			continue
		rooms.append(room)
		_carve_room(room, floor_tiles)

	if rooms.is_empty():
		var fallback := Rect2i(Vector2i(10, 10), Vector2i(8, 8))
		rooms.append(fallback)
		_carve_room(fallback, floor_tiles)

	for index in range(1, rooms.size()):
		var from_center := _room_center(rooms[index - 1])
		var to_center := _room_center(rooms[index])
		corridors.append({"from": from_center, "to": to_center})
		_carve_corridor(from_center, to_center, floor_tiles)

	var wall_tiles := _build_walls(floor_tiles)
	var spawn_room_index := 0
	var exit_room_index := rooms.size() - 1
	var elite_room_index := 0 if rooms.size() == 1 else randi_range(1, rooms.size() - 1)
	var spawn_point := _tile_to_world(_room_center(rooms[spawn_room_index]))
	var exit_point := _tile_to_world(_room_center(rooms[exit_room_index]))

	return {
		"rooms": rooms,
		"corridors": corridors,
		"spawn_point": spawn_point,
		"exit_point": exit_point,
		"elite_room_index": elite_room_index,
		"spawn_room_index": spawn_room_index,
		"exit_room_index": exit_room_index,
		"floor_tiles": floor_tiles.keys(),
		"wall_tiles": wall_tiles.keys(),
		"enemy_count_hint": max(rooms.size() + floor_number, 1),
	}


func _overlaps_existing(candidate: Rect2i, rooms: Array[Rect2i]) -> bool:
	var padded := Rect2i(candidate.position - Vector2i.ONE, candidate.size + Vector2i.ONE * 2)
	for room in rooms:
		if padded.intersects(room):
			return true
	return false


func _carve_room(room: Rect2i, floor_tiles: Dictionary) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			floor_tiles[Vector2i(x, y)] = true


func _carve_corridor(from_tile: Vector2i, to_tile: Vector2i, floor_tiles: Dictionary) -> void:
	var current := from_tile
	while current.x != to_tile.x:
		_carve_corridor_brush(current, floor_tiles)
		current.x += 1 if to_tile.x > current.x else -1

	while current.y != to_tile.y:
		_carve_corridor_brush(current, floor_tiles)
		current.y += 1 if to_tile.y > current.y else -1

	_carve_corridor_brush(to_tile, floor_tiles)


func _carve_corridor_brush(center_tile: Vector2i, floor_tiles: Dictionary) -> void:
	for y in range(center_tile.y - CORRIDOR_HALF_WIDTH, center_tile.y + CORRIDOR_HALF_WIDTH + 1):
		for x in range(center_tile.x - CORRIDOR_HALF_WIDTH, center_tile.x + CORRIDOR_HALF_WIDTH + 1):
			floor_tiles[Vector2i(x, y)] = true


func _build_walls(floor_tiles: Dictionary) -> Dictionary:
	var walls: Dictionary = {}
	for floor_tile: Vector2i in floor_tiles.keys():
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var wall_tile: Vector2i = floor_tile + offset
			if floor_tiles.has(wall_tile):
				continue
			walls[wall_tile] = true
	for x in range(MAP_SIZE.x):
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, MAP_SIZE.y - 1)] = true
	for y in range(MAP_SIZE.y):
		walls[Vector2i(0, y)] = true
		walls[Vector2i(MAP_SIZE.x - 1, y)] = true
	return walls


func _room_center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2


func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
