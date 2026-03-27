extends Node2D

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started
signal raid_countdown_changed(message: String, color: Color, visible: bool)

const SOURCE_GRASS := 1
const SOURCE_GRASS_ALT := 1
const SOURCE_ROAD := 3
const SOURCE_WATER := 5
const SOURCE_WATER_ALT := 6
const BASE_CLEAR_RADIUS := 128.0
const TREE_SCENE := preload("res://scenes/world/tree_node.tscn")
const ROCK_SCENE := preload("res://scenes/world/rock_node.tscn")
const IRON_SCENE := preload("res://scenes/world/iron_node.tscn")
const GRASS_SCENE := preload("res://scenes/world/grass_node.tscn")
const MERCHANT_SCENE := preload("res://scenes/world/merchant.tscn")

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var raid_system = $RaidSystem
@onready var dungeon_entrance = $ReturnPortal

var generation_seed: int = 0
var _generator: WorldGenerator = null


func _ready() -> void:
	_generator = WorldGenerator.new()
	_generator.generate(generation_seed)
	player_spawn.position = _generator.get_spawn_pixel()
	dungeon_entrance.position = _generator.get_dungeon_entrance_pixel()
	build_ground()
	_spawn_resource_layout()
	_spawn_merchant()
	if raid_system != null and raid_system.has_signal("banner_requested") \
			and raid_system.has_signal("border_flash_requested") \
			and raid_system.has_signal("raid_started"):
		raid_system.banner_requested.connect(_on_banner_requested)
		raid_system.border_flash_requested.connect(_on_border_flash_requested)
		raid_system.raid_started.connect(func() -> void: raid_started.emit())
	if raid_system != null and raid_system.has_signal("raid_countdown_changed"):
		raid_system.raid_countdown_changed.connect(_on_raid_countdown_changed)


func place_player(player: Node2D, spawn_override: Variant = null) -> void:
	if player.get_parent() != self:
		player.reparent(self)
	player.global_position = get_spawn_position(spawn_override)
	if raid_system != null and raid_system.has_method("bind_player"):
		raid_system.bind_player(player, player.building_system)


func build_ground() -> void:
	tile_map_layer.clear()
	var map_size: Vector2i = WorldGenerator.MAP_SIZE

	for y in range(map_size.y):
		for x in range(map_size.x):
			var coords: Vector2i = Vector2i(x, y)
			# Use generator road data (supports winding roads)
			if _generator.is_road_tile(coords):
				tile_map_layer.set_cell(coords, SOURCE_ROAD, Vector2i.ZERO)
				continue
			var tile_type: String = _generator.get_tile_type(coords)
			# Border and water tiles both render as impassable water
			if tile_type == "water" or tile_type == "lake" or tile_type == "border":
				var src: int = SOURCE_WATER if (x + y) % 2 == 0 else SOURCE_WATER_ALT
				tile_map_layer.set_cell(coords, src, Vector2i.ZERO)
			else:
				tile_map_layer.set_cell(coords, SOURCE_GRASS, Vector2i.ZERO)

	tile_map_layer.update_internals()


func _spawn_resource_layout() -> void:
	for child in get_children():
		if child is ResourceNode or child.name.begins_with("AutoResource_"):
			child.queue_free()

	var spawn_px := _generator.get_spawn_pixel()
	var entrance_px := _generator.get_dungeon_entrance_pixel()
	var safe_dist := float((WorldGenerator.SAFE_RADIUS + 2) * WorldGenerator.TILE_SIZE)
	var entrance_clear := float(3 * WorldGenerator.TILE_SIZE)
	var idx := 0

	for cluster in _generator.forest_clusters:
		var count := clampi(cluster.radius / 2, 10, 25)
		for pos in _generator.sample_positions_in_cluster(cluster, count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node := TREE_SCENE.instantiate()
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			idx += 1

	for cluster in _generator.mountain_clusters:
		var rock_count := clampi(cluster.radius / 2, 8, 15)
		for pos in _generator.sample_positions_in_cluster(cluster, rock_count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node := ROCK_SCENE.instantiate()
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			idx += 1
		var iron_count := clampi(cluster.radius / 5, 2, 5)
		for pos in _generator.sample_positions_in_cluster(cluster, iron_count):
			if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
				continue
			var node := IRON_SCENE.instantiate()
			node.name = "AutoResource_%d" % idx
			node.position = pos
			add_child(node)
			idx += 1

	for pos in _generator.sample_plains_positions(20):
		if not _is_valid_resource_pos(pos, spawn_px, entrance_px, safe_dist, entrance_clear):
			continue
		var node := GRASS_SCENE.instantiate()
		node.name = "AutoResource_%d" % idx
		node.position = pos
		add_child(node)
		idx += 1

	# Scatter decorative objects (flowers, grass tufts, pebbles) across plains
	for tile_pos in _generator.get_decoration_positions():
		var px: Vector2 = Vector2(Vector2i(tile_pos) * WorldGenerator.TILE_SIZE)
		if not _is_valid_resource_pos(px, spawn_px, entrance_px, safe_dist, entrance_clear):
			continue
		var deco := GRASS_SCENE.instantiate()
		deco.name = "AutoResource_%d" % idx
		deco.position = px
		add_child(deco)
		idx += 1


func _is_valid_resource_pos(pos: Vector2, spawn_px: Vector2, entrance_px: Vector2,
		safe_dist: float, entrance_clear: float) -> bool:
	if pos.distance_to(spawn_px) < safe_dist:
		return false
	if pos.distance_to(entrance_px) < entrance_clear:
		return false
	var tile := Vector2i(int(pos.x) / WorldGenerator.TILE_SIZE, int(pos.y) / WorldGenerator.TILE_SIZE)
	var tile_type := _generator.get_tile_type(tile)
	return tile_type != "water" and tile_type != "lake" and tile_type != "border"


func _spawn_merchant() -> void:
	var existing := get_node_or_null("Merchant")
	if existing != null:
		return
	var merchant := MERCHANT_SCENE.instantiate()
	merchant.name = "Merchant"
	merchant.position = _generator.get_spawn_pixel() + Vector2(48, 0)
	add_child(merchant)


func set_total_dungeon_runs(run_count: int) -> void:
	if raid_system != null and raid_system.has_method("set_total_dungeon_runs"):
		raid_system.set_total_dungeon_runs(run_count)


func set_day_count(day_count: int) -> void:
	if raid_system != null and raid_system.has_method("set_day_count"):
		raid_system.set_day_count(day_count)


func set_deepest_floor_reached(floor_number: int) -> void:
	if raid_system != null and raid_system.has_method("set_deepest_floor_reached"):
		raid_system.set_deepest_floor_reached(floor_number)


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
