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
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")
const STAIRWAY_SCENE := preload("res://scenes/dungeon/stairway.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")
const SHIELD_ORC_SCENE := preload("res://scenes/enemies/shield_orc_enemy.tscn")
const BAT_SWARM_SCENE := preload("res://scenes/enemies/bat_swarm_enemy.tscn")
const ELITE_ENEMY_SCENE := preload("res://scenes/enemies/elite_enemy.tscn")
const BOSS_ENEMY_SCENE := preload("res://scenes/enemies/boss_enemy.tscn")
const DUNGEON_CHEST_SCENE := preload("res://scenes/dungeon/dungeon_chest.tscn")
const LOCKED_CHEST_SCENE := preload("res://scenes/dungeon/locked_chest.tscn")
const SPIKE_TRAP_SCENE := preload("res://scenes/dungeon/spike_trap.tscn")
const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")
const EVENT_ROOM_SCRIPT := preload("res://scripts/dungeon/event_room.gd")
const CHALLENGE_ROOM_SCRIPT := preload("res://scripts/dungeon/challenge_room.gd")
const PUZZLE_ROOM_SCRIPT := preload("res://scripts/dungeon/puzzle_room.gd")
const SAFE_ROOM_SCRIPT := preload("res://scripts/dungeon/safe_room.gd")
const DUNGEON_MERCHANT_SCRIPT := preload("res://scripts/dungeon/dungeon_merchant.gd")

@export var current_floor: int = 1
@export var level_seed: int = 1

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var wall_tile_map_layer: TileMapLayer = $WallTileMapLayer
@onready var wall_collision_root: Node2D = $WallCollisionRoot
@onready var feature_root: Node2D = $FeatureRoot
@onready var enemy_root: Node2D = $EnemyRoot
@onready var loot_root: Node2D = $LootRoot

var player = null
var floor_data: Dictionary = {}
var total_kills: int = 0
var gameplay_paused: bool = false
var treasure_reveal_time_left: float = 0.0
var boss_stairway = null
var boss_enemy_ref = null
var boss_locked_chest = null


func _ready() -> void:
	_generate_floor()
	set_process(true)


func _process(delta: float) -> void:
	if treasure_reveal_time_left > 0.0:
		treasure_reveal_time_left = max(treasure_reveal_time_left - delta, 0.0)


func place_player(new_player: Node2D, spawn_override: Variant = null) -> void:
	player = new_player
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = get_spawn_position(spawn_override)
	_update_player_ambient_light()
	_spawn_enemies()


func descend_floor() -> void:
	current_floor += 1
	_generate_floor()
	if player != null and is_instance_valid(player):
		player.global_position = floor_data.get("spawn_point", Vector2.ZERO)


func _generate_floor() -> void:
	var generator := DUNGEON_GENERATOR.new()
	floor_data = generator.generate_floor(current_floor, _create_rng(17))
	boss_stairway = null
	boss_enemy_ref = null
	boss_locked_chest = null
	_draw_floor()
	_spawn_features()
	_spawn_enemies()
	floor_changed.emit(current_floor)
	QuestManager.update_quest_progress("reach_floor", "", current_floor)
	kills_changed.emit(total_kills)


func _draw_floor() -> void:
	tile_map_layer.clear()
	wall_tile_map_layer.clear()
	for child in wall_collision_root.get_children():
		child.queue_free()
	for floor_tile: Vector2i in floor_data.get("floor_tiles", []):
		tile_map_layer.set_cell(floor_tile, _get_floor_source(floor_tile), Vector2i.ZERO)
	for wall_tile: Vector2i in floor_data.get("wall_tiles", []):
		wall_tile_map_layer.set_cell(wall_tile, _get_wall_source(wall_tile), Vector2i.ZERO)
		_spawn_wall_blocker(wall_tile)
	tile_map_layer.update_internals()
	wall_tile_map_layer.update_internals()
	_apply_biome_colors()
	_update_player_ambient_light()


func _apply_biome_colors() -> void:
	if current_floor >= 31:
		tile_map_layer.modulate = Color(0.5, 0.5, 0.6)
		wall_tile_map_layer.modulate = Color(0.5, 0.5, 0.6)
	elif current_floor >= 21:
		tile_map_layer.modulate = Color(0.9, 0.7, 0.6)
		wall_tile_map_layer.modulate = Color(0.7, 0.4, 0.4)
	elif current_floor >= 11:
		tile_map_layer.modulate = Color(1.0, 1.0, 1.0)
		wall_tile_map_layer.modulate = Color(0.7, 0.7, 0.9)
	else:
		tile_map_layer.modulate = Color(1.0, 1.0, 1.0)
		wall_tile_map_layer.modulate = Color(1.0, 1.0, 1.0)


func _update_player_ambient_light() -> void:
	if player == null or not is_instance_valid(player):
		return
	var existing = player.get_node_or_null("DungeonAmbientLight")
	if existing != null:
		existing.queue_free()
	if current_floor >= 31:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.width = 128
		grad_tex.height = 128
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		var light := PointLight2D.new()
		light.name = "DungeonAmbientLight"
		light.texture = grad_tex
		light.energy = 0.6
		light.texture_scale = 3.0
		light.color = Color(0.8, 0.7, 1.0)
		player.add_child(light)


func _spawn_features() -> void:
	for child in feature_root.get_children():
		child.queue_free()

	var stairway = STAIRWAY_SCENE.instantiate()
	stairway.global_position = floor_data.get("exit_point", Vector2.ZERO)
	stairway.prompt_text = LocaleManager.L("prompt_descend_floor") % (current_floor + 1)
	if stairway.has_method("set_stair_variant"):
		stairway.set_stair_variant("down")
	if _is_boss_floor():
		stairway.set_locked(true, LocaleManager.L("prompt_descend_floor") % (current_floor + 1), LocaleManager.L("prompt_defeat_boss_unlock"))
		boss_stairway = stairway
	stairway.descend_requested.connect(_on_descend_requested)
	feature_root.add_child(stairway)

	var return_exit = STAIRWAY_SCENE.instantiate()
	return_exit.global_position = floor_data.get("spawn_point", Vector2.ZERO)
	return_exit.prompt_text = LocaleManager.L("prompt_return_surface")
	return_exit.uses_secondary_input = true
	if return_exit.has_method("set_stair_variant"):
		return_exit.set_stair_variant("up")
	return_exit.return_surface_requested.connect(_on_return_surface_requested)
	feature_root.add_child(return_exit)

	var rooms: Array = floor_data.get("rooms", [])
	var room_types: Array = floor_data.get("room_types", [])
	var room_features: Array = floor_data.get("room_features", [])
	for room_index in range(rooms.size()):
		if room_index >= room_types.size():
			continue
		var room: Rect2i = rooms[room_index]
		var features: Dictionary = room_features[room_index] if room_index < room_features.size() else {}
		_spawn_special_room_visuals(room, features)
		if bool(features.get("event", false)):
			_spawn_event_room(room, room_index)
		if bool(features.get("challenge", false)):
			_spawn_challenge_room(room, room_index)
		match str(room_types[room_index]):
			"treasure":
				_spawn_treasure_room(room)
			"trap":
				_spawn_trap_room(room)
			"empty":
				_spawn_empty_room(room)
			"boss":
				_spawn_boss_room_visual(room)
		if _room_has_feature(room_index, "puzzle"):
			_spawn_puzzle_room(room, room_index)
		if _room_has_feature(room_index, "safe"):
			_spawn_safe_room(room)
		if _room_has_feature(room_index, "boss_merchant"):
			_spawn_boss_merchant(room, room_index)


func _spawn_enemies() -> void:
	for child in enemy_root.get_children():
		child.queue_free()
	boss_enemy_ref = null
	boss_locked_chest = null

	if player == null or not is_instance_valid(player):
		return

	var rng := _create_rng(41)
	var config := get_floor_spawn_config(current_floor, rng)
	var rooms: Array = floor_data.get("rooms", [])
	var room_types: Array = floor_data.get("room_types", [])
	var eligible_rooms: Array[int] = []
	for room_index in range(rooms.size()):
		if room_index == int(floor_data.get("spawn_room_index", 0)) or room_index == int(floor_data.get("exit_room_index", 0)):
			continue
		var room_feature := _get_room_feature(room_index)
		if bool(room_feature.get("safe", false)) or bool(room_feature.get("challenge", false)) or bool(room_feature.get("boss_merchant", false)):
			continue
		eligible_rooms.append(room_index)
		var room: Rect2i = rooms[room_index]
		var room_type := str(room_types[room_index]) if room_index < room_types.size() else "normal"
		if room_type == "empty":
			continue
		var enemy_count := rng.randi_range(int(config["enemy_min"]), int(config["enemy_max"]))
		if room_type == "treasure":
			enemy_count = max(1, enemy_count - 2)
		elif room_type == "elite":
			enemy_count = max(2, enemy_count - 1)
		for _enemy_index in range(enemy_count):
			var enemy_scene: PackedScene = _pick_enemy_scene(current_floor, rng)
			if room_type == "elite":
				enemy_scene = BAT_SWARM_SCENE if rng.randf() <= 0.4 else SHIELD_ORC_SCENE
			_spawn_enemy_instance(enemy_scene, room, rng)

	var elite_count: int = min(int(config["elite_count"]), eligible_rooms.size())
	_shuffle_with_rng(eligible_rooms, rng)
	for elite_index in range(elite_count):
		var elite_room: Rect2i = rooms[int(eligible_rooms[elite_index])]
		var elite: Enemy = ELITE_ENEMY_SCENE.instantiate()
		elite.global_position = _random_point_in_room(elite_room, rng)
		elite.configure_for_floor(player, current_floor, loot_root)
		elite.died.connect(_on_enemy_died.bind(elite))
		enemy_root.add_child(elite)

	if _is_boss_floor():
		var boss_room_index := int(floor_data.get("boss_room_index", floor_data.get("exit_room_index", 0)))
		if boss_room_index >= 0 and boss_room_index < rooms.size():
			_spawn_boss_enemy(rooms[boss_room_index], rng)
			_spawn_boss_locked_chest(rooms[boss_room_index], rng)

	set_gameplay_paused(gameplay_paused)


func _on_enemy_died(_enemy_position: Vector2, enemy_ref) -> void:
	total_kills += 1
	kills_changed.emit(total_kills)
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		var kill_kind := "normal"
		if enemy_ref != null and enemy_ref.has_method("is_boss_enemy") and enemy_ref.is_boss_enemy():
			kill_kind = "boss"
		elif enemy_ref != null and enemy_ref.has_method("is_elite_enemy") and enemy_ref.is_elite_enemy():
			kill_kind = "elite"
		achievement_manager.record_enemy_kill(kill_kind)
	if enemy_ref != null and enemy_ref.has_method("is_boss_enemy") and enemy_ref.is_boss_enemy():
		boss_enemy_ref = null
		if boss_stairway != null and is_instance_valid(boss_stairway):
			boss_stairway.set_locked(false, LocaleManager.L("prompt_descend_floor") % (current_floor + 1))
		if boss_locked_chest != null and is_instance_valid(boss_locked_chest):
			boss_locked_chest.unlock()
		return
	if enemy_ref != null and enemy_ref.has_method("is_elite_enemy") and enemy_ref.is_elite_enemy():
		set_gameplay_paused(true)
		buff_selection_requested.emit(BUFF_SYSTEM.generate_random_buffs())


func _on_descend_requested() -> void:
	floor_transition_requested.emit(current_floor + 1)


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


func _room_center_world(room: Rect2i) -> Vector2:
	var center_tile := room.position + room.size / 2
	return Vector2(center_tile.x * 16 + 8, center_tile.y * 16 + 8)


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
	if floor_number <= 12:
		return {"enemy_min": 5, "enemy_max": 6, "allow_ranged": true, "ranged_ratio": 0.55, "elite_count": _rng_range(rng, 1, 2)}
	return {"enemy_min": 5, "enemy_max": 7, "allow_ranged": true, "ranged_ratio": 0.55, "elite_count": _rng_range(rng, 2, 3)}


func _pick_enemy_scene(floor_number: int, rng: RandomNumberGenerator) -> PackedScene:
	var roll := _rng_randf(rng)
	if floor_number >= 13:
		if roll <= 0.30:
			return SHIELD_ORC_SCENE
		if roll <= 0.55:
			return RANGED_ENEMY_SCENE
		if roll <= 0.75:
			return BAT_SWARM_SCENE
		return MELEE_ENEMY_SCENE
	if floor_number >= 9:
		if roll <= 0.50:
			return SHIELD_ORC_SCENE
		if roll <= 0.65:
			return RANGED_ENEMY_SCENE
		if roll <= 0.75:
			return BAT_SWARM_SCENE
		return MELEE_ENEMY_SCENE
	if floor_number >= 5:
		if roll <= 0.55:
			return RANGED_ENEMY_SCENE
		if roll <= 0.70:
			return BAT_SWARM_SCENE
		if roll <= 0.85:
			return SHIELD_ORC_SCENE
		return MELEE_ENEMY_SCENE
	if floor_number >= 3 and roll <= 0.20:
		return BAT_SWARM_SCENE
	return MELEE_ENEMY_SCENE


func _spawn_enemy_instance(enemy_scene: PackedScene, room: Rect2i, rng: RandomNumberGenerator) -> Array[Enemy]:
	var spawned_enemies: Array[Enemy] = []
	var enemy: Enemy = enemy_scene.instantiate()
	var min_group := int(enemy.get("group_spawn_min")) if enemy.get("group_spawn_min") != null else 1
	var max_group := int(enemy.get("group_spawn_max")) if enemy.get("group_spawn_max") != null else 1
	var group_count: int = max(1, min_group)
	if max_group > group_count:
		group_count = _rng_range(rng, min_group, max_group)
	enemy.queue_free()
	for index in range(group_count):
		var spawned_enemy: Enemy = enemy_scene.instantiate()
		var offset := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)) * float(index)
		spawned_enemy.global_position = _random_point_in_room(room, rng) + offset
		spawned_enemy.configure_for_floor(player, current_floor, loot_root)
		spawned_enemy.died.connect(_on_enemy_died.bind(spawned_enemy))
		enemy_root.add_child(spawned_enemy)
		spawned_enemies.append(spawned_enemy)
	return spawned_enemies


func _spawn_treasure_room(room: Rect2i) -> void:
	var chest_count := randi_range(1, 2)
	for _idx in range(chest_count):
		var chest = DUNGEON_CHEST_SCENE.instantiate()
		chest.global_position = _random_point_in_room(room)
		chest.setup(loot_root, current_floor)
		feature_root.add_child(chest)


func _spawn_empty_room(room: Rect2i) -> void:
	var pickup_count := randi_range(1, 3)
	var resources := ["wood", "stone", "fiber"]
	for _idx in range(pickup_count):
		var drop = LOOT_DROP_SCENE.instantiate()
		drop.setup(resources.pick_random(), 1)
		drop.global_position = _random_point_in_room(room)
		loot_root.add_child(drop)


func _spawn_trap_room(room: Rect2i) -> void:
	for _trap_index in range(randi_range(2, 4)):
		var trap = SPIKE_TRAP_SCENE.instantiate()
		trap.global_position = _random_point_in_room(room)
		feature_root.add_child(trap)


func _spawn_special_room_visuals(room: Rect2i, room_feature: Dictionary) -> void:
	var has_event := bool(room_feature.get("event", false))
	var has_challenge := bool(room_feature.get("challenge", false))
	if not has_event and not has_challenge:
		return

	var fill_color := Color(0.36, 0.14, 0.44, 0.30)
	var border_color := Color(0.78, 0.42, 0.96, 0.90)
	if has_challenge and has_event:
		fill_color = Color(0.50, 0.12, 0.22, 0.34)
		border_color = Color(0.96, 0.48, 0.74, 0.94)
	elif has_challenge:
		fill_color = Color(0.58, 0.14, 0.14, 0.32)
		border_color = Color(1.0, 0.42, 0.32, 0.95)

	_spawn_room_tint(room, fill_color, border_color)


func _spawn_room_tint(room: Rect2i, fill_color: Color, border_color: Color) -> void:
	var room_start := Vector2(room.position.x * 16, room.position.y * 16)
	var room_end := Vector2(room.end.x * 16, room.end.y * 16)

	var fill := Polygon2D.new()
	fill.z_index = -1
	fill.color = fill_color
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	feature_root.add_child(fill)

	var border := Line2D.new()
	border.z_index = -1
	border.width = 2.0
	border.default_color = border_color
	border.closed = true
	border.points = PackedVector2Array([
		room_start + Vector2(2, 2),
		Vector2(room_end.x - 2, room_start.y + 2),
		room_end - Vector2(2, 2),
		Vector2(room_start.x + 2, room_end.y - 2),
	])
	feature_root.add_child(border)


func _spawn_event_room(room: Rect2i, room_index: int) -> void:
	var event_room = EVENT_ROOM_SCRIPT.new()
	if event_room.has_method("setup"):
		event_room.setup(loot_root, current_floor, int(_create_room_rng(281, room_index).seed))
	event_room.global_position = _room_center_world(room)
	feature_root.add_child(event_room)


func _spawn_challenge_room(room: Rect2i, room_index: int) -> void:
	var challenge_room = CHALLENGE_ROOM_SCRIPT.new()
	if challenge_room.has_method("setup"):
		challenge_room.setup(self, room_index, room, _get_room_door_tiles(room))
	feature_root.add_child(challenge_room)


func spawn_challenge_room_wave(room_index: int) -> Array:
	var rooms: Array = floor_data.get("rooms", [])
	if room_index < 0 or room_index >= rooms.size():
		return []
	if player == null or not is_instance_valid(player):
		return []

	var room: Rect2i = rooms[room_index]
	var rng := _create_room_rng(337, room_index)
	var config := get_floor_spawn_config(current_floor, rng)
	var enemy_count: int = max(2, rng.randi_range(int(config["enemy_min"]), int(config["enemy_max"])) * 2)
	var spawned_enemies: Array = []
	for _enemy_index in range(enemy_count):
		var enemy_scene: PackedScene = _pick_enemy_scene(current_floor, rng)
		spawned_enemies.append_array(_spawn_enemy_instance(enemy_scene, room, rng))

	set_gameplay_paused(gameplay_paused)
	return spawned_enemies


func spawn_challenge_room_reward(room_index: int) -> void:
	var rooms: Array = floor_data.get("rooms", [])
	if room_index < 0 or room_index >= rooms.size():
		return

	var room: Rect2i = rooms[room_index]
	var center := _room_center_world(room)
	var rng := _create_room_rng(389, room_index)

	var copper_drop = LOOT_DROP_SCENE.instantiate()
	copper_drop.global_position = center + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
	copper_drop.setup("copper", rng.randi_range(18, 32) + current_floor * 3)
	loot_root.add_child(copper_drop)

	var shard_drop = LOOT_DROP_SCENE.instantiate()
	shard_drop.global_position = center + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
	shard_drop.setup("talent_shard", rng.randi_range(1, 2))
	loot_root.add_child(shard_drop)

	if rng.randf() <= 0.45:
		var equipment_drop = LOOT_DROP_SCENE.instantiate()
		equipment_drop.global_position = center + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
		equipment_drop.setup_stack(DUNGEON_LOOT.generate_dungeon_equipment(max(current_floor, 1), rng))
		loot_root.add_child(equipment_drop)


func _get_room_door_tiles(room: Rect2i) -> Array[Vector2i]:
	var door_tiles: Array[Vector2i] = []
	var floor_lookup: Dictionary = {}
	for floor_tile in floor_data.get("floor_tiles", []):
		floor_lookup[floor_tile] = true

	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var tile_pos := Vector2i(x, y)
			var is_perimeter := x == room.position.x or x == room.end.x - 1 or y == room.position.y or y == room.end.y - 1
			if not is_perimeter:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = tile_pos + Vector2i(offset)
				if _is_tile_inside_room(neighbor, room):
					continue
				if floor_lookup.has(neighbor):
					door_tiles.append(tile_pos)
					break
	return door_tiles


func _is_tile_inside_room(tile_pos: Vector2i, room: Rect2i) -> bool:
	return tile_pos.x >= room.position.x and tile_pos.x < room.end.x and tile_pos.y >= room.position.y and tile_pos.y < room.end.y


func _spawn_puzzle_room(room: Rect2i, room_index: int) -> void:
	var puzzle_room = PUZZLE_ROOM_SCRIPT.new()
	if puzzle_room.has_method("setup"):
		puzzle_room.setup(room, loot_root, current_floor, _create_room_rng(137, room_index))
	feature_root.add_child(puzzle_room)


func _spawn_safe_room(room: Rect2i) -> void:
	var safe_room = SAFE_ROOM_SCRIPT.new()
	if safe_room.has_method("setup"):
		safe_room.setup(room)
	feature_root.add_child(safe_room)


func _spawn_boss_merchant(room: Rect2i, room_index: int) -> void:
	var merchant = DUNGEON_MERCHANT_SCRIPT.new()
	if merchant.has_method("setup"):
		merchant.setup(current_floor, _create_room_rng(211, room_index))
	merchant.position = _room_center_world(room)
	feature_root.add_child(merchant)


func _spawn_boss_room_visual(room: Rect2i) -> void:
	var room_start := Vector2(room.position.x * 16, room.position.y * 16)
	var room_end := Vector2(room.end.x * 16, room.end.y * 16)

	var fill := Polygon2D.new()
	fill.color = Color(0.55, 0.12, 0.12, 0.22)
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	feature_root.add_child(fill)

	var border := Line2D.new()
	border.width = 3.0
	border.default_color = Color(1.0, 0.42, 0.18, 0.95)
	border.closed = true
	border.points = PackedVector2Array([
		room_start + Vector2(2, 2),
		Vector2(room_end.x - 2, room_start.y + 2),
		room_end - Vector2(2, 2),
		Vector2(room_start.x + 2, room_end.y - 2),
	])
	feature_root.add_child(border)


func _spawn_boss_enemy(room: Rect2i, rng: RandomNumberGenerator) -> void:
	var boss = BOSS_ENEMY_SCENE.instantiate()
	boss.global_position = _random_point_in_room(room, rng)
	boss.configure_for_floor(player, current_floor, loot_root)
	boss.died.connect(_on_enemy_died.bind(boss))
	enemy_root.add_child(boss)
	boss_enemy_ref = boss


func _spawn_boss_locked_chest(room: Rect2i, rng: RandomNumberGenerator) -> void:
	var chest = LOCKED_CHEST_SCENE.instantiate()
	chest.global_position = _random_edge_point_in_room(room, rng)
	chest.setup(loot_root, current_floor)
	feature_root.add_child(chest)
	boss_locked_chest = chest


func set_gameplay_paused(paused: bool) -> void:
	gameplay_paused = paused
	for enemy in enemy_root.get_children():
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(paused)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT


func get_minimap_snapshot() -> Dictionary:
	var enemy_positions: Array[Vector2] = []
	var chest_positions: Array[Vector2] = []
	for enemy in enemy_root.get_children():
		enemy_positions.append(enemy.global_position)
	if treasure_reveal_time_left > 0.0:
		for child in feature_root.get_children():
			if child is DungeonChest:
				chest_positions.append(child.global_position)
	return {
		"map_size": DUNGEON_GENERATOR.MAP_SIZE,
		"floor_tiles": floor_data.get("floor_tiles", []),
		"enemy_positions": enemy_positions,
		"chest_positions": chest_positions,
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


func _create_room_rng(offset: int, room_index: int) -> RandomNumberGenerator:
	return _create_rng(offset + room_index * 37)


func _shuffle_with_rng(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current_value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = current_value


func _get_room_feature(room_index: int) -> Dictionary:
	var room_features: Array = floor_data.get("room_features", [])
	if room_index < 0 or room_index >= room_features.size():
		return {}
	return room_features[room_index] as Dictionary


func _room_has_feature(room_index: int, feature_name: String) -> bool:
	return bool(_get_room_feature(room_index).get(feature_name, false))


func reveal_treasure_hunter(duration: float) -> void:
	treasure_reveal_time_left = max(treasure_reveal_time_left, duration)


func _is_boss_floor() -> bool:
	return bool(floor_data.get("is_boss_floor", false))
