extends Node
class_name RaidSystem

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started

const RAID_ENEMY_SCENE := preload("res://scenes/enemies/raid_enemy.tscn")
const RAID_INTERVAL := 300.0
const RAID_WARNING_TIME := 10.0

var player = null
var building_system = null
var total_dungeon_runs: int = 0
var time_until_raid: float = RAID_INTERVAL
var warning_shown: bool = false
var raid_active: bool = false
var raid_enemies: Array = []


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if raid_active or player == null:
		return
	if building_system == null or not building_system.has_functional_core():
		return
	time_until_raid = max(time_until_raid - delta, 0.0)
	if not warning_shown and time_until_raid <= RAID_WARNING_TIME:
		warning_shown = true
		banner_requested.emit("RAID INCOMING! Defend your base!", Color(1.0, 0.25, 0.25, 1.0), 2.0)
		border_flash_requested.emit(Color(1.0, 0.15, 0.15, 1.0))
	if time_until_raid <= 0.0:
		_start_raid()


func bind_player(target_player, target_building_system) -> void:
	player = target_player
	building_system = target_building_system


func set_total_dungeon_runs(run_count: int) -> void:
	total_dungeon_runs = run_count


func queue_progress_raid() -> void:
	time_until_raid = min(time_until_raid, RAID_WARNING_TIME)


func _start_raid() -> void:
	var core = building_system.get_home_core() if building_system != null else null
	if core == null:
		_reset_timer()
		return
	raid_active = true
	warning_shown = false
	raid_started.emit()
	if core.has_method("set_raid_active"):
		core.set_raid_active(true)
	if core.has_signal("destroyed") and not core.destroyed.is_connected(_on_core_destroyed):
		core.destroyed.connect(_on_core_destroyed)
	_spawn_raid_enemies(core)


func _spawn_raid_enemies(core) -> void:
	_clear_enemy_refs()
	var enemy_count: int = min(10, max(5, 5 + int(total_dungeon_runs / 2) + randi_range(0, 2)))
	var enemy_root: Node2D = Node2D.new()
	enemy_root.name = "RaidEnemyRoot"
	get_parent().add_child(enemy_root)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for _index in range(enemy_count):
		var enemy = RAID_ENEMY_SCENE.instantiate()
		enemy_root.add_child(enemy)
		enemy.global_position = _get_spawn_position(viewport_size, core.global_position)
		enemy.setup_raid(player, core, total_dungeon_runs, enemy_root)
		enemy.died.connect(_on_raid_enemy_died.bind(enemy))
		raid_enemies.append(enemy)


func _get_spawn_position(viewport_size: Vector2, anchor_position: Vector2) -> Vector2:
	var side := randi() % 4
	var margin := 48.0
	match side:
		0:
			return anchor_position + Vector2(randf_range(-viewport_size.x * 0.6, viewport_size.x * 0.6), -viewport_size.y * 0.6 - margin)
		1:
			return anchor_position + Vector2(randf_range(-viewport_size.x * 0.6, viewport_size.x * 0.6), viewport_size.y * 0.6 + margin)
		2:
			return anchor_position + Vector2(-viewport_size.x * 0.7 - margin, randf_range(-viewport_size.y * 0.5, viewport_size.y * 0.5))
		_:
			return anchor_position + Vector2(viewport_size.x * 0.7 + margin, randf_range(-viewport_size.y * 0.5, viewport_size.y * 0.5))


func _on_raid_enemy_died(_enemy_position: Vector2, enemy_ref) -> void:
	raid_enemies.erase(enemy_ref)
	_clear_enemy_refs()
	if not raid_enemies.is_empty():
		return
	raid_active = false
	var core = building_system.get_home_core() if building_system != null else null
	if core != null and core.has_method("set_raid_active"):
		core.set_raid_active(false)
	banner_requested.emit("Raid Survived!", Color(0.45, 1.0, 0.45, 1.0), 2.0)
	if player != null and player.inventory != null:
		player.inventory.add_item("talent_shard", randi_range(2, 3))
	_reset_timer()


func _on_core_destroyed() -> void:
	raid_active = false
	banner_requested.emit("Home Core Destroyed!", Color(1.0, 0.3, 0.3, 1.0), 2.0)
	for enemy in raid_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	raid_enemies.clear()
	_reset_timer()


func _clear_enemy_refs() -> void:
	raid_enemies = raid_enemies.filter(func(enemy) -> bool: return enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion())


func _reset_timer() -> void:
	time_until_raid = RAID_INTERVAL
	warning_shown = false
