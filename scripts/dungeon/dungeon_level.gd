extends Node2D

signal floor_changed(current_floor: int)
signal kills_changed(total_kills: int)
signal return_to_surface_requested

const SOURCE_FLOOR_1 := 0
const SOURCE_FLOOR_2 := 1
const SOURCE_FLOOR_3 := 2
const SOURCE_TOP_LEFT := 100
const SOURCE_TOP_MID := 101
const SOURCE_TOP_RIGHT := 102
const SOURCE_WALL_LEFT := 103
const SOURCE_WALL_RIGHT := 104
const SOURCE_WALL_MID := 105

const DUNGEON_GENERATOR := preload("res://scripts/dungeon/dungeon_generator.gd")
const STAIRWAY_SCENE := preload("res://scenes/dungeon/stairway.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")

@export var current_floor: int = 1

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var wall_collision_root: Node2D = $WallCollisionRoot
@onready var feature_root: Node2D = $FeatureRoot
@onready var enemy_root: Node2D = $EnemyRoot
@onready var loot_root: Node2D = $LootRoot

var player = null
var floor_data: Dictionary = {}
var total_kills: int = 0


func _ready() -> void:
	_generate_floor()


func place_player(new_player: Node2D) -> void:
	player = new_player
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = floor_data.get("spawn_point", Vector2.ZERO)
	_spawn_enemies()


func descend_floor() -> void:
	current_floor += 1
	_generate_floor()
	if player != null and is_instance_valid(player):
		player.global_position = floor_data.get("spawn_point", Vector2.ZERO)


func _generate_floor() -> void:
	var generator := DUNGEON_GENERATOR.new()
	floor_data = generator.generate_floor(current_floor)
	_draw_floor()
	_spawn_features()
	_spawn_enemies()
	floor_changed.emit(current_floor)
	kills_changed.emit(total_kills)


func _draw_floor() -> void:
	tile_map_layer.clear()
	for child in wall_collision_root.get_children():
		child.queue_free()
	for floor_tile: Vector2i in floor_data.get("floor_tiles", []):
		tile_map_layer.set_cell(floor_tile, _get_floor_source(floor_tile), Vector2i.ZERO)
	for wall_tile: Vector2i in floor_data.get("wall_tiles", []):
		tile_map_layer.set_cell(wall_tile, _get_wall_source(wall_tile), Vector2i.ZERO)
		_spawn_wall_blocker(wall_tile)
	tile_map_layer.update_internals()


func _spawn_features() -> void:
	for child in feature_root.get_children():
		child.queue_free()

	var stairway = STAIRWAY_SCENE.instantiate()
	stairway.global_position = floor_data.get("exit_point", Vector2.ZERO)
	stairway.prompt_text = "[E] Descend to Floor %d" % (current_floor + 1)
	stairway.descend_requested.connect(_on_descend_requested)
	feature_root.add_child(stairway)

	var return_exit = STAIRWAY_SCENE.instantiate()
	return_exit.global_position = floor_data.get("spawn_point", Vector2.ZERO)
	return_exit.prompt_text = "[F] Return to Surface"
	return_exit.uses_secondary_input = true
	return_exit.return_surface_requested.connect(_on_return_surface_requested)
	feature_root.add_child(return_exit)


func _spawn_enemies() -> void:
	for child in enemy_root.get_children():
		child.queue_free()

	if player == null or not is_instance_valid(player):
		return

	var rooms: Array = floor_data.get("rooms", [])
	for room_index in range(rooms.size()):
		if room_index == int(floor_data.get("spawn_room_index", 0)) or room_index == int(floor_data.get("exit_room_index", 0)):
			continue
		var room: Rect2i = rooms[room_index]
		var enemy_count := randi_range(2, 4) + int(floor(current_floor * 0.3))
		for _enemy_index in range(enemy_count):
			var enemy_scene: PackedScene = MELEE_ENEMY_SCENE if randf() <= 0.7 else RANGED_ENEMY_SCENE
			var enemy = enemy_scene.instantiate()
			enemy.global_position = _random_point_in_room(room)
			enemy.configure_for_floor(player, current_floor, loot_root)
			enemy.died.connect(_on_enemy_died)
			enemy_root.add_child(enemy)


func _on_enemy_died(_enemy_position: Vector2) -> void:
	total_kills += 1
	kills_changed.emit(total_kills)


func _on_descend_requested() -> void:
	descend_floor()


func _on_return_surface_requested() -> void:
	return_to_surface_requested.emit()


func _get_floor_source(coords: Vector2i) -> int:
	match (coords.x + coords.y) % 3:
		0:
			return SOURCE_FLOOR_1
		1:
			return SOURCE_FLOOR_2
		_:
			return SOURCE_FLOOR_3


func _get_wall_source(coords: Vector2i) -> int:
	if not _has_floor_neighbor(coords + Vector2i.UP):
		return SOURCE_WALL_MID
	if not _has_floor_neighbor(coords + Vector2i.LEFT):
		return SOURCE_WALL_LEFT
	if not _has_floor_neighbor(coords + Vector2i.RIGHT):
		return SOURCE_WALL_RIGHT
	return SOURCE_WALL_MID


func _has_floor_neighbor(tile_pos: Vector2i) -> bool:
	for floor_tile: Vector2i in floor_data.get("floor_tiles", []):
		if floor_tile == tile_pos:
			return true
	return false


func _random_point_in_room(room: Rect2i) -> Vector2:
	return Vector2(
		randi_range(room.position.x + 1, room.end.x - 2) * 16 + 8,
		randi_range(room.position.y + 1, room.end.y - 2) * 16 + 8
	)


func _spawn_wall_blocker(tile_pos: Vector2i) -> void:
	var blocker := StaticBody2D.new()
	blocker.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	blocker.add_child(collision)
	wall_collision_root.add_child(blocker)
