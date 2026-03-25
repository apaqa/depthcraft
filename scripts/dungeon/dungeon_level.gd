extends Node2D

signal floor_changed(current_floor: int)
signal kills_changed(total_kills: int)
signal return_to_surface_requested
signal buff_selection_requested(options: Array)
signal floor_transition_requested(next_floor: int)

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
const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")
const STAIRWAY_SCENE := preload("res://scenes/dungeon/stairway.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")
const ELITE_ENEMY_SCENE := preload("res://scenes/enemies/elite_enemy.tscn")

@export var current_floor: int = 1
@export var level_seed: int = 1

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var wall_collision_root: Node2D = $WallCollisionRoot
@onready var feature_root: Node2D = $FeatureRoot
@onready var enemy_root: Node2D = $EnemyRoot
@onready var loot_root: Node2D = $LootRoot

var player = null
var floor_data: Dictionary = {}
var total_kills: int = 0
var gameplay_paused: bool = false


func _ready() -> void:
	_generate_floor()


func place_player(new_player: Node2D, _spawn_override: Variant = null) -> void:
	player = new_player
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = get_spawn_position(_spawn_override)
	_spawn_enemies()


func descend_floor() -> void:
	current_floor += 1
	_generate_floor()
	if player != null and is_instance_valid(player):
		player.global_position = floor_data.get("spawn_point", Vector2.ZERO)


func _generate_floor() -> void:
	var generator := DUNGEON_GENERATOR.new()
	floor_data = generator.generate_floor(current_floor, _create_rng(17))
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
	if stairway.has_method("set_stair_variant"):
		stairway.set_stair_variant("down")
	stairway.descend_requested.connect(_on_descend_requested)
	feature_root.add_child(stairway)

	var return_exit = STAIRWAY_SCENE.instantiate()
	return_exit.global_position = floor_data.get("spawn_point", Vector2.ZERO)
	return_exit.prompt_text = "[F] Return to Surface (Keep Loot)"
	return_exit.uses_secondary_input = true
	if return_exit.has_method("set_stair_variant"):
		return_exit.set_stair_variant("up")
	return_exit.return_surface_requested.connect(_on_return_surface_requested)
	feature_root.add_child(return_exit)


func _spawn_enemies() -> void:
	for child in enemy_root.get_children():
		child.queue_free()

	if player == null or not is_instance_valid(player):
		return

	var rng := _create_rng(41)
	var config := get_floor_spawn_config(current_floor, rng)
	var rooms: Array = floor_data.get("rooms", [])
	var eligible_rooms: Array[int] = []
	for room_index in range(rooms.size()):
		if room_index == int(floor_data.get("spawn_room_index", 0)) or room_index == int(floor_data.get("exit_room_index", 0)):
			continue
		eligible_rooms.append(room_index)
		var room: Rect2i = rooms[room_index]
		var enemy_count := rng.randi_range(int(config["enemy_min"]), int(config["enemy_max"]))
		for _enemy_index in range(enemy_count):
			var enemy_scene: PackedScene = MELEE_ENEMY_SCENE
			if bool(config["allow_ranged"]):
				enemy_scene = MELEE_ENEMY_SCENE if rng.randf() > float(config["ranged_ratio"]) else RANGED_ENEMY_SCENE
			var enemy = enemy_scene.instantiate()
			enemy.global_position = _random_point_in_room(room, rng)
			enemy.configure_for_floor(player, current_floor, loot_root)
			enemy.died.connect(_on_enemy_died.bind(enemy))
			enemy_root.add_child(enemy)
	var elite_count: int = min(int(config["elite_count"]), eligible_rooms.size())
	_shuffle_with_rng(eligible_rooms, rng)
	for elite_index in range(elite_count):
		var elite_room: Rect2i = rooms[int(eligible_rooms[elite_index])]
		var elite: Enemy = ELITE_ENEMY_SCENE.instantiate()
		elite.global_position = _random_point_in_room(elite_room, rng)
		elite.configure_for_floor(player, current_floor, loot_root)
		elite.died.connect(_on_enemy_died.bind(elite))
		enemy_root.add_child(elite)
	set_gameplay_paused(gameplay_paused)


func _on_enemy_died(_enemy_position: Vector2, enemy_ref) -> void:
	total_kills += 1
	kills_changed.emit(total_kills)
	if enemy_ref != null and enemy_ref.has_method("is_elite_enemy") and enemy_ref.is_elite_enemy():
		set_gameplay_paused(true)
		buff_selection_requested.emit(BUFF_SYSTEM.generate_random_buffs())


func _on_descend_requested() -> void:
	floor_transition_requested.emit(current_floor + 1)
	await get_tree().create_timer(0.5).timeout
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


func _random_point_in_room(room: Rect2i, rng: RandomNumberGenerator = null) -> Vector2:
	return Vector2(
		_rng_range(rng, room.position.x + 1, room.end.x - 2) * 16 + 8,
		_rng_range(rng, room.position.y + 1, room.end.y - 2) * 16 + 8
	)


func _random_edge_point_in_room(room: Rect2i, rng: RandomNumberGenerator = null) -> Vector2:
	var side := _rng_range(rng, 0, 3)
	var x: int
	var y: int
	match side:
		0:
			x = _rng_range(rng, room.position.x + 1, room.end.x - 2)
			y = room.position.y + 1
		1:
			x = _rng_range(rng, room.position.x + 1, room.end.x - 2)
			y = room.end.y - 2
		2:
			x = room.position.x + 1
			y = _rng_range(rng, room.position.y + 1, room.end.y - 2)
		_:
			x = room.end.x - 2
			y = _rng_range(rng, room.position.y + 1, room.end.y - 2)
	return Vector2(x * 16 + 8, y * 16 + 8)


func _spawn_wall_blocker(tile_pos: Vector2i) -> void:
	var blocker := StaticBody2D.new()
	blocker.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(17, 17)
	collision.shape = shape
	blocker.add_child(collision)
	wall_collision_root.add_child(blocker)


func get_floor_spawn_config(floor_number: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if floor_number <= 2:
		return {"enemy_min": 2, "enemy_max": 3, "allow_ranged": false, "ranged_ratio": 0.0, "elite_count": 0}
	if floor_number <= 5:
		var elite_count := 1 if _rng_randf(rng) <= 0.5 else 0
		return {"enemy_min": 3, "enemy_max": 4, "allow_ranged": true, "ranged_ratio": 0.3, "elite_count": elite_count}
	if floor_number <= 10:
		return {"enemy_min": 4, "enemy_max": 5, "allow_ranged": true, "ranged_ratio": 0.45, "elite_count": 1}
	return {"enemy_min": 5, "enemy_max": 6, "allow_ranged": true, "ranged_ratio": 0.55, "elite_count": _rng_range(rng, 1, 2)}


func set_gameplay_paused(paused: bool) -> void:
	gameplay_paused = paused
	for enemy in enemy_root.get_children():
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(paused)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT


func get_minimap_snapshot() -> Dictionary:
	var enemy_positions: Array[Vector2] = []
	for enemy in enemy_root.get_children():
		enemy_positions.append(enemy.global_position)
	return {
		"map_size": DUNGEON_GENERATOR.MAP_SIZE,
		"floor_tiles": floor_data.get("floor_tiles", []),
		"enemy_positions": enemy_positions,
		"stair_tile": Vector2(floor_data.get("exit_point", Vector2.ZERO).x / 16.0, floor_data.get("exit_point", Vector2.ZERO).y / 16.0),
		"spawn_tile": Vector2(floor_data.get("spawn_point", Vector2.ZERO).x / 16.0, floor_data.get("spawn_point", Vector2.ZERO).y / 16.0),
		"player_tile": Vector2(player.global_position.x / 16.0, player.global_position.y / 16.0) if player != null else Vector2.ZERO,
	}


func get_spawn_position(spawn_override: Variant = null) -> Vector2:
	if spawn_override is Vector2:
		return spawn_override
	return floor_data.get("spawn_point", Vector2.ZERO)


func _create_rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_seed) + current_floor * 1009 + offset
	return rng


func _rng_range(rng: RandomNumberGenerator, min_value: int, max_value: int) -> int:
	return rng.randi_range(min_value, max_value) if rng != null else randi_range(min_value, max_value)


func _rng_randf(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()


func _shuffle_with_rng(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current_value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = current_value
