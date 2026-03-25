extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GOBLIN_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const SKELETON_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")
const ORC_SCENE := preload("res://scenes/enemies/shield_orc_enemy.tscn")
const BAT_SCENE := preload("res://scenes/enemies/bat_swarm_enemy.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_enemy_type_stats()
	test_equipment_generation_valid()
	test_rarity_by_affix_count()
	await test_consumable_heal_amount()
	await test_attack_knockback_pushes_enemy()
	await test_invincibility_frames_prevent_double_damage()
	await test_treasure_room_spawns_chest()
	await test_interaction_prompt_anchor_setup()
	_report_results()


func test_enemy_type_stats() -> void:
	var goblin = GOBLIN_SCENE.instantiate()
	var skeleton = SKELETON_SCENE.instantiate()
	var orc = ORC_SCENE.instantiate()
	var bat = BAT_SCENE.instantiate()
	_assert(goblin.max_hp == 25 and goblin.damage == 8 and is_equal_approx(goblin.speed, 50.0), "Goblin stats should match Phase 11 values.")
	_assert(skeleton.max_hp == 18 and skeleton.damage == 12 and is_equal_approx(skeleton.speed, 30.0), "Skeleton stats should match Phase 11 values.")
	_assert(orc.max_hp == 60 and orc.damage == 10 and is_equal_approx(orc.speed, 25.0), "Shield orc stats should match Phase 11 values.")
	_assert(bat.max_hp == 10 and bat.damage == 5 and is_equal_approx(bat.speed, 80.0), "Bat swarm unit stats should match Phase 11 values.")


func test_equipment_generation_valid() -> void:
	var item := DUNGEON_LOOT.generate_dungeon_equipment(6)
	_assert(str(item.get("type", "")) == "equipment", "Dungeon equipment should be typed as equipment.")
	_assert(["weapon", "helmet", "chest_armor", "boots", "accessory"].has(str(item.get("slot", ""))), "Dungeon equipment should roll a valid slot.")
	_assert(item.has("stats") and item.has("affixes") and item.has("rarity"), "Dungeon equipment should include stats, affixes, and rarity.")


func test_rarity_by_affix_count() -> void:
	_assert(DUNGEON_LOOT.determine_rarity(0) == "Common", "0 affixes should be Common.")
	_assert(DUNGEON_LOOT.determine_rarity(1) == "Uncommon", "1 affix should be Uncommon.")
	_assert(DUNGEON_LOOT.determine_rarity(2) == "Rare", "2 affixes should be Rare.")
	_assert(DUNGEON_LOOT.determine_rarity(3) == "Epic", "3 affixes should be Epic.")


func test_consumable_heal_amount() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.take_damage(40)
	player.inventory.add_item("bandage", 1)
	player.use_first_consumable()
	_assert(player.current_hp == player.max_hp - 20, "Bandage should heal 20 HP.")
	player.queue_free()
	await process_frame


func test_attack_knockback_pushes_enemy() -> void:
	var player = PLAYER_SCENE.instantiate()
	var enemy = GOBLIN_SCENE.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	enemy.global_position = player.global_position + Vector2(14, 0)
	var before_x: float = enemy.global_position.x
	player.perform_attack(Vector2.RIGHT)
	await process_frame
	enemy._physics_process(0.1)
	_assert(enemy.global_position.x > before_x, "Player attack should push the enemy away.")
	player.queue_free()
	enemy.queue_free()
	await process_frame


func test_invincibility_frames_prevent_double_damage() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var hp_before: int = player.current_hp
	player.take_damage(10, Vector2.LEFT)
	var hp_after_first: int = player.current_hp
	player.take_damage(10, Vector2.LEFT)
	_assert(hp_after_first < hp_before, "First hit should damage the player.")
	_assert(player.current_hp == hp_after_first, "Second hit during i-frames should not damage the player.")
	player.queue_free()
	await process_frame


func test_treasure_room_spawns_chest() -> void:
	var dungeon = DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon._spawn_treasure_room(Rect2i(Vector2i(5, 5), Vector2i(8, 8)))
	var has_chest := false
	for child in dungeon.feature_root.get_children():
		if child.has_method("get_interaction_prompt") and child.get_interaction_prompt() == "[E] Open Chest":
			has_chest = true
			break
	_assert(has_chest, "Treasure room should include at least one chest.")
	dungeon.queue_free()
	await process_frame


func test_interaction_prompt_anchor_setup() -> void:
	var hud_canvas = HUD_SCENE.instantiate()
	root.add_child(hud_canvas)
	await process_frame
	var prompt: Label = hud_canvas.get_node("HUD/InteractionPrompt")
	_assert(is_equal_approx(prompt.anchor_left, 0.3), "Interaction prompt should anchor left at 0.3.")
	_assert(is_equal_approx(prompt.anchor_right, 0.7), "Interaction prompt should anchor right at 0.7.")
	_assert(is_equal_approx(prompt.anchor_top, 0.85), "Interaction prompt should anchor top at 0.85.")
	_assert(is_equal_approx(prompt.anchor_bottom, 0.95), "Interaction prompt should anchor bottom at 0.95.")
	hud_canvas.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All Phase 11 tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
