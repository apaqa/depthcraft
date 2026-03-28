extends Node2D

@onready var hud: Control = $HUDCanvas/HUD
@onready var level_root: Node2D = $LevelRoot
@onready var player_spawner = $PlayerSpawner

const BUILDING_SAVE := preload("res://scripts/building/building_save.gd")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const OVERWORLD_SCENE := preload("res://scenes/overworld/test_overworld.tscn")
const TUTORIAL_MANAGER := preload("res://scripts/world/tutorial_manager.gd")

var player
var _tutorial_manager: Node = null
var current_level = null
var current_level_id: String = "overworld"
var current_level_seed: int = 0
var overworld_seed: int = 0
var dungeon_run_snapshot: Array = []
var total_dungeon_runs_completed: int = 0
var dungeon_returns_since_raid: int = 0
var overworld_return_position: Variant = null
var current_day: int = 1
var deepest_dungeon_floor_reached: int = 1


func _ready() -> void:
	randomize()
	overworld_seed = randi()
	var network_manager = _network_manager()
	if network_manager != null and not network_manager.players_changed.is_connected(_on_network_players_changed):
		network_manager.players_changed.connect(_on_network_players_changed)
	if network_manager != null and not network_manager.connection_status_changed.is_connected(_on_connection_status_changed):
		network_manager.connection_status_changed.connect(_on_connection_status_changed)
	var class_system = get_node_or_null("/root/ClassSystem")
	if class_system != null and not class_system.has_chosen_class():
		await _show_class_select()
	_start_tutorial()
	_sync_players_with_session()
	change_level(current_level_id)
	_on_connection_status_changed(_get_connection_status())


func _exit_tree() -> void:
	var network_manager = _network_manager()
	if network_manager != null and network_manager.players_changed.is_connected(_on_network_players_changed):
		network_manager.players_changed.disconnect(_on_network_players_changed)
	if network_manager != null and network_manager.connection_status_changed.is_connected(_on_connection_status_changed):
		network_manager.connection_status_changed.disconnect(_on_connection_status_changed)


func _sync_quest_day() -> void:
	QuestManager.set_day(current_day)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_reset"):
		_debug_goto_floor(10)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_reset_save"):
		_debug_clear_inventory_and_equipment()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_8:
		_debug_give_resources()
		get_viewport().set_input_as_handled()


func _debug_give_resources() -> void:
	var targets := get_tree().get_nodes_in_group("player")
	if targets.is_empty() and player != null:
		targets = [player]
	for p in targets:
		var inv = p.get("inventory")
		if inv == null or not inv.has_method("add_item"):
			continue
		inv.add_item("gold", 100)
		inv.add_item("silver", 100)
		inv.add_item("copper", 100)
		inv.add_item("wood", 99)
		inv.add_item("stone", 99)
		inv.add_item("iron_ore", 99)
		inv.add_item("fiber", 99)
		inv.add_item("wheat", 99)
		inv.add_item("talent_shard", 99)


func _debug_clear_inventory_and_equipment() -> void:
	var targets: Array = get_tree().get_nodes_in_group("player")
	if targets.is_empty() and player != null:
		targets = [player]
	for p in targets:
		var inv: Object = p.get("inventory")
		if inv != null:
			inv.items.clear()
			if inv.has_signal("inventory_changed"):
				inv.inventory_changed.emit()
		var eq: Object = p.get("equipment_system")
		if eq != null:
			for slot_name: String in eq.SLOT_ORDER:
				eq.unequip(str(slot_name))
	print("DEBUG: Cleared inventory and equipment")


func _debug_goto_floor(target_floor: int) -> void:
	current_level_seed = _create_level_seed()
	_broadcast_scene_change("dungeon", target_floor, current_level_seed)
	print("DEBUG: Teleporting to dungeon floor %d" % target_floor)


func change_level(level_id: String, spawn_override: Variant = null) -> void:
	if level_id == "dungeon":
		var floor_number := 1
		if current_level_id == "dungeon" and current_level != null:
			floor_number = int(current_level.get("current_floor"))
		current_level_seed = _create_level_seed() if current_level_seed == 0 else current_level_seed
		_broadcast_scene_change(level_id, floor_number, current_level_seed, spawn_override if spawn_override is Vector2 else Vector2.ZERO, spawn_override is Vector2)
		return
	_broadcast_scene_change(level_id, 1, 0, spawn_override if spawn_override is Vector2 else Vector2.ZERO, spawn_override is Vector2)


@rpc("authority", "call_local", "reliable")
func change_scene_all(level_id: String, floor_number: int = 1, level_seed: int = 0, spawn_override: Vector2 = Vector2.ZERO, has_spawn_override: bool = false) -> void:
	var resolved_override: Variant = spawn_override if has_spawn_override else null
	_change_level_internal(level_id, resolved_override, floor_number, level_seed)


func _change_level_internal(level_id: String, spawn_override: Variant = null, floor_number: int = 1, level_seed: int = 0) -> void:
	var previous_level_id := current_level_id
	var next_scene := _get_level_scene(level_id)
	if next_scene == null:
		return

	if current_level != null:
		for spawned_player in player_spawner.get_players():
			if spawned_player.get_parent() == current_level:
				spawned_player.reparent(level_root)
		current_level.queue_free()

	current_level = next_scene.instantiate()
	current_level_id = level_id
	if level_id == "dungeon":
		current_level.current_floor = floor_number
		current_level.level_seed = level_seed if level_seed != 0 else _create_level_seed()
		current_level_seed = current_level.level_seed
	else:
		current_level_seed = 0
		if level_id == "overworld":
			current_level.generation_seed = overworld_seed
	level_root.add_child(current_level)
	_place_players_in_current_level(spawn_override)
	for spawned_player in player_spawner.get_players():
		if spawned_player.building_system.has_method("set_active_level"):
			spawned_player.building_system.set_active_level(current_level_id, current_level)

	if current_level.has_signal("floor_changed") and not current_level.floor_changed.is_connected(_on_floor_changed):
		current_level.floor_changed.connect(_on_floor_changed)
	if current_level.has_signal("kills_changed") and not current_level.kills_changed.is_connected(_on_kills_changed):
		current_level.kills_changed.connect(_on_kills_changed)
	if current_level.has_signal("return_to_surface_requested") and not current_level.return_to_surface_requested.is_connected(_on_return_to_surface_requested):
		current_level.return_to_surface_requested.connect(_on_return_to_surface_requested)
	if current_level.has_signal("buff_selection_requested") and not current_level.buff_selection_requested.is_connected(_on_buff_selection_requested):
		current_level.buff_selection_requested.connect(_on_buff_selection_requested)
	if current_level.has_signal("floor_transition_requested") and not current_level.floor_transition_requested.is_connected(_on_floor_transition_requested):
		current_level.floor_transition_requested.connect(_on_floor_transition_requested)
	if current_level.has_signal("banner_requested") and not current_level.banner_requested.is_connected(_on_level_banner_requested):
		current_level.banner_requested.connect(_on_level_banner_requested)
	if current_level.has_signal("border_flash_requested") and not current_level.border_flash_requested.is_connected(_on_level_border_flash_requested):
		current_level.border_flash_requested.connect(_on_level_border_flash_requested)
	if current_level.has_signal("raid_started") and not current_level.raid_started.is_connected(_on_raid_started):
		current_level.raid_started.connect(_on_raid_started)
	if current_level.has_signal("raid_countdown_changed") and not current_level.raid_countdown_changed.is_connected(_on_raid_countdown_changed):
		current_level.raid_countdown_changed.connect(_on_raid_countdown_changed)

	if hud.has_method("bind_level"):
		hud.bind_level(current_level, current_level_id)
	var skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system != null:
		skill_system.bind_level(current_level, current_level_id)
	if hud.has_method("update_day_label"):
		hud.update_day_label(current_day)

	if level_id == "dungeon":
		if previous_level_id != "dungeon" and player != null:
			player.start_dungeon_run()
		dungeon_run_snapshot = player.inventory.get_state() if player != null else []
		var floor_value: Variant = current_level.get("current_floor")
		var kills_value: Variant = current_level.get("total_kills")
		_on_floor_changed(floor_value if floor_value != null else 0)
		_on_kills_changed(kills_value if kills_value != null else 0)
	else:
		_on_floor_changed(0)
		_on_kills_changed(0)
		if current_level.has_method("set_total_dungeon_runs"):
			current_level.set_total_dungeon_runs(total_dungeon_runs_completed)
		if current_level.has_method("set_day_count"):
			current_level.set_day_count(current_day)
		if current_level.has_method("set_deepest_floor_reached"):
			current_level.set_deepest_floor_reached(deepest_dungeon_floor_reached)

	for spawned_player in player_spawner.get_players():
		spawned_player.process_mode = Node.PROCESS_MODE_INHERIT
		spawned_player.set_process_input(true)
		spawned_player.set_physics_process(true)
		spawned_player.set_process_unhandled_input(true)
		spawned_player.heal_to_full()
	_on_connection_status_changed(_get_connection_status())


func _get_level_scene(level_id: String) -> PackedScene:
	match level_id:
		"dungeon":
			return DUNGEON_SCENE
		"overworld":
			return OVERWORLD_SCENE
		_:
			return null


func _on_player_portal_requested(target_level_id: String) -> void:
	if _is_multiplayer_enabled() and not _is_host():
		request_portal_transition.rpc_id(1, target_level_id)
		if player != null:
			player.show_status_message("Waiting for host...", Color(0.85, 0.9, 1.0, 1.0), 1.5)
		return
	if current_level_id == "overworld" and target_level_id == "dungeon" and current_level != null and current_level.has_method("get_dungeon_entrance_position"):
		overworld_return_position = current_level.get_dungeon_entrance_position()
	if current_level_id == "overworld" and target_level_id == "dungeon":
		await hud.fade_to_black("進入地牢...", Color(0, 0, 0, 1), 0.8)
		current_level_seed = _create_level_seed()
		_broadcast_scene_change(target_level_id, 1, current_level_seed)
		await get_tree().process_frame
		_reset_all_cameras()
		await get_tree().create_timer(0.3).timeout
		await hud.fade_from_black(Color(0, 0, 0, 1), 0.8)
		return
	call_deferred("_broadcast_scene_change", target_level_id, 1, current_level_seed)


func _on_floor_changed(current_floor: int) -> void:
	if hud.has_method("update_floor_label"):
		hud.update_floor_label(current_floor)
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.record_floor_reached(current_floor)


func _on_kills_changed(kills: int) -> void:
	if hud.has_method("update_kills_label"):
		hud.update_kills_label(kills)


func _on_return_to_surface_requested() -> void:
	if _is_multiplayer_enabled() and not _is_host():
		request_return_to_surface.rpc_id(1)
		return
	var floor_reached: int = int(current_level.get("current_floor")) if current_level != null else 0
	var kill_count: int = int(current_level.get("total_kills")) if current_level != null else 0
	var item_count: int = 0
	if player != null:
		for entry in player.dungeon_run_loot:
			item_count += int(entry.get("quantity", 0))
	await hud.fade_to_black("返回地面...", Color(0, 0, 0, 1), 0.5)
	if player != null:
		player.finish_dungeon_run(true)
	total_dungeon_runs_completed += 1
	dungeon_returns_since_raid += 1
	current_day += 1
	_sync_quest_day()
	deepest_dungeon_floor_reached = max(deepest_dungeon_floor_reached, floor_reached)
	_broadcast_scene_change("overworld", 1, 0, overworld_return_position if overworld_return_position is Vector2 else Vector2.ZERO, overworld_return_position is Vector2)
	if current_level != null and current_level.has_method("trigger_progress_raid") and dungeon_returns_since_raid >= 3:
		current_level.trigger_progress_raid()
	await get_tree().process_frame
	await hud.fade_from_black(Color(0, 0, 0, 1), 0.5)
	if player != null:
		player.show_status_message("已抵達第 %d 層 | %d 擊殺 | %d 件戰利品" % [floor_reached, kill_count, item_count], Color(0.85, 1.0, 0.85, 1.0), 4.0)


func _on_player_died() -> void:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.record_player_died()
	if current_level_id == "dungeon":
		if hud.has_method("show_death_screen"):
			var death_floor: Variant = current_level.get("current_floor")
			var death_kills: Variant = current_level.get("total_kills")
			hud.show_death_screen({
				"floor": death_floor if death_floor != null else 0,
				"kills": death_kills if death_kills != null else 0,
				"loot_lost": player.dungeon_run_loot.size() if player != null else 0,
			})
		await get_tree().create_timer(3.0).timeout
		if hud.has_method("play_transition"):
			await hud.play_transition("你死了\n第 %d 層 | %d 擊殺 | 地牢戰利品已遺失" % [int(current_level.get("current_floor")), int(current_level.get("total_kills"))], Color(0.35, 0.0, 0.0, 1.0), 0.25, 0.15)
		if player != null:
			player.finish_dungeon_run(false)
		total_dungeon_runs_completed += 1
		dungeon_returns_since_raid += 1
		current_day += 1
		_sync_quest_day()
		deepest_dungeon_floor_reached = max(deepest_dungeon_floor_reached, int(current_level.get("current_floor")))
		_broadcast_scene_change("overworld", 1, 0, overworld_return_position if overworld_return_position is Vector2 else Vector2.ZERO, overworld_return_position is Vector2)
		if player != null:
			player.show_status_message("你失去了戰利品！", Color(1.0, 0.75, 0.45, 1.0), 3.0)
		if current_level != null and current_level.has_method("trigger_progress_raid") and dungeon_returns_since_raid >= 3:
			current_level.trigger_progress_raid()
		if hud.has_method("hide_death_screen"):
			hud.hide_death_screen()


func _on_buff_selection_requested(options: Array) -> void:
	if hud.has_method("open_buff_selection"):
		hud.open_buff_selection(options, current_level)


func _on_level_banner_requested(message: String, color: Color, duration: float) -> void:
	if hud.has_method("show_event_banner"):
		hud.show_event_banner(message, color, duration)


func _on_level_border_flash_requested(color: Color) -> void:
	if hud.has_method("flash_border"):
		hud.flash_border(color)


func _on_raid_started() -> void:
	dungeon_returns_since_raid = 0


func _on_raid_countdown_changed(message: String, color: Color, visible: bool) -> void:
	if hud.has_method("set_raid_countdown"):
		hud.set_raid_countdown(message, color, visible)


func _reset_all_cameras() -> void:
	for spawned_player in player_spawner.get_players():
		var cam: Camera2D = spawned_player.get_node_or_null("Camera2D") as Camera2D
		if cam is Camera2D:
			cam.position = Vector2.ZERO
			cam.reset_smoothing()


func _on_floor_transition_requested(next_floor: int) -> void:
	if _is_multiplayer_enabled() and not _is_host():
		request_next_floor.rpc_id(1, next_floor)
		return
	await hud.fade_to_black("第 %d 層" % next_floor, Color(0, 0, 0, 1), 0.8)
	_broadcast_scene_change("dungeon", next_floor, current_level_seed)
	await get_tree().process_frame
	_reset_all_cameras()
	await get_tree().create_timer(0.3).timeout
	await hud.fade_from_black(Color(0, 0, 0, 1), 0.8)


@rpc("any_peer", "reliable")
func request_portal_transition(target_level_id: String) -> void:
	if _is_host():
		_on_player_portal_requested(target_level_id)


@rpc("any_peer", "reliable")
func request_next_floor(next_floor: int) -> void:
	if _is_host():
		_on_floor_transition_requested(next_floor)


@rpc("any_peer", "reliable")
func request_return_to_surface() -> void:
	if _is_host():
		_on_return_to_surface_requested()


func _on_network_players_changed(_player_ids: Array[int]) -> void:
	_sync_players_with_session()


func _sync_players_with_session() -> void:
	var desired_player_ids: Array[int] = [1]
	if _is_multiplayer_enabled():
		desired_player_ids = _get_connected_player_ids()
		if desired_player_ids.is_empty():
			desired_player_ids = [multiplayer.get_unique_id()]
	for peer_id in desired_player_ids:
		if player_spawner.get_player(peer_id) == null:
			player_spawner.spawn_player(peer_id, Vector2.ZERO)
	for peer_id in player_spawner.get_player_ids():
		if not desired_player_ids.has(peer_id):
			player_spawner.despawn_player(peer_id)
	_bind_local_player()
	if current_level != null:
		_place_players_in_current_level()
	_on_connection_status_changed(_get_connection_status())


func _bind_local_player() -> void:
	var local_peer_id := multiplayer.get_unique_id() if _is_multiplayer_enabled() and multiplayer.has_multiplayer_peer() else 1
	var local_player = player_spawner.get_player(local_peer_id)
	if local_player == null:
		return
	if player != null and player != local_player:
		if player.portal_requested.is_connected(_on_player_portal_requested):
			player.portal_requested.disconnect(_on_player_portal_requested)
		if player.died.is_connected(_on_player_died):
			player.died.disconnect(_on_player_died)
	player = local_player
	if not player.portal_requested.is_connected(_on_player_portal_requested):
		player.portal_requested.connect(_on_player_portal_requested)
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if hud.has_method("bind_player"):
		hud.bind_player(player)
	var skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system != null:
		skill_system.bind_player(player)
	if is_instance_valid(_tutorial_manager):
		_tutorial_manager.bind_player(player)


func _place_players_in_current_level(spawn_override: Variant = null) -> void:
	if current_level == null:
		return
	var peer_ids: Array[int] = player_spawner.get_player_ids()
	var base_position := _resolve_base_spawn(spawn_override)
	for index in range(peer_ids.size()):
		var peer_id: int = peer_ids[index]
		var spawned_player = player_spawner.get_player(peer_id)
		if spawned_player == null:
			continue
		var player_position := base_position + _spawn_offset_for_index(index, peer_ids.size())
		if current_level.has_method("place_player"):
			current_level.place_player(spawned_player, player_position)
		else:
			spawned_player.reparent(level_root)
			spawned_player.global_position = player_position
		var cam: Camera2D = spawned_player.get_node_or_null("Camera2D") as Camera2D
		if cam is Camera2D:
			cam.reset_smoothing()


func _resolve_base_spawn(spawn_override: Variant = null) -> Vector2:
	if spawn_override is Vector2:
		return spawn_override
	if current_level != null and current_level.has_method("get_spawn_position"):
		return current_level.get_spawn_position()
	return Vector2.ZERO


func _spawn_offset_for_index(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var angle := TAU * float(index) / float(count)
	return Vector2(22, 0).rotated(angle)


func _create_level_seed() -> int:
	return randi()


func _on_connection_status_changed(_status_text: String) -> void:
	if hud.has_method("set_connection_info"):
		hud.set_connection_info(_get_connection_status())


func _broadcast_scene_change(level_id: String, floor_number: int = 1, level_seed: int = 0, spawn_override: Vector2 = Vector2.ZERO, has_spawn_override: bool = false) -> void:
	if _is_multiplayer_enabled() and _is_host():
		change_scene_all.rpc(level_id, floor_number, level_seed, spawn_override, has_spawn_override)
	else:
		change_scene_all(level_id, floor_number, level_seed, spawn_override, has_spawn_override)


func _network_manager():
	return get_node_or_null("/root/NetworkManager")


func _is_multiplayer_enabled() -> bool:
	var network_manager = _network_manager()
	return network_manager != null and network_manager.is_multiplayer


func _is_host() -> bool:
	var network_manager = _network_manager()
	return network_manager != null and network_manager.is_host


func _get_connection_status() -> String:
	var network_manager = _network_manager()
	return network_manager.get_connection_status() if network_manager != null else ""


func _get_connected_player_ids() -> Array[int]:
	var network_manager = _network_manager()
	return network_manager.get_connected_player_ids() if network_manager != null else []


func _start_tutorial() -> void:
	_tutorial_manager = TUTORIAL_MANAGER.new()
	add_child(_tutorial_manager)


const CLASS_SELECT_SCREEN := preload("res://scripts/ui/class_select_screen.gd")

func _show_class_select() -> void:
	var screen := Control.new()
	screen.set_script(CLASS_SELECT_SCREEN)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(screen)
	await screen.class_chosen
	screen.queue_free()
