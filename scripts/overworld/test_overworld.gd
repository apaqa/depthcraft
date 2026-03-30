extends Node2D

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started
signal raid_countdown_changed(message: String, color: Color, visible: bool)

const SOURCE_GRASS = 0
const SOURCE_GRASS_ALT = 1
const SOURCE_ROAD = 3
const SOURCE_WATER = 5
const SOURCE_WATER_ALT = 6
const SOURCE_ROAD_ALT = 4
const BASE_CLEAR_RADIUS = 128.0
const TREE_SCENE = preload("res://scenes/world/tree_node.tscn")
const ROCK_SCENE = preload("res://scenes/world/rock_node.tscn")
const IRON_SCENE = preload("res://scenes/world/iron_node.tscn")
const GRASS_SCENE = preload("res://scenes/world/grass_node.tscn")
const MERCHANT_SCENE = preload("res://scenes/world/merchant.tscn")
const VILLAGE_NPC_SCENE = preload("res://scenes/world/village_npc.tscn")
const OVERWORLD_ALTAR_SCRIPT: Script = preload("res://scripts/world/overworld_altar.gd")
const WANDERER_COUNT: int = 4

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var raid_system = $RaidSystem
@onready var dungeon_entrance = $ReturnPortal

const RESOURCE_CULL_RADIUS: float = 800.0
const RESOURCE_CULL_MOVE_THRESHOLD_SQ: float = 32.0 * 32.0

var generation_seed: int = 0
var current_day: int = 1
var _generator: WorldGenerator = null
var _world_npc_container: Node2D = null
var _recruited_npc_container: Node2D = null
var _player_ref: Node2D = null
var _resource_nodes: Array[Node2D] = []
var _last_cull_pos: Vector2 = Vector2(-99999.0, -99999.0)


func _ready() -> void:
	_generator = WorldGenerator.new()
	_generator.generate(generation_seed)
	player_spawn.position = _generator.get_spawn_pixel()
	dungeon_entrance.position = _generator.get_dungeon_entrance_pixel()
	build_ground()
	_spawn_resource_layout()
	_spawn_merchant()
	_spawn_altars()
	_ensure_npc_containers()
	_connect_npc_manager()
	_refresh_npc_population()
	if raid_system != null and raid_system.has_signal("banner_requested") \
			and raid_system.has_signal("border_flash_requested") \
			and raid_system.has_signal("raid_started"):
		raid_system.banner_requested.connect(_on_banner_requested)
		raid_system.border_flash_requested.connect(_on_border_flash_requested)
		raid_system.raid_started.connect(func() -> void: raid_started.emit())
	if raid_system != null and raid_system.has_signal("raid_countdown_changed"):
		raid_system.raid_countdown_changed.connect(_on_raid_countdown_changed)


func _exit_tree() -> void:
	if NpcManager != null and NpcManager.roster_changed.is_connected(_on_npc_roster_changed):
		NpcManager.roster_changed.disconnect(_on_npc_roster_changed)


func _process(_delta: float) -> void:
	_update_resource_culling()


func _update_resource_culling() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var player_pos: Vector2 = _player_ref.global_position
	if player_pos.distance_squared_to(_last_cull_pos) < RESOURCE_CULL_MOVE_THRESHOLD_SQ:
		return
	_last_cull_pos = player_pos
	var cull_sq: float = RESOURCE_CULL_RADIUS * RESOURCE_CULL_RADIUS
	for node: Node2D in _resource_nodes:
		if not is_instance_valid(node):
			continue
		node.visible = node.global_position.distance_squared_to(player_pos) <= cull_sq


func place_player(player: Node2D, spawn_override: Variant = null) -> void:
	_player_ref = player
	_last_cull_pos = Vector2(-99999.0, -99999.0)
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = get_spawn_position(spawn_override)
	if raid_system != null and raid_system.has_method("bind_player"):
		raid_system.bind_player(player, player.building_system)


func build_ground() -> void:
	tile_map_layer.clear()
	var map_size: Vector2i = WorldGenerator.MAP_SIZE
	var ground_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	ground_rng.seed = generation_seed ^ 0x6A55

	for y in range(map_size.y):
		for x in range(map_size.x):
			var coords: Vector2i = Vector2i(x, y)
			if _generator.is_road_tile(coords):
				var road_src: int = SOURCE_ROAD
				if ground_rng.randf() < 0.5:
					road_src = SOURCE_ROAD_ALT
				tile_map_layer.set_cell(coords, road_src, Vector2i.ZERO)
				continue
			tile_map_layer.set_cell(coords, SOURCE_GRASS, Vector2i.ZERO)

	tile_map_layer.update_internals()


func _spawn_resource_layout() -> void:
	for child: Node in get_children():
		if child is ResourceNode or child.name.begins_with("AutoResource_"):
			child.queue_free()
	_resource_nodes.clear()

	var spawn_px: Vector2 = _generator.get_spawn_pixel()
	var entrance_px: Vector2 = _generator.get_dungeon_entrance_pixel()
	var safe_dist: float = float((WorldGenerator.SAFE_RADIUS + 2) * WorldGenerator.TILE_SIZE)
	var entrance_clear: float = float(3 * WorldGenerator.TILE_SIZE)
	var idx: int = 0

	for cluster: Dictionary in _generator.forest_clusters:
		var count: int = clampi(cluster.radius / 6, 3, 8)
		for pos: Vector2 in _generator.sample_positions_in_cluster(cluster, count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node: Node2D = TREE_SCENE.instantiate() as Node2D
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			_resource_nodes.append(node)
			idx += 1

	for cluster: Dictionary in _generator.mountain_clusters:
		var rock_count: int = clampi(cluster.radius / 2, 8, 15)
		for pos: Vector2 in _generator.sample_positions_in_cluster(cluster, rock_count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node: Node2D = ROCK_SCENE.instantiate() as Node2D
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			_resource_nodes.append(node)
			idx += 1
		var iron_count: int = clampi(cluster.radius / 5, 2, 5)
		for pos: Vector2 in _generator.sample_positions_in_cluster(cluster, iron_count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node: Node2D = IRON_SCENE.instantiate() as Node2D
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			_resource_nodes.append(node)
			idx += 1

	for pos: Vector2 in _generator.sample_plains_positions(20):
		if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
			continue
		var node: Node2D = GRASS_SCENE.instantiate() as Node2D
		node.name = "AutoResource_%d" % idx
		node.position = pos
		add_child(node)
		_resource_nodes.append(node)
		idx += 1

	for tile_pos: Variant in _generator.get_decoration_positions():
		var px: Vector2 = Vector2(Vector2i(tile_pos) * WorldGenerator.TILE_SIZE)
		if not _is_valid_resource_pos(px, spawn_px, entrance_px, safe_dist, entrance_clear):
			continue
		var deco: Node2D = GRASS_SCENE.instantiate() as Node2D
		deco.name = "AutoResource_%d" % idx
		deco.position = px
		add_child(deco)
		_resource_nodes.append(deco)
		idx += 1


func _is_valid_resource_pos(pos: Vector2, spawn_px: Vector2, entrance_px: Vector2,
		safe_dist: float, entrance_clear: float) -> bool:
	if pos.distance_to(spawn_px) < safe_dist:
		return false
	if pos.distance_to(entrance_px) < entrance_clear:
		return false
	var tile: Vector2i = Vector2i(int(pos.x) / WorldGenerator.TILE_SIZE, int(pos.y) / WorldGenerator.TILE_SIZE)
	var tile_type: String = _generator.get_tile_type(tile)
	return tile_type != "water" and tile_type != "lake" and tile_type != "border"


func _spawn_merchant() -> void:
	var existing: Node = get_node_or_null("Merchant")
	if existing != null:
		return
	var merchant: Node2D = MERCHANT_SCENE.instantiate() as Node2D
	merchant.name = "Merchant"
	merchant.position = _generator.get_spawn_pixel() + Vector2(48, 0)
	add_child(merchant)


func _spawn_altars() -> void:
	# Remove existing altars
	for child: Node in get_children():
		if child.name.begins_with("OverworldAltar_"):
			child.queue_free()
	var spawn_px: Vector2 = _generator.get_spawn_pixel()
	var entrance_px: Vector2 = _generator.get_dungeon_entrance_pixel()
	var safe_dist: float = float((WorldGenerator.SAFE_RADIUS + 3) * WorldGenerator.TILE_SIZE)
	var entrance_clear: float = float(4 * WorldGenerator.TILE_SIZE)
	var map_size: Vector2 = Vector2(float(WorldGenerator.MAP_SIZE.x), float(WorldGenerator.MAP_SIZE.y)) * float(WorldGenerator.TILE_SIZE)
	var altar_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	altar_rng.seed = generation_seed ^ 0xA17A4
	var placed: int = 0
	var attempts: int = 0
	while placed < 4 and attempts < 200:
		attempts += 1
		var px: float = altar_rng.randf_range(float(WorldGenerator.TILE_SIZE) * 4.0, map_size.x - float(WorldGenerator.TILE_SIZE) * 4.0)
		var py: float = altar_rng.randf_range(float(WorldGenerator.TILE_SIZE) * 4.0, map_size.y - float(WorldGenerator.TILE_SIZE) * 4.0)
		var pos: Vector2 = Vector2(px, py)
		if pos.distance_to(spawn_px) < safe_dist:
			continue
		if pos.distance_to(entrance_px) < entrance_clear:
			continue
		var tile: Vector2i = Vector2i(int(pos.x) / WorldGenerator.TILE_SIZE, int(pos.y) / WorldGenerator.TILE_SIZE)
		if _generator.get_tile_type(tile) == "border":
			continue
		var altar: Area2D = Area2D.new()
		altar.set_script(OVERWORLD_ALTAR_SCRIPT)
		altar.name = "OverworldAltar_%d" % placed
		altar.position = pos
		add_child(altar)
		placed += 1


func set_total_dungeon_runs(run_count: int) -> void:
	if raid_system != null and raid_system.has_method("set_total_dungeon_runs"):
		raid_system.set_total_dungeon_runs(run_count)


func set_day_count(day_count: int) -> void:
	current_day = max(day_count, 1)
	if raid_system != null and raid_system.has_method("set_day_count"):
		raid_system.set_day_count(current_day)
	if NpcManager != null:
		NpcManager.set_current_day(current_day)
	var merchant: Node = get_node_or_null("Merchant")
	if merchant != null and merchant.has_method("refresh_inventory_state"):
		merchant.call("refresh_inventory_state")
	_refresh_npc_population()


func set_deepest_floor_reached(floor_number: int) -> void:
	if WorldLevel != null and WorldLevel.has_method("set_deepest_floor_reached"):
		WorldLevel.call("set_deepest_floor_reached", floor_number)
	if raid_system != null and raid_system.has_method("set_deepest_floor_reached"):
		raid_system.set_deepest_floor_reached(floor_number)
	var merchant: Node = get_node_or_null("Merchant")
	if merchant != null and merchant.has_method("refresh_inventory_state"):
		merchant.call("refresh_inventory_state")
	_refresh_npc_population()


func trigger_progress_raid() -> void:
	if raid_system != null and raid_system.has_method("queue_progress_raid"):
		raid_system.queue_progress_raid()


func _on_banner_requested(message: String, color: Color, duration: float) -> void:
	banner_requested.emit(message, color, duration)


func _on_border_flash_requested(color: Color) -> void:
	border_flash_requested.emit(color)


func _on_raid_countdown_changed(message: String, color: Color, visible: bool) -> void:
	raid_countdown_changed.emit(message, color, visible)


func get_dungeon_entrance_position() -> Vector2:
	return dungeon_entrance.global_position if dungeon_entrance != null else player_spawn.global_position


func is_raid_active() -> bool:
	return raid_system != null and raid_system.has_method("is_raid_active") and raid_system.is_raid_active()


func get_spawn_position(spawn_override: Variant = null) -> Vector2:
	var spawn_position: Vector2 = player_spawn.global_position
	if spawn_override is Vector2:
		spawn_position = spawn_override
	return spawn_position


func clear_base_area_around(world_position: Vector2) -> void:
	for child in get_children():
		if child == player_spawn or child == raid_system:
			continue
		if not child.has_method("set_permanently_depleted"):
			continue
		if child.global_position.distance_to(world_position) <= BASE_CLEAR_RADIUS:
			child.set_permanently_depleted()


func _ensure_npc_containers() -> void:
	if _world_npc_container == null:
		_world_npc_container = get_node_or_null("WorldNpcContainer") as Node2D
	if _world_npc_container == null:
		_world_npc_container = Node2D.new()
		_world_npc_container.name = "WorldNpcContainer"
		add_child(_world_npc_container)
	if _recruited_npc_container == null:
		_recruited_npc_container = get_node_or_null("RecruitedNpcContainer") as Node2D
	if _recruited_npc_container == null:
		_recruited_npc_container = Node2D.new()
		_recruited_npc_container.name = "RecruitedNpcContainer"
		add_child(_recruited_npc_container)


func _connect_npc_manager() -> void:
	if NpcManager == null:
		return
	if not NpcManager.roster_changed.is_connected(_on_npc_roster_changed):
		NpcManager.roster_changed.connect(_on_npc_roster_changed)


func _on_npc_roster_changed(_recruited_count: int) -> void:
	_spawn_recruited_npcs()
	var merchant: Node = get_node_or_null("Merchant")
	if merchant != null and merchant.has_method("refresh_inventory_state"):
		merchant.call("refresh_inventory_state")


func _refresh_npc_population() -> void:
	_spawn_world_npcs()
	_spawn_recruited_npcs()


func _clear_container_children(container: Node2D) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		child.queue_free()


func _spawn_world_npcs() -> void:
	if _world_npc_container == null or _generator == null:
		return
	_clear_container_children(_world_npc_container)
	var spawn_seed: int = generation_seed + current_day * 101
	var positions: Array[Vector2] = _build_wanderer_positions(WANDERER_COUNT)
	for index: int in range(mini(WANDERER_COUNT, positions.size())):
		var npc_instance: Area2D = VILLAGE_NPC_SCENE.instantiate() as Area2D
		if npc_instance == null:
			continue
		npc_instance.position = positions[index]
		if npc_instance.has_method("setup"):
			npc_instance.call("setup", NpcManager.create_random_wanderer(spawn_seed, index), true)
		_world_npc_container.add_child(npc_instance)


func _spawn_recruited_npcs() -> void:
	if _recruited_npc_container == null:
		return
	_clear_container_children(_recruited_npc_container)
	var anchor_position: Vector2 = _resolve_home_anchor()
	var recruited_roster: Array[Dictionary] = NpcManager.recruited_npcs
	for index: int in range(recruited_roster.size()):
		var npc_instance: Area2D = VILLAGE_NPC_SCENE.instantiate() as Area2D
		if npc_instance == null:
			continue
		npc_instance.position = anchor_position + NpcManager.get_settlement_offset(index)
		if npc_instance.has_method("setup"):
			npc_instance.call("setup", recruited_roster[index], false)
		_recruited_npc_container.add_child(npc_instance)


func _build_wanderer_positions(target_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	_append_village_positions(positions, target_count)
	_append_roadside_positions(positions, target_count)
	if positions.size() >= target_count:
		return positions
	var fallback_positions: Array = _generator.sample_plains_positions(target_count * 2)
	for fallback_variant: Variant in fallback_positions:
		if not fallback_variant is Vector2:
			continue
		var fallback_position: Vector2 = fallback_variant as Vector2
		_try_append_npc_position(positions, fallback_position, target_count)
		if positions.size() >= target_count:
			break
	return positions


func _append_village_positions(positions: Array[Vector2], target_count: int) -> void:
	var spawn_center: Vector2 = _generator.get_spawn_pixel()
	var village_offsets: Array[Vector2] = [
		Vector2(-52.0, 20.0),
		Vector2(54.0, 18.0),
		Vector2(-14.0, 48.0),
	]
	for offset: Vector2 in village_offsets:
		_try_append_npc_position(positions, spawn_center + offset, target_count)
		if positions.size() >= target_count:
			return


func _append_roadside_positions(positions: Array[Vector2], target_count: int) -> void:
	for tile_variant: Variant in _generator.road_tiles.keys():
		if not tile_variant is Vector2i:
			continue
		var road_tile: Vector2i = tile_variant as Vector2i
		if road_tile.y % 18 != 0:
			continue
		var road_position: Vector2 = Vector2(
			float(road_tile.x * WorldGenerator.TILE_SIZE + WorldGenerator.TILE_SIZE / 2),
			float(road_tile.y * WorldGenerator.TILE_SIZE + WorldGenerator.TILE_SIZE / 2)
		)
		var roadside_offset: Vector2 = Vector2(22.0, 0.0) if road_tile.x <= WorldGenerator.CENTER.x else Vector2(-22.0, 0.0)
		_try_append_npc_position(positions, road_position + roadside_offset, target_count)
		if positions.size() >= target_count:
			return


func _try_append_npc_position(positions: Array[Vector2], candidate_position: Vector2, target_count: int) -> void:
	if positions.size() >= target_count:
		return
	if candidate_position.distance_to(_generator.get_dungeon_entrance_pixel()) < 48.0:
		return
	if candidate_position.distance_to(_generator.get_spawn_pixel()) < 26.0:
		return
	var tile_position: Vector2i = Vector2i(
		floori(candidate_position.x / WorldGenerator.TILE_SIZE),
		floori(candidate_position.y / WorldGenerator.TILE_SIZE)
	)
	var tile_type: String = _generator.get_tile_type(tile_position)
	if tile_type == "border":
		return
	for existing_position: Vector2 in positions:
		if existing_position.distance_to(candidate_position) < 28.0:
			return
	positions.append(candidate_position)


func get_minimap_snapshot() -> Dictionary:
	var player_pos: Vector2 = Vector2.ZERO
	var players: Array = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node = players[0] as Node
		if p != null and "global_position" in p:
			player_pos = p.global_position as Vector2
	var home_core_pos: Vector2 = Vector2.ZERO
	if not players.is_empty():
		var p: Node = players[0] as Node
		if p != null and "building_system" in p:
			var bsys: Node = p.building_system as Node
			if bsys != null:
				var hcp: Variant = bsys.get("home_core_position")
				if hcp is Vector2:
					home_core_pos = hcp as Vector2
	var merchant_node: Node = get_node_or_null("Merchant")
	var merchant_pos: Vector2 = merchant_node.global_position if merchant_node != null else Vector2.ZERO
	var entrance_pos: Vector2 = _generator.get_dungeon_entrance_pixel() if _generator != null else Vector2.ZERO
	var world_tile_size: int = WorldGenerator.TILE_SIZE
	var world_map_size: Vector2i = WorldGenerator.MAP_SIZE
	var world_px_size: Vector2 = Vector2(
		float(world_map_size.x * world_tile_size),
		float(world_map_size.y * world_tile_size)
	)
	var forest_data: Array = []
	if _generator != null:
		for cluster: Dictionary in _generator.forest_clusters:
			var center_tile: Vector2i = cluster.get("center", Vector2i.ZERO) as Vector2i
			var radius_tiles: int = int(cluster.get("radius", 0))
			forest_data.append({
				"center": Vector2(
					float(center_tile.x * world_tile_size + world_tile_size / 2),
					float(center_tile.y * world_tile_size + world_tile_size / 2)
				),
				"radius": float(radius_tiles * world_tile_size)
			})
	var mountain_data: Array = []
	if _generator != null:
		for cluster: Dictionary in _generator.mountain_clusters:
			var center_tile: Vector2i = cluster.get("center", Vector2i.ZERO) as Vector2i
			var radius_tiles: int = int(cluster.get("radius", 0))
			mountain_data.append({
				"center": Vector2(
					float(center_tile.x * world_tile_size + world_tile_size / 2),
					float(center_tile.y * world_tile_size + world_tile_size / 2)
				),
				"radius": float(radius_tiles * world_tile_size)
			})
	return {
		"mode": "overworld",
		"world_size": world_px_size,
		"player_pos": player_pos,
		"dungeon_entrance_pos": entrance_pos,
		"merchant_pos": merchant_pos,
		"home_core_pos": home_core_pos,
		"forest_clusters": forest_data,
		"mountain_clusters": mountain_data,
	}


func _resolve_home_anchor() -> Vector2:
	var primary_player: Node = _get_primary_player()
	if primary_player != null and "building_system" in primary_player:
		var building_system: Node = primary_player.building_system
		if building_system != null:
			var home_core_position: Variant = building_system.get("home_core_position")
			if home_core_position is Vector2 and (home_core_position as Vector2) != Vector2.ZERO:
				return home_core_position as Vector2
	return _generator.get_spawn_pixel() + Vector2(0.0, 44.0)


func _get_primary_player() -> Node:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node
