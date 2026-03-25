extends Node2D

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started
signal raid_countdown_changed(message: String, color: Color, visible: bool)

const GROUND_SIZE := Vector2i(60, 40)
const SOURCE_GRASS := 0
const SOURCE_GRASS_ALT := 1
const SOURCE_ROAD := 3
const SOURCE_WATER := 5
const SOURCE_WATER_ALT := 6
const BASE_CLEAR_RADIUS := 128.0
# Dungeon portal tile position (pixel 480,320 → tile 30,20)
const PORTAL_TILE := Vector2i(30, 20)
# Water border thickness
const WATER_BORDER := 2
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


func _ready() -> void:
	build_ground()
	_spawn_resource_layout()
	_spawn_merchant()
	if raid_system != null and raid_system.has_signal("banner_requested") and raid_system.has_signal("border_flash_requested") and raid_system.has_signal("raid_started"):
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

	for y in range(GROUND_SIZE.y):
		for x in range(GROUND_SIZE.x):
			var coords := Vector2i(x, y)
			# Water border around the map edges
			if x < WATER_BORDER or x >= GROUND_SIZE.x - WATER_BORDER \
					or y < WATER_BORDER or y >= GROUND_SIZE.y - WATER_BORDER:
				var src := SOURCE_WATER if (x + y) % 2 == 0 else SOURCE_WATER_ALT
				tile_map_layer.set_cell(coords, src, Vector2i.ZERO)
			# Dirt road leading south from portal to water border
			elif x >= PORTAL_TILE.x - 1 and x <= PORTAL_TILE.x \
					and y >= PORTAL_TILE.y and y < GROUND_SIZE.y - WATER_BORDER:
				tile_map_layer.set_cell(coords, SOURCE_ROAD, Vector2i.ZERO)
			else:
				# Solid grass tile - no transition tiles in main ground area
				tile_map_layer.set_cell(coords, SOURCE_GRASS, Vector2i.ZERO)

	tile_map_layer.update_internals()


func _spawn_resource_layout() -> void:
	for child in get_children():
		if child.name.begins_with("AutoResource_"):
			child.queue_free()
	var placements := [
		{"scene": TREE_SCENE, "pos": Vector2(112, 112)}, {"scene": TREE_SCENE, "pos": Vector2(176, 160)},
		{"scene": TREE_SCENE, "pos": Vector2(272, 96)}, {"scene": TREE_SCENE, "pos": Vector2(352, 208)},
		{"scene": TREE_SCENE, "pos": Vector2(592, 160)}, {"scene": TREE_SCENE, "pos": Vector2(704, 96)},
		{"scene": TREE_SCENE, "pos": Vector2(784, 224)}, {"scene": TREE_SCENE, "pos": Vector2(864, 128)},
		{"scene": TREE_SCENE, "pos": Vector2(896, 320)}, {"scene": TREE_SCENE, "pos": Vector2(656, 448)},
		{"scene": ROCK_SCENE, "pos": Vector2(144, 320)}, {"scene": ROCK_SCENE, "pos": Vector2(304, 400)},
		{"scene": ROCK_SCENE, "pos": Vector2(480, 112)}, {"scene": ROCK_SCENE, "pos": Vector2(704, 352)},
		{"scene": ROCK_SCENE, "pos": Vector2(896, 464)}, {"scene": ROCK_SCENE, "pos": Vector2(560, 528)},
		{"scene": IRON_SCENE, "pos": Vector2(240, 496)}, {"scene": IRON_SCENE, "pos": Vector2(448, 496)},
		{"scene": IRON_SCENE, "pos": Vector2(768, 512)}, {"scene": IRON_SCENE, "pos": Vector2(912, 240)},
		{"scene": GRASS_SCENE, "pos": Vector2(96, 224)}, {"scene": GRASS_SCENE, "pos": Vector2(160, 448)},
		{"scene": GRASS_SCENE, "pos": Vector2(256, 224)}, {"scene": GRASS_SCENE, "pos": Vector2(336, 528)},
		{"scene": GRASS_SCENE, "pos": Vector2(416, 272)}, {"scene": GRASS_SCENE, "pos": Vector2(544, 224)},
		{"scene": GRASS_SCENE, "pos": Vector2(624, 400)}, {"scene": GRASS_SCENE, "pos": Vector2(736, 208)},
		{"scene": GRASS_SCENE, "pos": Vector2(816, 416)}, {"scene": GRASS_SCENE, "pos": Vector2(928, 144)},
		{"scene": GRASS_SCENE, "pos": Vector2(944, 560)}, {"scene": GRASS_SCENE, "pos": Vector2(528, 592)},
	]
	var idx := 0
	for placement in placements:
		var node = (placement["scene"] as PackedScene).instantiate()
		node.name = "AutoResource_%d" % idx
		node.position = placement["pos"]
		add_child(node)
		idx += 1


func _spawn_merchant() -> void:
	var existing := get_node_or_null("Merchant")
	if existing != null:
		return
	var merchant = MERCHANT_SCENE.instantiate()
	merchant.name = "Merchant"
	merchant.position = Vector2(288, 320)
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
