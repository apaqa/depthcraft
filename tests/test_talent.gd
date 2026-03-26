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
	test_branch_layout_sizes()
	await test_branch_unlock_requires_main_gate()
	await test_support_talent_increases_gather_bonus()
	await test_defense_talent_increases_hp()
	PLAYER_SAVE.clear_save()
	_report_results()


func test_talent_pool_has_three_branches() -> void:
	_assert(TALENT_DATA.get_branch_ids().size() == 3, "Talent tree should expose three branches.")


func test_all_talent_nodes_have_data() -> void:
	_assert(TALENT_DATA.get_all_talents().size() == 78, "Talent tree should expose 78 configured nodes.")


func test_branch_layout_sizes() -> void:
	_assert(TALENT_DATA.get_sub_branch_talents("offense", "main").size() == 10, "Offense main line should have 10 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("offense", "crit").size() == 8, "Offense crit branch should have 8 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("offense", "dot").size() == 8, "Offense damage-over-time branch should have 8 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("defense", "main").size() == 10, "Defense main line should have 10 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("defense", "block").size() == 8, "Defense block branch should have 8 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("defense", "regen").size() == 8, "Defense regen branch should have 8 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("support", "main").size() == 10, "Support main line should have 10 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("support", "speed").size() == 8, "Support speed branch should have 8 nodes.")
	_assert(TALENT_DATA.get_sub_branch_talents("support", "explore").size() == 8, "Support exploration branch should have 8 nodes.")


func test_branch_unlock_requires_main_gate() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 20)
	_assert(not player.unlock_talent("O11"), "Crit branch should stay locked until O5 is unlocked.")
	for talent_id in ["O1", "O2", "O3", "O4", "O5"]:
		_assert(player.unlock_talent(talent_id), "%s should unlock along the offense main line." % talent_id)
	_assert(player.unlock_talent("O11"), "Crit branch should unlock after O5 is learned.")
	player.queue_free()
	await process_frame


func test_unlocking_talent_requires_enough_shards() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
	_assert(player.unlock_talent("O1"), "O1 should unlock with exactly enough shards.")
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
	player.inventory.add_item("talent_shard", 2)
	var before_attack: int = player.get_attack_damage()
	_assert(player.unlock_talent("O1"), "First offense talent should unlock with enough shards.")
	_assert(player.get_attack_damage() == before_attack + 3, "Attack talent should increase player damage by 3.")
	player.queue_free()
	await process_frame


func test_multiple_branches_can_unlock() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 4)
	_assert(player.unlock_talent("O1"), "Player should unlock offense talents.")
	_assert(player.unlock_talent("D1"), "Player should also unlock defense talents.")
	player.queue_free()
	await process_frame


func test_talent_shards_are_spent() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 1)
	player.unlock_talent("D1")
	_assert(player.inventory.get_item_count("talent_shard") == 0, "Unlocking a talent should spend the shard cost.")
	player.queue_free()
	await process_frame


func test_talent_state_persists() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("talent_shard", 2)
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
	player.inventory.add_item("talent_shard", 5)
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
	player.inventory.add_item("talent_shard", 2)
	player.unlock_talent("D1")
	_assert(player.max_hp == base_hp + 15, "Tough Skin should increase max HP by 15.")
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
