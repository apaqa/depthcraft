extends Node2D

signal floor_changed(current_floor: int)
signal kills_changed(total_kills: int)
signal return_to_surface_requested
signal buff_selection_requested(options: Array)
signal floor_transition_requested(next_floor: int)
signal victory_requested

const SOURCE_FLOOR_1: int = 0
const SOURCE_FLOOR_2: int = 1
const SOURCE_FLOOR_3: int = 2
const SOURCE_TOP_LEFT: int = 100
const SOURCE_TOP_MID: int = 101
const SOURCE_TOP_RIGHT: int = 102
const SOURCE_WALL_LEFT: int = 103
const SOURCE_WALL_RIGHT: int = 104
const SOURCE_WALL_MID: int = 105

const DUNGEON_GENERATOR: Script = preload("res://scripts/dungeon/dungeon_generator.gd")
const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")
const STAIRWAY_SCENE: PackedScene = preload("res://scenes/dungeon/stairway.tscn")
const MELEE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")
const SHIELD_ORC_SCENE: PackedScene = preload("res://scenes/enemies/shield_orc_enemy.tscn")
const BAT_SWARM_SCENE: PackedScene = preload("res://scenes/enemies/bat_swarm_enemy.tscn")
const SLIME_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const SHADOW_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/shadow_enemy.tscn")
const GARGOYLE_SCENE: PackedScene = preload("res://scenes/enemies/gargoyle_enemy.tscn")
const MIMIC_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/mimic_enemy.tscn")
const ELITE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/elite_enemy.tscn")
const BOSS_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")
const NECROMANCER_BOSS_SCENE: PackedScene = preload("res://scenes/enemies/necromancer_boss.tscn")
const LAVA_GIANT_BOSS_SCENE: PackedScene = preload("res://scenes/enemies/lava_giant_boss.tscn")
const ABYSS_EYE_BOSS_SCENE: PackedScene = preload("res://scenes/enemies/abyss_eye_boss.tscn")
const DUNGEON_CHEST_SCENE: PackedScene = preload("res://scenes/dungeon/dungeon_chest.tscn")
const LOCKED_CHEST_SCENE: PackedScene = preload("res://scenes/dungeon/locked_chest.tscn")
const SPIKE_TRAP_SCENE: PackedScene = preload("res://scenes/dungeon/spike_trap.tscn")
const LOOT_DROP_SCENE: PackedScene = preload("res://scenes/dungeon/loot_drop.tscn")
const EVENT_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/event_room.gd")
const CHALLENGE_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/challenge_room.gd")
const PUZZLE_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/puzzle_room.gd")
const SAFE_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/safe_room.gd")
const DUNGEON_MERCHANT_SCRIPT: Script = preload("res://scripts/dungeon/dungeon_merchant.gd")
const WISHING_WELL_SCRIPT: Script = preload("res://scripts/dungeon/wishing_well.gd")
const DEMON_MERCHANT_SCRIPT: Script = preload("res://scripts/dungeon/demon_merchant.gd")
const TIMED_TREASURE_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/timed_treasure_room.gd")
const SECRET_MERCHANT_SCRIPT: Script = preload("res://scripts/dungeon/secret_merchant.gd")
const ARROW_TRAP_LAUNCHER_SCRIPT: Script = preload("res://scripts/dungeon/arrow_trap_launcher.gd")
const MONSTER_PREFIX: Script = preload("res://scripts/enemies/monster_prefix.gd")

@export var current_floor: int = 1
@export var level_seed: int = 1

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var wall_tile_map_layer: TileMapLayer = $WallTileMapLayer
@onready var wall_collision_root: Node2D = $WallCollisionRoot
@onready var feature_root: Node2D = $FeatureRoot
@onready var enemy_root: Node2D = $EnemyRoot
@onready var loot_root: Node2D = $LootRoot

var player = null
var fog_tile_map_layer: TileMapLayer = null
var floor_data: Dictionary = {}
var total_kills: int = 0
var elites_killed_this_floor: int = 0
var gameplay_paused: bool = false
var treasure_reveal_time_left: float = 0.0
var boss_stairway = null
var boss_enemy_ref = null
var boss_locked_chest = null
var explored_rooms: Array[int] = []
var revealed_tiles: Dictionary = {}
var _last_track_tile: Vector2i = Vector2i(-99999, -99999)
var _boss_door_locked: bool = false
var _boss_door_tiles: Array[Vector2i] = []
var _boss_door_blockers: Array[Node] = []
var _decoration_texture_cache: Dictionary = {}
var _decoration_frames_cache: Dictionary = {}
var _room_decoration_root: Node2D = null


func _ready() -> void:
	_ensure_fog_layer()
	_generate_floor()
	set_process(true)


func _process(delta: float) -> void:
	if treasure_reveal_time_left > 0.0:
		treasure_reveal_time_left = max(treasure_reveal_time_left - delta, 0.0)
	_track_explored_room()


func _track_explored_room() -> void:
	if player == null or not is_instance_valid(player):
		return
	var rooms: Array = floor_data.get("rooms", [])
	var player_tile: Vector2i = Vector2i(
		floori(player.global_position.x / 16.0),
		floori(player.global_position.y / 16.0)
	)
	if player_tile != _last_track_tile:
		_last_track_tile = player_tile
		_reveal_tile_radius(player_tile, 3)
	for room_index: int in range(rooms.size()):
		var room: Rect2i = rooms[room_index] as Rect2i
		if not room.has_point(player_tile):
			continue
		_reveal_room(room)
		if not explored_rooms.has(room_index):
			explored_rooms.append(room_index)
			_on_room_entered(room_index)
		break


func _on_room_entered(room_index: int) -> void:
	var boss_room_index: int = int(floor_data.get("boss_room_index", -1))
	if boss_room_index < 0 or room_index != boss_room_index:
		return
	if boss_enemy_ref != null and is_instance_valid(boss_enemy_ref) and not _boss_door_locked:
		call_deferred("_lock_boss_door")


func place_player(new_player: Node2D, spawn_override: Variant = null) -> void:
	player = new_player
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = get_spawn_position(spawn_override)
	if player.has_signal("safe_return_requested") and not player.safe_return_requested.is_connected(_on_return_surface_requested):
		player.safe_return_requested.connect(_on_return_surface_requested)
	_update_player_ambient_light()
	_spawn_enemies()
	_track_explored_room()


func descend_floor() -> void:
	current_floor += 1
	_generate_floor()
	if player != null and is_instance_valid(player):
		player.global_position = floor_data.get("spawn_point", Vector2.ZERO)
		_track_explored_room()


func _generate_floor() -> void:
	var generator: RefCounted = DUNGEON_GENERATOR.new()
	floor_data = generator.generate_floor(current_floor, _create_rng(17))
	boss_stairway = null
	boss_enemy_ref = null
	boss_locked_chest = null
	_boss_door_locked = false
	_boss_door_tiles.clear()
	_boss_door_blockers.clear()
	explored_rooms.clear()
	revealed_tiles.clear()
	elites_killed_this_floor = 0
	_draw_floor()
	_spawn_features()
	_spawn_enemies()
	floor_changed.emit(current_floor)
	QuestManager.update_quest_progress("reach_floor", "", current_floor)
	kills_changed.emit(total_kills)


func _draw_floor() -> void:
	_ensure_fog_layer()
	tile_map_layer.clear()
	wall_tile_map_layer.clear()
	fog_tile_map_layer.clear()
	for child in wall_collision_root.get_children():
		child.queue_free()
	var all_floor_tiles: Array = floor_data.get("floor_tiles", [])
	var all_wall_tiles: Array = floor_data.get("wall_tiles", [])
	for floor_tile: Vector2i in all_floor_tiles:
		tile_map_layer.set_cell(floor_tile, _get_floor_source(floor_tile), Vector2i.ZERO)
	for wall_tile: Vector2i in all_wall_tiles:
		wall_tile_map_layer.set_cell(wall_tile, _get_wall_source(wall_tile), Vector2i.ZERO)
		_spawn_wall_blocker(wall_tile)
	tile_map_layer.update_internals()
	wall_tile_map_layer.update_internals()
	# Fill full bounding box (+ 10 tile margin) with fog to cover empty spaces
	if not all_floor_tiles.is_empty() or not all_wall_tiles.is_empty():
		var fog_min_x: int = 999999
		var fog_min_y: int = 999999
		var fog_max_x: int = -999999
		var fog_max_y: int = -999999
		for t: Vector2i in all_floor_tiles:
			fog_min_x = mini(fog_min_x, t.x)
			fog_min_y = mini(fog_min_y, t.y)
			fog_max_x = maxi(fog_max_x, t.x)
			fog_max_y = maxi(fog_max_y, t.y)
		for t: Vector2i in all_wall_tiles:
			fog_min_x = mini(fog_min_x, t.x)
			fog_min_y = mini(fog_min_y, t.y)
			fog_max_x = maxi(fog_max_x, t.x)
			fog_max_y = maxi(fog_max_y, t.y)
		var fog_expand: int = 10
		var fog_source_id: int = _get_floor_source(Vector2i.ZERO)
		for fy: int in range(fog_min_y - fog_expand, fog_max_y + fog_expand + 1):
			for fx: int in range(fog_min_x - fog_expand, fog_max_x + fog_expand + 1):
				fog_tile_map_layer.set_cell(Vector2i(fx, fy), fog_source_id, Vector2i.ZERO)
	fog_tile_map_layer.update_internals()
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
		var gradient: Gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var grad_tex: GradientTexture2D = GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.width = 128
		grad_tex.height = 128
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		var light: PointLight2D = PointLight2D.new()
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
	var spawned_wishing_well: bool = false
	var spawned_demon_merchant: bool = false
	for room_index: int in range(rooms.size()):
		if room_index >= room_types.size():
			continue
		var room: Rect2i = rooms[room_index]
		var features: Dictionary = room_features[room_index] if room_index < room_features.size() else {}
		var room_type: String = str(room_types[room_index])
		_spawn_special_room_visuals(room, features)
		if bool(features.get("event", false)):
			_spawn_event_room(room, room_index)
		if bool(features.get("challenge", false)):
			_spawn_challenge_room(room, room_index)
		match room_type:
			"treasure":
				_spawn_treasure_room(room, room_index)
			"trap":
				_spawn_trap_room(room)
			"empty":
				_spawn_empty_room(room)
			"secret_merchant":
				_spawn_secret_merchant_room(room, room_index)
			"boss":
				_spawn_boss_room_visual(room)
		if _room_has_feature(room_index, "puzzle"):
			_spawn_puzzle_room(room, room_index)
		if _room_has_feature(room_index, "safe"):
			_spawn_safe_room(room)
		if _room_has_feature(room_index, "boss_merchant"):
			_spawn_boss_merchant(room, room_index)
		if not spawned_wishing_well:
			spawned_wishing_well = _try_spawn_wishing_well(room, room_index)
		if not spawned_demon_merchant:
			spawned_demon_merchant = _try_spawn_demon_merchant(room, room_index, room_type, features)
	_spawn_corridor_features()


func _spawn_enemies() -> void:
	for child in enemy_root.get_children():
		child.queue_free()
	boss_enemy_ref = null
	boss_locked_chest = null

	if player == null or not is_instance_valid(player):
		return

	var rng: RandomNumberGenerator = _create_rng(41)
	var config: Dictionary = get_floor_spawn_config(current_floor, rng)
	var rooms: Array = floor_data.get("rooms", [])
	var room_types: Array = floor_data.get("room_types", [])
	var eligible_rooms: Array[int] = []
	for room_index in range(rooms.size()):
		if room_index == int(floor_data.get("spawn_room_index", 0)) or room_index == int(floor_data.get("exit_room_index", 0)):
			continue
		var room_type: String = str(room_types[room_index]) if room_index < room_types.size() else "normal"
		var room_feature: Dictionary = _get_room_feature(room_index)
		if bool(room_feature.get("safe", false)) or bool(room_feature.get("challenge", false)) or bool(room_feature.get("boss_merchant", false)) or room_type == "secret_merchant":
			continue
		eligible_rooms.append(room_index)
		var room: Rect2i = rooms[room_index]
		if room_type == "empty":
			continue
		var enemy_count: int = rng.randi_range(int(config["enemy_min"]), int(config["enemy_max"]))
		if room_type == "treasure":
			enemy_count = max(1, enemy_count - 3)
		elif room_type == "elite":
			enemy_count = max(2, enemy_count - 1)
		for _enemy_index in range(enemy_count):
			var enemy_scene: PackedScene = _pick_enemy_scene(current_floor, rng)
			if room_type == "elite":
				if current_floor >= 21:
					enemy_scene = GARGOYLE_SCENE if rng.randf() <= 0.7 else SHIELD_ORC_SCENE
				elif current_floor >= 11:
					enemy_scene = SHADOW_ENEMY_SCENE if rng.randf() <= 0.65 else RANGED_ENEMY_SCENE
				else:
					enemy_scene = SLIME_ENEMY_SCENE if rng.randf() <= 0.6 else BAT_SWARM_SCENE
			_spawn_enemy_instance(enemy_scene, room, rng)

	var elite_count: int = min(int(config["elite_count"]), eligible_rooms.size())
	_shuffle_with_rng(eligible_rooms, rng)
	for elite_index in range(elite_count):
		var elite_room: Rect2i = rooms[int(eligible_rooms[elite_index])]
		var elite: Enemy = ELITE_ENEMY_SCENE.instantiate()
		elite.global_position = _random_point_in_room(elite_room, rng)
		elite.configure_for_floor(player, current_floor, loot_root)
		_apply_floor_scaling(elite, 1.4, 1.25, 1.08 if current_floor >= 31 else 1.0)
		_maybe_apply_prefixes(elite, true, rng)
		elite.died.connect(_on_enemy_died.bind(elite))
		enemy_root.add_child(elite)

	if _is_boss_floor():
		var boss_room_index: int = int(floor_data.get("boss_room_index", floor_data.get("exit_room_index", 0)))
		if boss_room_index >= 0 and boss_room_index < rooms.size():
			_spawn_boss_enemy(rooms[boss_room_index], rng)
			_spawn_boss_locked_chest(rooms[boss_room_index], rng)

	_spawn_room_decorations_for_all_rooms()
	set_gameplay_paused(gameplay_paused)


func _on_enemy_died(_enemy_position: Vector2, enemy_ref) -> void:
	total_kills += 1
	kills_changed.emit(total_kills)
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		var kill_kind: String = "normal"
		if enemy_ref != null and enemy_ref.has_method("is_boss_enemy") and enemy_ref.is_boss_enemy():
			kill_kind = "boss"
		elif enemy_ref != null and enemy_ref.has_method("is_elite_enemy") and enemy_ref.is_elite_enemy():
			kill_kind = "elite"
		achievement_manager.record_enemy_kill(kill_kind)
	if enemy_ref != null and enemy_ref.has_method("is_boss_enemy") and enemy_ref.is_boss_enemy():
		boss_enemy_ref = null
		_unlock_boss_door()
		if current_floor >= 30:
			victory_requested.emit()
			return
		if boss_stairway != null and is_instance_valid(boss_stairway):
			boss_stairway.set_locked(false, LocaleManager.L("prompt_descend_floor") % (current_floor + 1))
		if boss_locked_chest != null and is_instance_valid(boss_locked_chest):
			boss_locked_chest.unlock()
		return
	if enemy_ref != null and enemy_ref.has_method("is_elite_enemy") and enemy_ref.is_elite_enemy():
		elites_killed_this_floor += 1
		_apply_elite_chain_enhancement()
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
	var center_tile: Vector2i = room.position + room.size / 2
	return Vector2(center_tile.x * 16 + 8, center_tile.y * 16 + 8)


func _random_edge_point_in_room(room: Rect2i, rng: RandomNumberGenerator = null) -> Vector2:
	var side: int = _rng_range(rng, 0, 3)
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


func _make_wall_blocker(tile_pos: Vector2i) -> StaticBody2D:
	var blocker: StaticBody2D = StaticBody2D.new()
	blocker.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(17, 17)
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _spawn_wall_blocker(tile_pos: Vector2i) -> void:
	wall_collision_root.add_child(_make_wall_blocker(tile_pos))


func _lock_boss_door() -> void:
	var boss_room_index: int = int(floor_data.get("boss_room_index", -1))
	var rooms: Array = floor_data.get("rooms", [])
	if boss_room_index < 0 or boss_room_index >= rooms.size():
		return
	_boss_door_locked = true
	var boss_room: Rect2i = rooms[boss_room_index] as Rect2i
	var door_tiles: Array[Vector2i] = _get_room_door_tiles(boss_room)
	_boss_door_tiles.clear()
	_boss_door_blockers.clear()
	for door_tile: Vector2i in door_tiles:
		tile_map_layer.erase_cell(door_tile)
		wall_tile_map_layer.set_cell(door_tile, _get_wall_source(door_tile), Vector2i.ZERO)
		var blocker: StaticBody2D = _make_wall_blocker(door_tile)
		wall_collision_root.add_child(blocker)
		_boss_door_tiles.append(door_tile)
		_boss_door_blockers.append(blocker)
	tile_map_layer.update_internals()
	wall_tile_map_layer.update_internals()


func _unlock_boss_door() -> void:
	for door_tile: Vector2i in _boss_door_tiles:
		wall_tile_map_layer.erase_cell(door_tile)
		tile_map_layer.set_cell(door_tile, _get_floor_source(door_tile), Vector2i.ZERO)
	tile_map_layer.update_internals()
	wall_tile_map_layer.update_internals()
	for blocker: Node in _boss_door_blockers:
		if is_instance_valid(blocker):
			blocker.queue_free()
	_boss_door_tiles.clear()
	_boss_door_blockers.clear()


func _roll_elite_count(rng: RandomNumberGenerator, guaranteed: int) -> int:
	var count: int = guaranteed
	# Extra elites: 2nd=30%, 3rd=15%, 4th+=5%
	if _rng_randf(rng) < 0.30:
		count += 1
	if count >= 2 and _rng_randf(rng) < 0.15:
		count += 1
	if count >= 3 and _rng_randf(rng) < 0.05:
		count += 1
	return count


func _apply_elite_chain_enhancement() -> void:
	if elites_killed_this_floor <= 0:
		return
	var boost_mult: float = 1.0 + float(elites_killed_this_floor) * 0.1
	var remaining_count: int = 0
	for child: Node in enemy_root.get_children():
		if child.has_method("is_elite_enemy") and child.is_elite_enemy() and child.has_method("apply_chain_enhancement"):
			child.apply_chain_enhancement(boost_mult)
			remaining_count += 1
	if remaining_count > 0 and player != null and player.has_method("status_message_requested"):
		player.status_message_requested.emit(LocaleManager.L("elite_chain_enhanced"), Color(1.0, 0.4, 0.1, 1.0), 2.5)


func get_floor_spawn_config(floor_number: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if floor_number <= 2:
		return {"enemy_min": 2, "enemy_max": 3, "allow_ranged": false, "ranged_ratio": 0.0, "elite_count": 0}
	if floor_number <= 5:
		var ec_early: int = 1 if _rng_randf(rng) <= 0.5 else 0
		return {"enemy_min": 3, "enemy_max": 4, "allow_ranged": true, "ranged_ratio": 0.3, "elite_count": ec_early}
	if floor_number <= 10:
		return {"enemy_min": 4, "enemy_max": 5, "allow_ranged": true, "ranged_ratio": 0.45, "elite_count": _roll_elite_count(rng, 1)}
	if floor_number <= 20:
		return {"enemy_min": 4, "enemy_max": 6, "allow_ranged": true, "ranged_ratio": 0.6, "elite_count": _roll_elite_count(rng, 1)}
	if floor_number <= 30:
		return {"enemy_min": 5, "enemy_max": 7, "allow_ranged": true, "ranged_ratio": 0.65, "elite_count": _roll_elite_count(rng, 2)}
	return {"enemy_min": 6, "enemy_max": 8, "allow_ranged": true, "ranged_ratio": 0.7, "elite_count": _roll_elite_count(rng, 3)}


func _pick_enemy_scene(floor_number: int, rng: RandomNumberGenerator) -> PackedScene:
	var roll: float = _rng_randf(rng)
	if floor_number >= 31:
		if roll <= 0.16:
			return RANGED_ENEMY_SCENE
		if roll <= 0.34:
			return SHIELD_ORC_SCENE
		if roll <= 0.54:
			return BAT_SWARM_SCENE
		if roll <= 0.76:
			return GARGOYLE_SCENE
		return GARGOYLE_SCENE
	if floor_number >= 21:
		if roll <= 0.22:
			return RANGED_ENEMY_SCENE
		if roll <= 0.48:
			return SHIELD_ORC_SCENE
		if roll <= 0.7:
			return BAT_SWARM_SCENE
		return GARGOYLE_SCENE
	if floor_number >= 11:
		if roll <= 0.32:
			return RANGED_ENEMY_SCENE
		if roll <= 0.58:
			return SHIELD_ORC_SCENE
		if roll <= 0.8:
			return BAT_SWARM_SCENE
		return SHADOW_ENEMY_SCENE
	if floor_number >= 6:
		if roll <= 0.26:
			return MELEE_ENEMY_SCENE
		if roll <= 0.5:
			return SLIME_ENEMY_SCENE
		if roll <= 0.74:
			return RANGED_ENEMY_SCENE
		return BAT_SWARM_SCENE
	if roll <= 0.42:
		return MELEE_ENEMY_SCENE
	if roll <= 0.74:
		return SLIME_ENEMY_SCENE
	return BAT_SWARM_SCENE


func _spawn_enemy_instance(enemy_scene: PackedScene, room: Rect2i, rng: RandomNumberGenerator) -> Array[Enemy]:
	var spawned_enemies: Array[Enemy] = []
	var enemy: Enemy = enemy_scene.instantiate()
	var min_group: int = int(enemy.get("group_spawn_min")) if enemy.get("group_spawn_min") != null else 1
	var max_group: int = int(enemy.get("group_spawn_max")) if enemy.get("group_spawn_max") != null else 1
	var group_count: int = max(1, min_group)
	if max_group > group_count:
		group_count = _rng_range(rng, min_group, max_group)
	enemy.queue_free()
	for index in range(group_count):
		var spawned_enemy: Enemy = enemy_scene.instantiate()
		var offset: Vector2 = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)) * float(index)
		spawned_enemy.global_position = _random_point_in_room(room, rng) + offset
		spawned_enemy.configure_for_floor(player, current_floor, loot_root)
		_apply_floor_scaling(spawned_enemy, 1.4, 1.25, 1.12 if current_floor >= 31 else 1.0)
		_maybe_apply_prefixes(spawned_enemy, false, rng)
		spawned_enemy.died.connect(_on_enemy_died.bind(spawned_enemy))
		enemy_root.add_child(spawned_enemy)
		spawned_enemies.append(spawned_enemy)
	return spawned_enemies


func _maybe_apply_prefixes(enemy: Enemy, is_elite_or_boss: bool, rng: RandomNumberGenerator) -> void:
	if not enemy.has_method("apply_prefixes"):
		return
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle: int = 1
	if cycle_manager != null:
		cycle = int(cycle_manager.current_cycle)
	var prefix_count: int = 0
	if is_elite_or_boss:
		prefix_count = 1
		if cycle >= 3:
			prefix_count = 2
	else:
		# Normal enemies: cycle 2=20% chance 1 prefix, cycle 3+=40% one 10% two
		var roll: float = _rng_randf(rng)
		if cycle >= 3:
			if roll < 0.10:
				prefix_count = 2
			elif roll < 0.40:
				prefix_count = 1
		elif cycle >= 2:
			if roll < 0.20:
				prefix_count = 1
	if prefix_count <= 0:
		return
	var chosen: Array[String] = MONSTER_PREFIX.pick_random_prefixes(prefix_count, rng)
	enemy.apply_prefixes(chosen)


func _spawn_treasure_room(room: Rect2i, room_index: int = -1) -> void:
	var chest_count: int = randi_range(3, 5)
	var chest_modulate: Color = _get_chest_modulate(current_floor)
	for _idx in range(chest_count):
		var spawn_mimic: bool = randf() <= 0.05
		if spawn_mimic:
			var mimic: Enemy = MIMIC_ENEMY_SCENE.instantiate() as Enemy
			mimic.global_position = _random_point_in_room(room)
			mimic.configure_for_floor(player, current_floor, loot_root)
			mimic.modulate = chest_modulate
			mimic.died.connect(_on_enemy_died.bind(mimic))
			enemy_root.add_child(mimic)
		else:
			var chest: DungeonChest = DUNGEON_CHEST_SCENE.instantiate() as DungeonChest
			chest.global_position = _random_point_in_room(room)
			chest.setup(loot_root, current_floor)
			chest.modulate = chest_modulate
			feature_root.add_child(chest)
	if room_index >= 0:
		var treasure_timer: Node = TIMED_TREASURE_ROOM_SCRIPT.new()
		if treasure_timer.has_method("setup"):
			treasure_timer.setup(room, _get_room_door_tiles(room))
		feature_root.add_child(treasure_timer)


func _spawn_secret_merchant_room(room: Rect2i, room_index: int) -> void:
	_spawn_room_tint(room, Color(0.12, 0.26, 0.36, 0.22), Color(0.52, 0.84, 1.0, 0.88))
	var merchant: Node2D = SECRET_MERCHANT_SCRIPT.new() as Node2D
	if merchant == null:
		return
	if merchant.has_method("setup"):
		merchant.setup(current_floor + 2, _create_room_rng(251, room_index))
	merchant.position = _room_center_world(room)
	feature_root.add_child(merchant)


func _spawn_empty_room(room: Rect2i) -> void:
	var pickup_count: int = randi_range(1, 3)
	var resources: Array[String] = ["wood", "stone", "fiber"]
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
	var has_event: bool = bool(room_feature.get("event", false))
	var has_challenge: bool = bool(room_feature.get("challenge", false))
	if not has_event and not has_challenge:
		return

	var fill_color: Color = Color(0.36, 0.14, 0.44, 0.30)
	var border_color: Color = Color(0.78, 0.42, 0.96, 0.90)
	if has_challenge and has_event:
		fill_color = Color(0.50, 0.12, 0.22, 0.34)
		border_color = Color(0.96, 0.48, 0.74, 0.94)
	elif has_challenge:
		fill_color = Color(0.58, 0.14, 0.14, 0.32)
		border_color = Color(1.0, 0.42, 0.32, 0.95)

	_spawn_room_tint(room, fill_color, border_color)


func _spawn_room_tint(room: Rect2i, fill_color: Color, border_color: Color) -> void:
	var room_start: Vector2 = Vector2(room.position.x * 16, room.position.y * 16)
	var room_end: Vector2 = Vector2(room.end.x * 16, room.end.y * 16)

	var fill: Polygon2D = Polygon2D.new()
	fill.z_index = -1
	fill.color = fill_color
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	feature_root.add_child(fill)

	var border: Line2D = Line2D.new()
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
	var rng: RandomNumberGenerator = _create_room_rng(337, room_index)
	var config: Dictionary = get_floor_spawn_config(current_floor, rng)
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
	var center: Vector2 = _room_center_world(room)
	var rng: RandomNumberGenerator = _create_room_rng(389, room_index)

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
			var tile_pos: Vector2i = Vector2i(x, y)
			var is_perimeter: bool = x == room.position.x or x == room.end.x - 1 or y == room.position.y or y == room.end.y - 1
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


func _spawn_room_decorations_for_all_rooms() -> void:
	if _room_decoration_root == null or not is_instance_valid(_room_decoration_root):
		_room_decoration_root = Node2D.new()
		_room_decoration_root.name = "RoomDecorationRoot"
		feature_root.add_child(_room_decoration_root)
	for child: Node in _room_decoration_root.get_children():
		child.queue_free()
	var rooms: Array = floor_data.get("rooms", [])
	for room_index: int in range(rooms.size()):
		var room: Rect2i = rooms[room_index] as Rect2i
		_spawn_room_decorations(room, room_index)


func _spawn_room_decorations(room: Rect2i, room_index: int) -> void:
	if _room_decoration_root == null or not is_instance_valid(_room_decoration_root):
		return
	var decoration_rng: RandomNumberGenerator = _create_room_rng(463, room_index)
	var room_node: Node2D = Node2D.new()
	room_node.name = "RoomDecorations_%d" % room_index
	_room_decoration_root.add_child(room_node)
	var wall_sides: PackedStringArray = PackedStringArray(["top", "bottom", "left", "right"])
	if current_floor >= 31:
		for side_name: String in wall_sides:
			_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.15, PackedStringArray(["res://assets/wall_gargoyle_blue_1.png"]))
			_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.20, PackedStringArray(["res://assets/wall_banner_blue.png"]))
		_spawn_corner_decorations(room_node, room, decoration_rng, "res://assets/column_wall.png", 0.30)
		return
	if current_floor >= 21:
		for side_name: String in wall_sides:
			_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.15, PackedStringArray(["res://assets/wall_gargoyle_red_1.png"]))
			_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.20, PackedStringArray(["res://assets/wall_banner_red.png"]))
		if decoration_rng.randf() <= 0.10:
			_add_static_room_decoration(room_node, "res://assets/floor_gargoyle_red_basin.png", _room_center_world(room))
		return
	if current_floor >= 11:
		for side_name: String in wall_sides:
			if decoration_rng.randf() <= 0.25:
				var goo_position: Vector2 = _random_wall_decoration_point(room, decoration_rng, side_name)
				_add_static_room_decoration(room_node, "res://assets/wall_goo_base.png", goo_position + Vector2(0.0, 6.0))
				_add_static_room_decoration(room_node, "res://assets/wall_goo.png", goo_position)
			_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.10, PackedStringArray([
				"res://assets/wall_banner_red.png",
				"res://assets/wall_banner_green.png",
			]))
		_spawn_floor_skulls(room_node, room, decoration_rng)
		return
	for side_name: String in wall_sides:
		_maybe_spawn_wall_decoration(room_node, room, decoration_rng, side_name, 0.20, PackedStringArray([
			"res://assets/wall_hole_1.png",
			"res://assets/wall_hole_2.png",
		]))
		if decoration_rng.randf() <= 0.40:
			_add_torch_room_decoration(room_node, _random_wall_decoration_point(room, decoration_rng, side_name))
	_spawn_corner_decorations(room_node, room, decoration_rng, "res://assets/column.png", 0.30)


func _maybe_spawn_wall_decoration(room_node: Node2D, room: Rect2i, rng: RandomNumberGenerator, side_name: String, chance: float, texture_paths: PackedStringArray) -> void:
	if rng.randf() > chance or texture_paths.is_empty():
		return
	var texture_path: String = texture_paths[rng.randi_range(0, texture_paths.size() - 1)]
	var world_position: Vector2 = _random_wall_decoration_point(room, rng, side_name)
	_add_static_room_decoration(room_node, texture_path, world_position)


func _spawn_corner_decorations(room_node: Node2D, room: Rect2i, rng: RandomNumberGenerator, texture_path: String, chance: float) -> void:
	for corner_index: int in range(4):
		if rng.randf() > chance:
			continue
		_add_static_room_decoration(room_node, texture_path, _get_room_anchor_world(room, corner_index))


func _spawn_floor_skulls(room_node: Node2D, room: Rect2i, rng: RandomNumberGenerator) -> void:
	var placed_count: int = 0
	for tile_y: int in range(room.position.y + 1, room.end.y - 1):
		for tile_x: int in range(room.position.x + 1, room.end.x - 1):
			if placed_count >= 3:
				return
			if rng.randf() > 0.05:
				continue
			var skull_position: Vector2 = Vector2(tile_x * 16 + 8, tile_y * 16 + 8)
			_add_static_room_decoration(
				room_node,
				"res://assets/skull.png",
				skull_position + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
				rng.randf_range(-15.0, 15.0)
			)
			placed_count += 1


func _add_torch_room_decoration(room_node: Node2D, world_position: Vector2) -> void:
	var frame_paths: PackedStringArray = PackedStringArray([
		"res://assets/torch_1.png",
		"res://assets/torch_2.png",
		"res://assets/torch_3.png",
		"res://assets/torch_4.png",
		"res://assets/torch_5.png",
		"res://assets/torch_6.png",
		"res://assets/torch_7.png",
		"res://assets/torch_8.png",
	])
	var frames: SpriteFrames = _get_or_build_decoration_frames("stone_wall_torch", frame_paths, 8.0)
	if frames.get_frame_count("default") <= 0:
		return
	var torch_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	torch_sprite.position = world_position
	torch_sprite.z_index = -1
	torch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	torch_sprite.sprite_frames = frames
	torch_sprite.animation = &"default"
	torch_sprite.play()
	room_node.add_child(torch_sprite)


func _add_static_room_decoration(room_node: Node2D, texture_path: String, world_position: Vector2, rotation_degrees: float = 0.0) -> void:
	var texture: Texture2D = _load_decoration_texture(texture_path)
	if texture == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.position = world_position
	sprite.rotation_degrees = rotation_degrees
	sprite.z_index = -1
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_node.add_child(sprite)


func _load_decoration_texture(texture_path: String) -> Texture2D:
	var cached_texture: Variant = _decoration_texture_cache.get(texture_path, null)
	if cached_texture is Texture2D:
		return cached_texture as Texture2D
	var loaded_texture: Texture2D = load(texture_path) as Texture2D
	if loaded_texture != null:
		_decoration_texture_cache[texture_path] = loaded_texture
	return loaded_texture


func _get_or_build_decoration_frames(cache_key: String, frame_paths: PackedStringArray, animation_speed: float) -> SpriteFrames:
	var cached_frames: Variant = _decoration_frames_cache.get(cache_key, null)
	if cached_frames is SpriteFrames:
		return cached_frames as SpriteFrames
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", animation_speed)
	for frame_path: String in frame_paths:
		var texture: Texture2D = _load_decoration_texture(frame_path)
		if texture != null:
			frames.add_frame("default", texture)
	if cache_key != "":
		_decoration_frames_cache[cache_key] = frames
	return frames


func _random_wall_decoration_point(room: Rect2i, rng: RandomNumberGenerator, preferred_side: String = "any") -> Vector2:
	var side: String = preferred_side
	if side == "any":
		var side_names: PackedStringArray = PackedStringArray(["top", "bottom", "left", "right"])
		side = side_names[rng.randi_range(0, side_names.size() - 1)]
	var tile_x: int = room.position.x + 1
	var tile_y: int = room.position.y + 1
	var offset: Vector2 = Vector2.ZERO
	match side:
		"top":
			tile_x = _rng_range(rng, room.position.x + 1, room.end.x - 2)
			tile_y = room.position.y + 1
			offset = Vector2(0.0, -6.0)
		"bottom":
			tile_x = _rng_range(rng, room.position.x + 1, room.end.x - 2)
			tile_y = room.end.y - 2
			offset = Vector2(0.0, 6.0)
		"left":
			tile_x = room.position.x + 1
			tile_y = _rng_range(rng, room.position.y + 1, room.end.y - 2)
			offset = Vector2(-6.0, 0.0)
		_:
			tile_x = room.end.x - 2
			tile_y = _rng_range(rng, room.position.y + 1, room.end.y - 2)
			offset = Vector2(6.0, 0.0)
	return Vector2(tile_x * 16 + 8, tile_y * 16 + 8) + offset


func _try_spawn_wishing_well(room: Rect2i, room_index: int) -> bool:
	var room_rng: RandomNumberGenerator = _create_room_rng(541, room_index)
	if room_rng.randf() > 0.50:
		return false
	var well: Area2D = WISHING_WELL_SCRIPT.new() as Area2D
	if well == null:
		return false
	if well.has_method("setup"):
		well.setup(loot_root, current_floor, int(room_rng.seed))
	well.position = _get_room_anchor_world(room, room_rng.randi_range(0, 3))
	feature_root.add_child(well)
	return true


func _try_spawn_demon_merchant(room: Rect2i, room_index: int, room_type: String, room_features: Dictionary) -> bool:
	if current_floor < 10:
		return false
	var spawn_room_index: int = int(floor_data.get("spawn_room_index", -1))
	var exit_room_index: int = int(floor_data.get("exit_room_index", -1))
	if room_index == spawn_room_index or room_index == exit_room_index:
		return false
	if room_type == "boss" or room_type == "secret_merchant":
		return false
	if bool(room_features.get("boss_merchant", false)):
		return false
	var is_special_room: bool = room_type == "treasure" or room_type == "trap" or room_type == "elite"
	if bool(room_features.get("event", false)) or bool(room_features.get("challenge", false)) or bool(room_features.get("puzzle", false)) or bool(room_features.get("safe", false)):
		is_special_room = true
	if not is_special_room:
		return false
	var room_rng: RandomNumberGenerator = _create_room_rng(577, room_index)
	if room_rng.randf() > 0.05:
		return false
	var merchant: Area2D = DEMON_MERCHANT_SCRIPT.new() as Area2D
	if merchant == null:
		return false
	if merchant.has_method("setup"):
		merchant.setup(loot_root, current_floor, int(room_rng.seed))
	merchant.position = _get_room_anchor_world(room, room_rng.randi_range(0, 3))
	feature_root.add_child(merchant)
	return true


func _get_room_anchor_world(room: Rect2i, anchor_index: int) -> Vector2:
	var anchor_tiles: Array[Vector2i] = [
		Vector2i(room.position.x + 1, room.position.y + 1),
		Vector2i(room.end.x - 2, room.position.y + 1),
		Vector2i(room.position.x + 1, room.end.y - 2),
		Vector2i(room.end.x - 2, room.end.y - 2),
	]
	var safe_index: int = clampi(anchor_index, 0, anchor_tiles.size() - 1)
	var anchor_tile: Vector2i = anchor_tiles[safe_index]
	return Vector2(anchor_tile.x * 16 + 8, anchor_tile.y * 16 + 8)


func _spawn_corridor_features() -> void:
	var corridor_features: Array = floor_data.get("corridor_features", [])
	for corridor_index in range(corridor_features.size()):
		var corridor_feature: Dictionary = corridor_features[corridor_index] as Dictionary
		if not bool(corridor_feature.get("trap", false)):
			continue
		_spawn_trap_corridor(corridor_feature, corridor_index)


func _spawn_trap_corridor(corridor_feature: Dictionary, corridor_index: int) -> void:
	var from_tile: Vector2i = corridor_feature.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = corridor_feature.get("to", Vector2i.ZERO)
	_spawn_corridor_segment_launchers(from_tile, Vector2i(to_tile.x, from_tile.y), true, corridor_index)
	_spawn_corridor_segment_launchers(Vector2i(to_tile.x, from_tile.y), to_tile, false, corridor_index + 7)


func _spawn_corridor_segment_launchers(start_tile: Vector2i, end_tile: Vector2i, is_horizontal: bool, seed_offset: int) -> void:
	if is_horizontal:
		var min_x: int = mini(start_tile.x, end_tile.x)
		var max_x: int = maxi(start_tile.x, end_tile.x)
		if max_x - min_x < 4:
			return
		for tile_x: int in range(min_x + 2, max_x - 1, 4):
			var top_delay: float = float((tile_x + seed_offset) % 3) * 0.35
			var bottom_delay: float = float((tile_x + seed_offset + 1) % 3) * 0.35
			_spawn_arrow_trap_launcher(Vector2i(tile_x, start_tile.y - 2), Vector2.DOWN, top_delay)
			_spawn_arrow_trap_launcher(Vector2i(tile_x, start_tile.y + 2), Vector2.UP, bottom_delay)
		return

	var min_y: int = mini(start_tile.y, end_tile.y)
	var max_y: int = maxi(start_tile.y, end_tile.y)
	if max_y - min_y < 4:
		return
	for tile_y: int in range(min_y + 2, max_y - 1, 4):
		var left_delay: float = float((tile_y + seed_offset) % 3) * 0.35
		var right_delay: float = float((tile_y + seed_offset + 1) % 3) * 0.35
		_spawn_arrow_trap_launcher(Vector2i(start_tile.x - 2, tile_y), Vector2.RIGHT, left_delay)
		_spawn_arrow_trap_launcher(Vector2i(start_tile.x + 2, tile_y), Vector2.LEFT, right_delay)


func _spawn_arrow_trap_launcher(tile_pos: Vector2i, direction: Vector2, initial_delay: float) -> void:
	var launcher: Node2D = ARROW_TRAP_LAUNCHER_SCRIPT.new() as Node2D
	if launcher == null:
		return
	if launcher.has_method("setup"):
		launcher.setup(direction, initial_delay, max(8 + current_floor, 10), 1.4)
	launcher.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
	feature_root.add_child(launcher)


func _spawn_boss_room_visual(room: Rect2i) -> void:
	var room_start: Vector2 = Vector2(room.position.x * 16, room.position.y * 16)
	var room_end: Vector2 = Vector2(room.end.x * 16, room.end.y * 16)

	var fill: Polygon2D = Polygon2D.new()
	fill.color = Color(0.55, 0.12, 0.12, 0.22)
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	feature_root.add_child(fill)

	var border: Line2D = Line2D.new()
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
	var boss_scene: PackedScene = _pick_boss_scene(current_floor)
	var boss = boss_scene.instantiate()
	boss.global_position = _random_point_in_room(room, rng)
	boss.configure_for_floor(player, current_floor, loot_root)
	_apply_floor_scaling(boss, 1.55, 1.3, 1.08 if current_floor >= 31 else 1.0)
	_maybe_apply_prefixes(boss, true, rng)
	boss.died.connect(_on_enemy_died.bind(boss))
	enemy_root.add_child(boss)
	if boss.has_method("setup_boss_arena"):
		boss.setup_boss_arena(self, room)
	boss_enemy_ref = boss


func _spawn_boss_locked_chest(room: Rect2i, rng: RandomNumberGenerator) -> void:
	var chest = LOCKED_CHEST_SCENE.instantiate()
	chest.global_position = _random_edge_point_in_room(room, rng)
	chest.setup(loot_root, current_floor)
	chest.modulate = _get_chest_modulate(max(current_floor, 21))
	feature_root.add_child(chest)
	boss_locked_chest = chest


func _get_chest_modulate(floor_number: int) -> Color:
	if floor_number >= 31:
		return Color(0.5, 0.9, 1.0)
	if floor_number >= 21:
		return Color(1.0, 0.85, 0.3)
	if floor_number >= 11:
		return Color(0.75, 0.85, 0.95)
	return Color(0.8, 0.6, 0.4)


func set_gameplay_paused(paused: bool) -> void:
	gameplay_paused = paused
	for enemy in enemy_root.get_children():
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(paused)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	for feature in feature_root.get_children():
		if feature.has_method("set_gameplay_paused"):
			feature.set_gameplay_paused(paused)
		feature.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT


func _pick_boss_scene(floor_number: int) -> PackedScene:
	if floor_number == 25:
		return ABYSS_EYE_BOSS_SCENE
	if floor_number == 15:
		return LAVA_GIANT_BOSS_SCENE
	if floor_number % 10 == 0:
		return NECROMANCER_BOSS_SCENE
	return BOSS_ENEMY_SCENE


func spawn_abyss_cover_pillars(room: Rect2i) -> void:
	var room_center: Vector2 = _room_center_world(room)
	var pillar_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-36.0, 26.0),
		Vector2(36.0, -26.0),
	]
	for offset: Vector2 in pillar_offsets:
		feature_root.add_child(_create_cover_pillar(room_center + offset))


func _create_cover_pillar(world_position: Vector2) -> Node2D:
	var pillar_root: Node2D = Node2D.new()
	pillar_root.name = "AbyssPillar"
	pillar_root.global_position = world_position
	pillar_root.z_index = 1

	var pillar_body: StaticBody2D = StaticBody2D.new()
	pillar_body.collision_layer = 1
	pillar_body.collision_mask = 0
	pillar_root.add_child(pillar_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 11.0
	collision_shape.shape = shape
	pillar_body.add_child(collision_shape)

	var base: Polygon2D = Polygon2D.new()
	base.color = Color(0.18, 0.18, 0.24, 1.0)
	base.polygon = PackedVector2Array([
		Vector2(-12.0, -12.0),
		Vector2(12.0, -12.0),
		Vector2(12.0, 12.0),
		Vector2(-12.0, 12.0),
	])
	pillar_root.add_child(base)

	var inner: Polygon2D = Polygon2D.new()
	inner.color = Color(0.45, 0.45, 0.58, 1.0)
	inner.polygon = PackedVector2Array([
		Vector2(-7.0, -11.0),
		Vector2(7.0, -11.0),
		Vector2(7.0, 11.0),
		Vector2(-7.0, 11.0),
	])
	pillar_root.add_child(inner)

	return pillar_root


func _apply_floor_scaling(enemy_node: Enemy, hp_multiplier: float, damage_multiplier: float, speed_multiplier: float) -> void:
	if enemy_node == null:
		return
	# Apply cycle-based scaling for all floors in cycle 2+
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle_scale: float = 1.0
	if cycle_manager != null and cycle_manager.has_method("get_enemy_scale"):
		cycle_scale = cycle_manager.get_enemy_scale()
	if cycle_scale > 1.0:
		enemy_node.max_hp = int(round(float(enemy_node.max_hp) * cycle_scale))
		enemy_node.current_hp = enemy_node.max_hp
		enemy_node.damage = int(round(float(enemy_node.damage) * cycle_scale))
	# Extra scaling for floor 31+
	if current_floor >= 31:
		enemy_node.max_hp = int(round(float(enemy_node.max_hp) * hp_multiplier))
		enemy_node.current_hp = enemy_node.max_hp
		enemy_node.damage = int(round(float(enemy_node.damage) * damage_multiplier))
		enemy_node.speed *= speed_multiplier
	if enemy_node.has_method("_update_hp_bar"):
		enemy_node.call("_update_hp_bar")


func get_minimap_snapshot() -> Dictionary:
	var enemy_positions: Array[Vector2] = []
	var chest_positions: Array[Vector2] = []
	var visible_floor_tiles: Array[Vector2i] = []
	var full_minimap: bool = _has_full_minimap()
	for enemy in enemy_root.get_children():
		if enemy.has_method("is_hidden_on_minimap") and bool(enemy.call("is_hidden_on_minimap")):
			continue
		enemy_positions.append(enemy.global_position)
	if treasure_reveal_time_left > 0.0:
		for child in feature_root.get_children():
			if child is DungeonChest:
				chest_positions.append(child.global_position)
		for enemy in enemy_root.get_children():
			if enemy.has_method("is_disguised_mimic") and bool(enemy.call("is_disguised_mimic")):
				chest_positions.append(enemy.global_position)
	for floor_tile_variant: Variant in floor_data.get("floor_tiles", []):
		var floor_tile: Vector2i = floor_tile_variant as Vector2i
		if full_minimap or revealed_tiles.has(floor_tile):
			visible_floor_tiles.append(floor_tile)
	var minimap_rooms: Array[int] = explored_rooms.duplicate()
	if full_minimap:
		minimap_rooms.clear()
		var room_count: int = (floor_data.get("rooms", []) as Array).size()
		for room_index: int in range(room_count):
			minimap_rooms.append(room_index)
	return {
		"mode": "dungeon",
		"map_size": DUNGEON_GENERATOR.MAP_SIZE,
		"floor_tiles": visible_floor_tiles,
		"rooms": floor_data.get("rooms", []),
		"room_types": floor_data.get("room_types", []),
		"boss_room_index": int(floor_data.get("boss_room_index", -1)),
		"spawn_room_index": int(floor_data.get("spawn_room_index", 0)),
		"exit_room_index": int(floor_data.get("exit_room_index", 0)),
		"explored_rooms": minimap_rooms,
		"enemy_positions": enemy_positions,
		"chest_positions": chest_positions,
		"stair_tile": Vector2(floor_data.get("exit_point", Vector2.ZERO).x / 16.0, floor_data.get("exit_point", Vector2.ZERO).y / 16.0),
		"spawn_tile": Vector2(floor_data.get("spawn_point", Vector2.ZERO).x / 16.0, floor_data.get("spawn_point", Vector2.ZERO).y / 16.0),
		"player_tile": Vector2(player.global_position.x / 16.0, player.global_position.y / 16.0) if player != null else Vector2.ZERO,
	}


func _ensure_fog_layer() -> void:
	if fog_tile_map_layer != null and is_instance_valid(fog_tile_map_layer):
		return
	var existing_layer: Node = get_node_or_null("fog")
	if existing_layer is TileMapLayer:
		fog_tile_map_layer = existing_layer as TileMapLayer
	else:
		fog_tile_map_layer = TileMapLayer.new()
		fog_tile_map_layer.name = "fog"
		add_child(fog_tile_map_layer)
	fog_tile_map_layer.tile_set = tile_map_layer.tile_set
	fog_tile_map_layer.z_index = max(tile_map_layer.z_index, wall_tile_map_layer.z_index) + 20
	fog_tile_map_layer.modulate = Color(0.0, 0.0, 0.0, 0.96)


func _reveal_room(room: Rect2i) -> void:
	for y: int in range(room.position.y - 1, room.end.y + 1):
		for x: int in range(room.position.x - 1, room.end.x + 1):
			_reveal_tile(Vector2i(x, y))


func _reveal_tile_radius(center_tile: Vector2i, radius: int) -> void:
	for y: int in range(center_tile.y - radius, center_tile.y + radius + 1):
		for x: int in range(center_tile.x - radius, center_tile.x + radius + 1):
			_reveal_tile(Vector2i(x, y))


func _reveal_tile(tile_pos: Vector2i) -> void:
	if revealed_tiles.has(tile_pos):
		return
	revealed_tiles[tile_pos] = true
	if fog_tile_map_layer != null:
		fog_tile_map_layer.erase_cell(tile_pos)


func _has_full_minimap() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var stats_node: Node = player.get_node_or_null("PlayerStats")
	if stats_node == null or not stats_node.has_method("has_full_minimap"):
		return false
	return bool(stats_node.call("has_full_minimap"))


func get_spawn_position(spawn_override: Variant = null) -> Vector2:
	if spawn_override is Vector2:
		return spawn_override
	return floor_data.get("spawn_point", Vector2.ZERO)


func _create_rng(offset: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
		var swap_index: int = rng.randi_range(0, index)
		var current_value: int = values[index]
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


func is_boss_floor() -> bool:
	return _is_boss_floor()


func _is_boss_floor() -> bool:
	return bool(floor_data.get("is_boss_floor", false))
