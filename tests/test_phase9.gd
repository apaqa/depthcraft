extends SceneTree

const BUILDING_DATA := preload("res://scripts/building/building_data.gd")
const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")
const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	test_building_categories_contain_correct_items()
	test_crafting_costs_are_correct()
	test_buff_selection_generates_three_unique_buffs()
	await test_buff_applies_stat_change()
	await test_buffs_clear_on_dungeon_exit()
	test_elite_spawn_rules_start_on_floor_three()
	await test_death_removes_dungeon_loot()
	await test_death_applies_durability_penalty()
	_report_results()


func test_building_categories_contain_correct_items() -> void:
	_assert(BUILDING_DATA.get_buildings_for_category("structure").size() == 4, "Structure category should contain 4 items.")
	_assert(BUILDING_DATA.get_buildings_for_category("door_window").size() == 1, "Door/Window category should contain the wood door.")
	_assert(BUILDING_DATA.get_buildings_for_category("facility").size() == 6, "Facility category should contain the six current facilities.")
	_assert(BUILDING_DATA.get_buildings_for_category("defense").is_empty(), "Defense category should be empty for now.")


func test_crafting_costs_are_correct() -> void:
	var cost := CRAFTING_SYSTEM.get_recipe_cost("iron_sword")
	_assert(int(cost.get("iron_ore", 0)) == 5, "Iron Sword should cost 5 iron ore.")
	_assert(int(cost.get("wood", 0)) == 2, "Iron Sword should cost 2 wood.")


func test_buff_selection_generates_three_unique_buffs() -> void:
	var buffs := BUFF_SYSTEM.generate_random_buffs(3)
	var ids := {}
	for buff in buffs:
		ids[str(buff.get("id", ""))] = true
	_assert(buffs.size() == 3, "Buff system should generate three buff options.")
	_assert(ids.size() == 3, "Generated buff choices should be unique.")


func test_elite_spawn_rules_start_on_floor_three() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	var floor_two: Dictionary = dungeon.get_floor_spawn_config(2)
	var floor_three: Dictionary = dungeon.get_floor_spawn_config(3)
	var floor_six: Dictionary = dungeon.get_floor_spawn_config(6)
	_assert(int(floor_two.get("elite_count", 0)) == 0, "Floor 2 should not spawn elites.")
	_assert(int(floor_three.get("elite_count", 0)) >= 0 and int(floor_three.get("elite_count", 0)) <= 1, "Floor 3 should allow at most one elite.")
	_assert(int(floor_six.get("elite_count", 0)) >= 1, "Floor 6 should guarantee at least one elite.")
	dungeon.queue_free()


func test_buff_applies_stat_change() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_damage: int = player.get_attack_damage()
	player.apply_buff("atk_up_1")
	_assert(player.get_attack_damage() > base_damage, "Applying an attack buff should increase player damage.")
	player.queue_free()
	await process_frame


func test_buffs_clear_on_dungeon_exit() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.apply_buff("hp_up")
	player.finish_dungeon_run(true)
	_assert(player.active_buff_ids.is_empty(), "Leaving the dungeon should clear active buffs.")
	player.queue_free()
	await process_frame


func test_death_removes_dungeon_loot() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 3)
	player.record_dungeon_loot("talent_shard", 3)
	player.finish_dungeon_run(false)
	_assert(player.inventory.get_item_count("talent_shard") == 0, "Death should remove tracked dungeon loot.")
	player.queue_free()
	await process_frame


func test_death_applies_durability_penalty() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.equipment_system.equip(ITEM_DATABASE.get_item("wood_sword"), "weapon")
	player.finish_dungeon_run(false)
	_assert(int(player.equipment_system.get_equipped("weapon").get("durability", 0)) == 40, "Death should reduce weapon durability by 20% of max.")
	player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All Phase 9 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
