extends Area2D
class_name ChallengeRoom

const COUNTDOWN_DURATION := 30.0

var level_ref = null
var room_index: int = -1
var room_rect: Rect2i
var door_tiles: Array[Vector2i] = []
var tracked_enemies: Array = []
var active_player = null

var is_active: bool = false
var is_resolved: bool = false
var time_left: float = COUNTDOWN_DURATION
var challenge_type: int = 0  # 0 = timed_clear, 1 = no_hit
var _player_took_damage: bool = false
var _player_hp_at_start: int = -1

var trigger_shape: CollisionShape2D = null
var door_root: Node2D = null
var countdown_layer: CanvasLayer = null
var countdown_label: Label = null


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_build_nodes()
	_sync_trigger_shape()
	set_process(false)


func setup(target_level, target_room_index: int, target_room: Rect2i, target_door_tiles: Array[Vector2i]) -> void:
	level_ref = target_level
	room_index = target_room_index
	room_rect = target_room
	door_tiles.clear()
	for tile in target_door_tiles:
		door_tiles.append(tile)
	# Randomly pick challenge type: 50% timed clear, 50% no-hit
	challenge_type = randi() % 2
	if is_node_ready():
		_sync_trigger_shape()


func _process(delta: float) -> void:
	if not is_active or is_resolved:
		return
	time_left = max(time_left - delta, 0.0)
	_update_countdown_label()
	if time_left <= 0.0:
		_resolve_room(false)


func _build_nodes() -> void:
	trigger_shape = get_node_or_null("CollisionShape2D")
	if trigger_shape == null:
		trigger_shape = CollisionShape2D.new()
		trigger_shape.name = "CollisionShape2D"
		add_child(trigger_shape)

	door_root = get_node_or_null("DoorRoot")
	if door_root == null:
		door_root = Node2D.new()
		door_root.name = "DoorRoot"
		door_root.z_index = 4
		add_child(door_root)


func _sync_trigger_shape() -> void:
	if trigger_shape == null:
		return
	var world_size := Vector2(room_rect.size.x * 16, room_rect.size.y * 16)
	global_position = Vector2(room_rect.position.x * 16, room_rect.position.y * 16) + world_size * 0.5
	var shape := RectangleShape2D.new()
	shape.size = Vector2(max(world_size.x - 12.0, 16.0), max(world_size.y - 12.0, 16.0))
	trigger_shape.shape = shape


func _on_body_entered(body: Node) -> void:
	if is_active or is_resolved or body == null:
		return
	if not body.is_in_group("player"):
		return
	active_player = body
	_start_challenge()


func _start_challenge() -> void:
	if level_ref == null:
		return
	is_active = true
	time_left = COUNTDOWN_DURATION
	_player_took_damage = false
	_player_hp_at_start = int(active_player.get("current_hp")) if active_player != null else -1
	_close_doors()
	_create_countdown_ui()
	_update_countdown_label()
	set_process(true)

	if active_player != null and active_player.has_method("show_status_message"):
		if challenge_type == 1:
			active_player.show_status_message(LocaleManager.L("challenge_nohit_started"), Color(0.85, 0.92, 1.0, 1.0), 2.5)
			# Connect to player damage signal to track hits
			if active_player.has_signal("hp_changed") and not active_player.hp_changed.is_connected(_on_challenge_hp_changed):
				active_player.hp_changed.connect(_on_challenge_hp_changed)
		else:
			active_player.show_status_message(LocaleManager.L("challenge_started"), Color(1.0, 0.62, 0.62, 1.0), 2.0)

	tracked_enemies.clear()
	if level_ref.has_method("spawn_challenge_room_wave"):
		var spawned_enemies: Array = level_ref.spawn_challenge_room_wave(room_index)
		for enemy in spawned_enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			tracked_enemies.append(enemy)
			enemy.died.connect(_on_tracked_enemy_died.bind(enemy))

	if _get_alive_enemy_count() == 0:
		_resolve_room(true)


func _on_tracked_enemy_died(_enemy_position: Vector2, enemy_ref) -> void:
	if enemy_ref != null and tracked_enemies.has(enemy_ref):
		tracked_enemies.erase(enemy_ref)
	if is_resolved:
		return
	if _get_alive_enemy_count() == 0:
		_resolve_room(true)


func _get_alive_enemy_count() -> int:
	var alive_count := 0
	for enemy in tracked_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		alive_count += 1
	return alive_count


func _on_challenge_hp_changed(current_hp: int, _max_hp: int) -> void:
	# Track damage taken during no-hit challenge
	if not is_active or is_resolved:
		return
	if _player_hp_at_start > 0 and current_hp < _player_hp_at_start:
		_player_took_damage = true
	_player_hp_at_start = current_hp


func _resolve_room(succeeded: bool) -> void:
	if is_resolved:
		return
	# Disconnect no-hit tracker
	if active_player != null and active_player.has_signal("hp_changed"):
		if active_player.hp_changed.is_connected(_on_challenge_hp_changed):
			active_player.hp_changed.disconnect(_on_challenge_hp_changed)
	is_resolved = true
	is_active = false
	set_process(false)
	_open_doors()
	_destroy_countdown_ui()

	var actual_success: bool = succeeded
	if challenge_type == 1 and succeeded and _player_took_damage:
		actual_success = false

	if actual_success:
		if level_ref != null and level_ref.has_method("spawn_challenge_room_reward"):
			level_ref.spawn_challenge_room_reward(room_index)
		if challenge_type == 1:
			if active_player != null and active_player.has_method("show_status_message"):
				active_player.show_status_message(LocaleManager.L("challenge_nohit_cleared"), Color(0.72, 1.0, 0.92, 1.0), 2.4)
		else:
			if active_player != null and active_player.has_method("show_status_message"):
				active_player.show_status_message(LocaleManager.L("challenge_cleared"), Color(0.72, 1.0, 0.76, 1.0), 2.4)
	else:
		if active_player != null and active_player.has_method("show_status_message"):
			if challenge_type == 1 and _player_took_damage:
				active_player.show_status_message(LocaleManager.L("challenge_nohit_failed"), Color(1.0, 0.72, 0.52, 1.0), 2.2)
			else:
				active_player.show_status_message(LocaleManager.L("challenge_failed"), Color(1.0, 0.72, 0.52, 1.0), 2.2)


func _close_doors() -> void:
	if door_root == null:
		return
	for child in door_root.get_children():
		child.queue_free()
	for tile_pos in door_tiles:
		door_root.add_child(_create_door_blocker(tile_pos))


func _open_doors() -> void:
	if door_root == null:
		return
	for child in door_root.get_children():
		child.queue_free()


func _create_door_blocker(tile_pos: Vector2i) -> Node2D:
	var blocker_root := Node2D.new()
	blocker_root.global_position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)

	var blocker := StaticBody2D.new()
	# Match existing dungeon wall blockers so both players and enemies collide with the closed door.
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker_root.add_child(blocker)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	blocker.add_child(collision)

	var panel := Polygon2D.new()
	panel.polygon = PackedVector2Array([
		Vector2(-7, -7),
		Vector2(7, -7),
		Vector2(7, 7),
		Vector2(-7, 7),
	])
	panel.color = Color(0.82, 0.18, 0.18, 0.96)
	blocker_root.add_child(panel)

	var bar := Line2D.new()
	bar.width = 2.0
	bar.default_color = Color(1.0, 0.82, 0.54, 1.0)
	bar.points = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0)])
	blocker_root.add_child(bar)

	return blocker_root


func _create_countdown_ui() -> void:
	if countdown_layer != null and is_instance_valid(countdown_layer):
		return
	countdown_layer = CanvasLayer.new()
	countdown_layer.name = "ChallengeCountdownLayer"
	add_child(countdown_layer)

	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_layer.add_child(root_control)

	countdown_label = Label.new()
	countdown_label.anchor_left = 0.0
	countdown_label.anchor_right = 1.0
	countdown_label.anchor_top = 0.0
	countdown_label.anchor_bottom = 0.0
	countdown_label.offset_top = 10.0
	countdown_label.offset_bottom = 42.0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 22)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.86, 1.0))
	countdown_label.add_theme_color_override("font_outline_color", Color(0.16, 0.02, 0.02, 1.0))
	countdown_label.add_theme_constant_override("outline_size", 4)
	root_control.add_child(countdown_label)


func _destroy_countdown_ui() -> void:
	if countdown_layer != null and is_instance_valid(countdown_layer):
		countdown_layer.queue_free()
	countdown_layer = null
	countdown_label = null


func _update_countdown_label() -> void:
	if countdown_label == null:
		return
	countdown_label.text = LocaleManager.L("challenge_countdown") % int(ceil(time_left))


func _exit_tree() -> void:
	_destroy_countdown_ui()
