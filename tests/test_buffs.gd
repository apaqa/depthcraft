extends SceneTree

const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const ELITE_SCENE := preload("res://scenes/enemies/elite_enemy.tscn")

var _failures: PackedStringArray = []
var _buff_request_count: int = 0
var _buff_request_options_size: int = 0


func _initialize() -> void:
	await test_buff_pool_has_variety()
	await test_generate_random_buffs_returns_three_unique()
	await test_applying_attack_buff_increases_player_damage()
	await test_applying_hp_buff_increases_max_hp()
	await test_buffs_are_cleared_on_dungeon_exit()
	await test_elite_spawn_rules_match_floor_bands()
	await test_enemy_scaling_matches_formula()
	await test_elite_death_requests_buff_selection()
	await test_death_removes_dungeon_run_loot()
	await test_safe_return_keeps_loot()
	await test_bandage_heals_player()
	_report_results()


func test_buff_pool_has_variety() -> void:
	_assert(BUFF_SYSTEM.get_buff_pool().size() >= 12, "Buff pool should expose at least 12 buff options.")


func test_generate_random_buffs_returns_three_unique() -> void:
	var buffs: Array[Dictionary] = BUFF_SYSTEM.generate_random_buffs()
	_assert(buffs.size() == 3, "Buff roll should return exactly three options.")
	var seen: Dictionary = {}
	for buff in buffs:
		seen[str(buff.get("id", ""))] = true
	_assert(seen.size() == 3, "Buff roll should return unique options.")


func test_applying_attack_buff_increases_player_damage() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_damage: int = player.get_attack_damage()
	_assert(player.apply_buff("atk_up_1"), "Applying a valid attack buff should succeed.")
	_assert(player.get_attack_damage() > base_damage, "Attack buff should increase player damage.")
	player.queue_free()
	await process_frame


func test_applying_hp_buff_increases_max_hp() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_hp: int = player.max_hp
	player.apply_buff("hp_up")
	_assert(player.max_hp > base_hp, "HP buff should raise max HP.")
	player.queue_free()
	await process_frame


func test_buffs_are_cleared_on_dungeon_exit() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.apply_buff("atk_up_1")
	player.apply_buff("speed_up")
	player.finish_dungeon_run(true)
	_assert(player.active_buff_ids.is_empty(), "Leaving the dungeon should clear temporary buffs.")
	player.queue_free()
	await process_frame


func test_elite_spawn_rules_match_floor_bands() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	await process_frame
	var early_config: Dictionary = dungeon.get_floor_spawn_config(2)
	var late_config: Dictionary = dungeon.get_floor_spawn_config(8)
	_assert(int(early_config.get("elite_count", 0)) == 0, "Early floors should not spawn elites.")
	_assert(int(late_config.get("elite_count", 0)) >= 1, "Floor 7+ should guarantee at least one elite.")
	dungeon.queue_free()
	await process_frame


func test_enemy_scaling_matches_formula() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	enemy.configure_for_floor(player, 4, Node2D.new())
	_assert(enemy.max_hp == 48, "Enemy HP scaling should follow the floor formula.")
	_assert(enemy.damage == 11, "Enemy damage scaling should follow the floor formula.")
	player.queue_free()
	enemy.queue_free()
	await process_frame


func test_elite_death_requests_buff_selection() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	await process_frame
	var elite = ELITE_SCENE.instantiate()
	_buff_request_count = 0
	_buff_request_options_size = 0
	if not dungeon.buff_selection_requested.is_connected(_on_buff_requested):
		dungeon.buff_selection_requested.connect(_on_buff_requested)
	dungeon._on_enemy_died(Vector2.ZERO, elite)
	_assert(_buff_request_count == 1 and _buff_request_options_size == 3, "Elite death should request a three-choice buff selection.")
	dungeon.queue_free()
	await process_frame


func test_death_removes_dungeon_run_loot() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
	player.record_dungeon_loot("talent_shard", 2)
	player.finish_dungeon_run(false)
	_assert(player.inventory.get_item_count("talent_shard") == 0, "Death should remove loot gathered during the current dungeon run.")
	player.queue_free()
	await process_frame


func test_safe_return_keeps_loot() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
	player.record_dungeon_loot("talent_shard", 2)
	player.finish_dungeon_run(true)
	_assert(player.inventory.get_item_count("talent_shard") == 2, "Safe return should keep dungeon loot in the inventory.")
	player.queue_free()
	await process_frame


func test_bandage_heals_player() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.take_damage(30)
	player.inventory.add_item("bandage", 1)
	_assert(player.use_first_consumable(), "Bandage use should succeed when present.")
	_assert(player.current_hp == player.max_hp - 10, "Bandage should restore 20 HP.")
	player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_buff_requested(options: Array) -> void:
	_buff_request_count += 1
	_buff_request_options_size = options.size()


func _report_results() -> void:
	if _failures.is_empty():
		print("All buff tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
