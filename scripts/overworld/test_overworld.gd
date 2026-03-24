extends Node2D

const GROUND_SIZE := Vector2i(28, 18)
const SOURCE_FLOOR_1 := 0
const SOURCE_FLOOR_2 := 1
const SOURCE_FLOOR_3 := 2

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player_spawn: Marker2D = $PlayerSpawn


func _ready() -> void:
	build_ground()


func place_player(player: Node2D) -> void:
	if player.get_parent() != self:
		player.reparent(self)

	player.global_position = player_spawn.global_position


func build_ground() -> void:
	tile_map_layer.clear()

	for y in range(GROUND_SIZE.y):
		for x in range(GROUND_SIZE.x):
			var coords := Vector2i(x, y)
			tile_map_layer.set_cell(coords, _get_floor_source(coords), Vector2i.ZERO)

	tile_map_layer.update_internals()


func _get_floor_source(coords: Vector2i) -> int:
	match (coords.x + coords.y) % 3:
		0:
			return SOURCE_FLOOR_1
		1:
			return SOURCE_FLOOR_2
		_:
			return SOURCE_FLOOR_3
