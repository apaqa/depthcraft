extends Node2D

const GROUND_SIZE := Vector2i(28, 18)
const SOURCE_OUTDOOR_GROUND := 5

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
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
			tile_map_layer.set_cell(coords, SOURCE_OUTDOOR_GROUND, Vector2i.ZERO)

	tile_map_layer.update_internals()
