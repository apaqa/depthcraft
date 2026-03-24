extends Node2D

const ROOM_SIZE := Vector2i(15, 11)
const SOURCE_FLOOR_1 := 0
const SOURCE_FLOOR_2 := 1
const SOURCE_FLOOR_3 := 2
const SOURCE_TOP_LEFT := 100
const SOURCE_TOP_MID := 101
const SOURCE_TOP_RIGHT := 102
const SOURCE_WALL_LEFT := 103
const SOURCE_WALL_RIGHT := 104
const SOURCE_WALL_MID := 105
const DOORWAY_Y := 5

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	build_test_room()


func build_test_room() -> void:
	tile_map_layer.clear()

	for y in range(ROOM_SIZE.y):
		for x in range(ROOM_SIZE.x):
			var coords := Vector2i(x, y)
			if is_doorway(coords):
				continue

			if y == 0:
				tile_map_layer.set_cell(coords, get_top_wall_source(x), Vector2i.ZERO)
			elif y == ROOM_SIZE.y - 1:
				tile_map_layer.set_cell(coords, SOURCE_WALL_MID, Vector2i.ZERO)
			elif x == 0:
				tile_map_layer.set_cell(coords, SOURCE_WALL_LEFT, Vector2i.ZERO)
			elif x == ROOM_SIZE.x - 1:
				tile_map_layer.set_cell(coords, SOURCE_WALL_RIGHT, Vector2i.ZERO)
			else:
				tile_map_layer.set_cell(coords, get_floor_source(coords), Vector2i.ZERO)

	tile_map_layer.update_internals()


func place_player(player: Node2D) -> void:
	if player.get_parent() != self:
		player.reparent(self)

	player.global_position = player_spawn.global_position


func get_floor_source(coords: Vector2i) -> int:
	match (coords.x + coords.y) % 3:
		0:
			return SOURCE_FLOOR_1
		1:
			return SOURCE_FLOOR_2
		_:
			return SOURCE_FLOOR_3


func get_top_wall_source(x: int) -> int:
	if x == 0:
		return SOURCE_TOP_LEFT
	if x == ROOM_SIZE.x - 1:
		return SOURCE_TOP_RIGHT
	return SOURCE_TOP_MID


func is_doorway(coords: Vector2i) -> bool:
	return coords.x == ROOM_SIZE.x - 1 and coords.y == DOORWAY_Y
