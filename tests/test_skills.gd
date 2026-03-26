extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_whirlwind_damages_nearby_enemy()
	await test_execute_arms_and_consumes()
	await test_war_cry_slows_enemy()
	await test_sprint_applies_multiplier()
	await test_treasure_hunter_reveals_chests()
	_report_results()


func test_whirlwind_damages_nearby_enemy() -> void:
	var player = PLAYER_SCENE.instantiate()
	var enemy = ENEMY_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	var skill_system = root.get_node("/root/SkillSystem")
	skill_system.bind_player(player)
	skill_system.unlock_skill("whirlwind")
	enemy.global_position = player.global_position + Vector2(20, 0)
	var before_hp: int = enemy.current_hp
	skill_system.use_skill_slot(0)
	_assert(enemy.current_hp < before_hp, "Whirlwind should damage nearby enemies.")
	player.queue_free()
	enemy.queue_free()
	await process_frame


func test_execute_arms_and_consumes() -> void:
	var player = PLAYER_SCENE.instantiate()
	var enemy = ENEMY_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	var skill_system = root.get_node("/root/SkillSystem")
	skill_system.bind_player(player)
	skill_system.unlock_skill("execute")
	enemy.global_position = player.global_position + Vector2(16, 0)
	enemy.current_hp = int(enemy.max_hp * 0.25)
	skill_system.set_equipped_skill_ids(["execute", "", ""])
	skill_system.use_skill_slot(0)
	_assert(player.execute_skill_armed, "Execute should arm the next attack.")
	player.perform_attack(Vector2.RIGHT)
	_assert(not player.execute_skill_armed, "Execute should be consumed by the next attack.")
	player.queue_free()
	enemy.queue_free()
	await process_frame


func test_war_cry_slows_enemy() -> void:
	var player = PLAYER_SCENE.instantiate()
	var enemy = ENEMY_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	var skill_system = root.get_node("/root/SkillSystem")
	skill_system.bind_player(player)
	skill_system.unlock_skill("war_cry")
	skill_system.set_equipped_skill_ids(["war_cry", "", ""])
	enemy.global_position = player.global_position + Vector2(25, 0)
	skill_system.use_skill_slot(0)
	_assert(is_equal_approx(enemy.slow_multiplier, 0.5), "War Cry should halve enemy speed.")
	player.queue_free()
	enemy.queue_free()
	await process_frame


func test_sprint_applies_multiplier() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var skill_system = root.get_node("/root/SkillSystem")
	skill_system.bind_player(player)
	skill_system.unlock_skill("sprint")
	skill_system.set_equipped_skill_ids(["sprint", "", ""])
	skill_system.use_skill_slot(0)
	_assert(is_equal_approx(player.sprint_skill_multiplier, 2.0), "Sprint should double movement speed multiplier.")
	player.queue_free()
	await process_frame


func test_treasure_hunter_reveals_chests() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(dungeon)
	root.add_child(player)
	await process_frame
	dungeon.player = player
	dungeon._spawn_treasure_room(Rect2i(Vector2i(5, 5), Vector2i(8, 8)))
	var skill_system = root.get_node("/root/SkillSystem")
	skill_system.bind_player(player)
	skill_system.bind_level(dungeon, "dungeon")
	skill_system.unlock_skill("treasure_hunter")
	skill_system.set_equipped_skill_ids(["treasure_hunter", "", ""])
	skill_system.use_skill_slot(0)
	var snapshot: Dictionary = dungeon.get_minimap_snapshot()
	_assert((snapshot.get("chest_positions", []) as Array).size() >= 1, "Treasure Hunter should reveal chest positions.")
	player.queue_free()
	dungeon.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All skill tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

