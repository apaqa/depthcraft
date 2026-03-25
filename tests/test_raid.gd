extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OVERWORLD_SCENE := preload("res://scenes/overworld/test_overworld.tscn")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_raid_spawns_enemies()
	await test_raid_enemies_target_home_core()
	await test_death_removes_dungeon_run_loot()
	await test_safe_return_keeps_loot()
	await test_death_applies_durability_penalty()
	_report_results()


func test_raid_spawns_enemies() -> void:
	var setup := await _create_overworld_with_core()
	setup.level.raid_system._start_raid()
	await process_frame
	var enemy_root = setup.level.get_node_or_null("RaidEnemyRoot")
	_assert(enemy_root != null and enemy_root.get_child_count() >= 5, "A raid should spawn between 5 and 10 enemies.")
	await _cleanup_setup(setup)


func test_raid_enemies_target_home_core() -> void:
	var setup := await _create_overworld_with_core()
	setup.level.raid_system._start_raid()
	await process_frame
	var enemy_root = setup.level.get_node_or_null("RaidEnemyRoot")
	var first_enemy = enemy_root.get_child(0)
	_assert(first_enemy.core_target == setup.player.building_system.get_home_core(), "Raid enemies should target the home core.")
	await _cleanup_setup(setup)


func test_death_removes_dungeon_run_loot() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
	player.record_dungeon_loot("talent_shard", 2)
	player.finish_dungeon_run(false)
	_assert(player.inventory.get_item_count("talent_shard") == 0, "Death should remove all tracked dungeon loot from inventory.")
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
	_assert(player.dungeon_run_loot.is_empty(), "Safe return should clear the dungeon loot tracker.")
	player.queue_free()
	await process_frame


func test_death_applies_durability_penalty() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var sword: Dictionary = ITEM_DATABASE.get_item("wood_sword")
	player.equipment_system.equip(sword, "weapon")
	player.finish_dungeon_run(false)
	var equipped: Dictionary = player.equipment_system.get_equipped("weapon")
	_assert(int(equipped.get("durability", 0)) == 40, "Death should remove 20% max durability from equipped gear.")
	player.queue_free()
	await process_frame


func _create_overworld_with_core() -> Dictionary:
	var level = OVERWORLD_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(level)
	root.add_child(player)
	await process_frame
	player.building_system.set_active_level("overworld", level)
	player.inventory.add_item("wood", 30)
	player.inventory.add_item("stone", 20)
	player.building_system.place_home_core(Vector2i(4, 4))
	level.place_player(player)
	level.set_total_dungeon_runs(4)
	return {
		"level": level,
		"player": player,
	}


func _cleanup_setup(setup: Dictionary) -> void:
	setup.level.queue_free()
	setup.player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All raid tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
