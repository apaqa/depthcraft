extends Node2D

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started

const GROUND_SIZE := Vector2i(28, 18)
const SOURCE_OUTDOOR_GROUND := 5

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var building_layer: TileMapLayer = $BuildingLayer
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var raid_system = $RaidSystem


func _ready() -> void:
	build_ground()
	if raid_system != null and raid_system.has_signal("banner_requested") and raid_system.has_signal("border_flash_requested") and raid_system.has_signal("raid_started"):
		raid_system.banner_requested.connect(_on_banner_requested)
		raid_system.border_flash_requested.connect(_on_border_flash_requested)
		raid_system.raid_started.connect(func() -> void: raid_started.emit())


func place_player(player: Node2D) -> void:
	if player.get_parent() != self:
		player.reparent(self)
	var core = player.building_system.get_home_core() if player != null else null
	player.global_position = core.global_position if core != null else player_spawn.global_position
	if raid_system != null and raid_system.has_method("bind_player"):
		raid_system.bind_player(player, player.building_system)


func build_ground() -> void:
	tile_map_layer.clear()

	for y in range(GROUND_SIZE.y):
		for x in range(GROUND_SIZE.x):
			var coords := Vector2i(x, y)
			tile_map_layer.set_cell(coords, SOURCE_OUTDOOR_GROUND, Vector2i.ZERO)

	tile_map_layer.update_internals()


func set_total_dungeon_runs(run_count: int) -> void:
	if raid_system != null and raid_system.has_method("set_total_dungeon_runs"):
		raid_system.set_total_dungeon_runs(run_count)


func trigger_progress_raid() -> void:
	if raid_system != null and raid_system.has_method("queue_progress_raid"):
		raid_system.queue_progress_raid()


func _on_banner_requested(message: String, color: Color, duration: float) -> void:
	banner_requested.emit(message, color, duration)


func _on_border_flash_requested(color: Color) -> void:
	border_flash_requested.emit(color)
