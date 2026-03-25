extends Node
class_name RaidSystem

signal banner_requested(message: String, color: Color, duration: float)
signal border_flash_requested(color: Color)
signal raid_started
signal raid_countdown_changed(message: String, color: Color, visible: bool)

const RAID_ENEMY_SCENE := preload("res://scenes/enemies/raid_enemy.tscn")
const RAID_WARNING_DURATION := 30.0
const BASE_MIN_ENEMIES := 8
const BASE_MAX_ENEMIES := 15
const FLOOR_SCALE_STEP := 5
const EXTRA_ENEMIES_PER_STEP := 3
const HP_SCALE_PER_STEP := 0.2

var player = null
var building_system = null
var total_dungeon_runs: int = 0
var current_day: int = 1
var deepest_floor_reached: int = 1
var raid_countdown_remaining: float = 0.0
var raid_warning_active: bool = false
var raid_active: bool = false
var raid_enemies: Array = []


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not raid_warning_active:
		return
	if raid_active or player == null:
		_cancel_countdown()
		return
	if building_system == null or not building_system.has_functional_core():
		_cancel_countdown()
		return
	raid_countdown_remaining = max(raid_countdown_remaining - delta, 0.0)
	_emit_countdown()
	if raid_countdown_remaining <= 0.0:
		_start_raid()


func bind_player(target_player, target_building_system) -> void:
	player = target_player
	building_system = target_building_system


func set_total_dungeon_runs(run_count: int) -> void:
	total_dungeon_runs = run_count


func set_day_count(day_count: int) -> void:
	current_day = max(day_count, 1)


func set_deepest_floor_reached(floor_number: int) -> void:
	deepest_floor_reached = max(floor_number, 1)


func queue_progress_raid() -> void:
	if raid_active or raid_warning_active:
		return
	if building_system == null or not building_system.has_functional_core():
		return
	raid_warning_active = true
	raid_countdown_remaining = RAID_WARNING_DURATION
	border_flash_requested.emit(Color(1.0, 0.12, 0.12, 1.0))
	_emit_countdown()


func _start_raid() -> void:
	var core = building_system.get_home_core() if building_system != null else null
	if core == null:
		_cancel_countdown()
		return
	_cancel_countdown()
	raid_active = true
	raid_started.emit()
	if core.has_method("set_raid_active"):
		core.set_raid_active(true)
	if core.has_signal("destroyed") and not core.destroyed.is_connected(_on_core_destroyed):
		core.destroyed.connect(_on_core_destroyed)
	banner_requested.emit("RAID STARTED! DEFEND THE HOME CORE!", Color(1.0, 0.2, 0.2, 1.0), 2.0)
	border_flash_requested.emit(Color(1.0, 0.12, 0.12, 1.0))
	_spawn_raid_enemies(core)


func _spawn_raid_enemies(core) -> void:
	_clear_enemy_refs()
	var scaling_steps := int(max(deepest_floor_reached - 1, 0) / FLOOR_SCALE_STEP)
	var enemy_count: int = randi_range(BASE_MIN_ENEMIES, BASE_MAX_ENEMIES) + scaling_steps * EXTRA_ENEMIES_PER_STEP
	var hp_multiplier := 1.0 + float(scaling_steps) * HP_SCALE_PER_STEP
	var enemy_root: Node2D = Node2D.new()
	enemy_root.name = "RaidEnemyRoot"
	get_parent().add_child(enemy_root)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for _index in range(enemy_count):
		var enemy = RAID_ENEMY_SCENE.instantiate()
		enemy_root.add_child(enemy)
		enemy.global_position = _get_spawn_position(viewport_size, core.global_position)
		enemy.setup_raid(player, core, deepest_floor_reached, hp_multiplier, enemy_root)
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
	banner_requested.emit("RAID SURVIVED! +5 Talent Shards", Color(0.45, 1.0, 0.45, 1.0), 3.0)
	if player != null and player.inventory != null:
		player.inventory.add_item("talent_shard", 5)
	_clear_enemy_root()


func _on_core_destroyed() -> void:
	raid_active = false
	banner_requested.emit("HOME CORE DESTROYED!", Color(1.0, 0.3, 0.3, 1.0), 3.0)
	for enemy in raid_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	raid_enemies.clear()
	_clear_enemy_root()


func _clear_enemy_refs() -> void:
	raid_enemies = raid_enemies.filter(func(enemy) -> bool: return enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion())


func is_raid_active() -> bool:
	return raid_active


func is_countdown_active() -> bool:
	return raid_warning_active


func _emit_countdown() -> void:
	var seconds_left := int(ceil(raid_countdown_remaining))
	var message := "⚠ %d 秒後襲擊 ⚠" % max(seconds_left, 0)
	raid_countdown_changed.emit(message, Color(1.0, 0.15, 0.15, 1.0), true)


func _cancel_countdown() -> void:
	raid_warning_active = false
	raid_countdown_remaining = 0.0
	raid_countdown_changed.emit("", Color(1.0, 0.15, 0.15, 1.0), false)


func _clear_enemy_root() -> void:
	var enemy_root = get_parent().get_node_or_null("RaidEnemyRoot")
	if enemy_root != null:
		enemy_root.queue_free()
()
e()
