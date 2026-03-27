extends SceneTree

const DUNGEON_GENERATOR = preload("res://scripts/dungeon/dungeon_generator.gd")
const DUNGEON_LEVEL_SCENE = preload("res://scenes/dungeon/dungeon_level.tscn")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")

var _failures: PackedStringArray = []
var _buff_request_count: int = 0
var _buff_request_options_size: int = 0


func _initialize() -> void:
	test_floor_five_creates_boss_room()
	await test_boss_death_unlocks_stairs()
	await test_boss_death_requests_buff_selection()
	_report_results()


func test_floor_five_creates_boss_room() -> void:
	var generator: Variant = DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(5)
	_assert(bool(floor_data.get("is_boss_floor", false)), "Floor 5 should be marked as a boss floor.")
	_assert(int(floor_data.get("boss_room_index", -1)) == int(floor_data.get("exit_room_index", -2)), "Boss room should be the last room on boss floors.")
	_assert(str((floor_data.get("room_types", []) as Array)[int(floor_data.get("exit_room_index", 0))]) == "boss", "Exit room should be tagged as a boss room.")


func test_boss_death_unlocks_stairs() -> void:
	var level: Variant = DUNGEON_LEVEL_SCENE.instantiate()
	var player: Variant = PLAYER_SCENE.instantiate()
	player.load_persistent_state_on_ready = false
	level.current_floor = 5
	root.add_child(level)
	root.add_child(player)
	await process_frame
	level.place_player(player)
	await process_frame
	_assert(level.boss_stairway != null and level.boss_stairway.is_locked, "Boss stairway should start locked on boss floors.")
	_assert(level.boss_enemy_ref != null, "Boss floor should spawn a boss enemy.")
	level.boss_enemy_ref.take_damage(level.boss_enemy_ref.current_hp)
	await process_frame
	_assert(level.boss_stairway != null and not level.boss_stairway.is_locked, "Boss stairway should unlock after the boss dies.")
	level.queue_free()
	player.queue_free()
	await process_frame


func test_boss_death_requests_buff_selection() -> void:
	var level: Variant = DUNGEON_LEVEL_SCENE.instantiate()
	var player: Variant = PLAYER_SCENE.instantiate()
	player.load_persistent_state_on_ready = false
	level.current_floor = 5
	root.add_child(level)
	root.add_child(player)
	await process_frame
	level.place_player(player)
	await process_frame
	_buff_request_count = 0
	_buff_request_options_size = 0
	if not level.buff_selection_requested.is_connected(_on_buff_requested):
		level.buff_selection_requested.connect(_on_buff_requested)
	_assert(level.boss_enemy_ref != null, "Boss floor should spawn a boss enemy for buff selection.")
	level.boss_enemy_ref.take_damage(level.boss_enemy_ref.current_hp)
	await process_frame
	_assert(_buff_request_count == 1 and _buff_request_options_size == 3, "Boss death should request a three-choice buff selection.")
	if level.buff_selection_requested.is_connected(_on_buff_requested):
		level.buff_selection_requested.disconnect(_on_buff_requested)
	level.queue_free()
	player.queue_free()
	await process_frame


func _on_buff_requested(options: Array) -> void:
	_buff_request_count += 1
	_buff_request_options_size = options.size()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All boss tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)

