extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TALENT_DATA := preload("res://scripts/talent/talent_data.gd")
const PLAYER_SAVE := preload("res://scripts/player/player_save.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	PLAYER_SAVE.clear_save()
	await test_unlocking_talent_requires_enough_shards()
	await test_unlocking_talent_requires_prerequisite()
	await test_talent_bonus_applies_to_player_stats()
	await test_multiple_branches_can_unlock()
	await test_talent_shards_are_spent()
	await test_talent_state_persists()
	test_talent_pool_has_three_branches()
	test_all_talent_nodes_have_data()
	await test_support_talent_increases_gather_bonus()
	await test_defense_talent_increases_hp()
	PLAYER_SAVE.clear_save()
	_report_results()


func test_talent_pool_has_three_branches() -> void:
	_assert(TALENT_DATA.get_branch_ids().size() == 3, "Talent tree should expose three branches.")


func test_all_talent_nodes_have_data() -> void:
	_assert(TALENT_DATA.get_all_talents().size() >= 15, "Talent tree should expose all configured nodes.")


func test_unlocking_talent_requires_enough_shards() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
	_assert(not player.unlock_talent("O1"), "Talent unlock should fail without enough shards.")
	player.queue_free()
	await process_frame


func test_unlocking_talent_requires_prerequisite() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 20)
	_assert(not player.unlock_talent("O2"), "Second talent should require its prerequisite.")
	player.queue_free()
	await process_frame


func test_talent_bonus_applies_to_player_stats() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 3)
	var before_attack: int = player.get_attack_damage()
	_assert(player.unlock_talent("O1"), "First offense talent should unlock with enough shards.")
	_assert(player.get_attack_damage() == before_attack + 5, "Attack talent should increase player damage by 5.")
	player.queue_free()
	await process_frame


func test_multiple_branches_can_unlock() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 6)
	_assert(player.unlock_talent("O1"), "Player should unlock offense talents.")
	_assert(player.unlock_talent("D1"), "Player should also unlock defense talents.")
	player.queue_free()
	await process_frame


func test_talent_shards_are_spent() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 3)
	player.unlock_talent("D1")
	_assert(player.inventory.get_item_count("talent_shard") == 0, "Unlocking a talent should spend the shard cost.")
	player.queue_free()
	await process_frame


func test_talent_state_persists() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 3)
	player.unlock_talent("S1")
	player.queue_free()
	await process_frame
	var player_two = PLAYER_SCENE.instantiate()
	root.add_child(player_two)
	await process_frame
	_assert(player_two.has_talent("S1"), "Unlocked talents should persist in the player save.")
	player_two.queue_free()
	await process_frame


func test_support_talent_increases_gather_bonus() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 8)
	player.unlock_talent("S1")
	player.unlock_talent("S2")
	_assert(player.player_stats.get_total_gather_bonus() == 1, "Gatherer should add one bonus resource.")
	player.queue_free()
	await process_frame


func test_defense_talent_increases_hp() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_hp: int = player.max_hp
	player.inventory.add_item("talent_shard", 3)
	player.unlock_talent("D1")
	_assert(player.max_hp == base_hp + 20, "Tough Skin should increase max HP by 20.")
	player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All talent tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
