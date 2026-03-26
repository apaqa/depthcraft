extends SceneTree

const DUNGEON_GENERATOR := preload("res://scripts/dungeon/dungeon_generator.gd")
const DUNGEON_LEVEL_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	test_floor_five_creates_boss_room()
	await test_boss_death_unlocks_stairs()
	_report_results()


func test_floor_five_creates_boss_room() -> void:
	var generator := DUNGEON_GENERATOR.new()
	var floor_data: Dictionary = generator.generate_floor(5)
	_assert(bool(floor_data.get("is_boss_floor", false)), "Floor 5 should be marked as a boss floor.")
	_assert(int(floor_data.get("boss_room_index", -1)) == int(floor_data.get("exit_room_index", -2)), "Boss room should be the last room on boss floors.")
	_assert(str((floor_data.get("room_types", []) as Array)[int(floor_data.get("exit_room_index", 0))]) == "boss", "Exit room should be tagged as a boss room.")


func test_boss_death_unlocks_stairs() -> void:
	var level = DUNGEON_LEVEL_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
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

