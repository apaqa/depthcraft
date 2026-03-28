extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUNGEON_LEVEL_SCENE: PackedScene = preload("res://scenes/dungeon/dungeon_level.tscn")
const DUNGEON_GENERATOR_SCRIPT: Script = preload("res://scripts/dungeon/dungeon_generator.gd")
const DUNGEON_CHEST_SCRIPT: Script = preload("res://scripts/dungeon/dungeon_chest.gd")
const TIMED_TREASURE_ROOM_SCRIPT: Script = preload("res://scripts/dungeon/timed_treasure_room.gd")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const SHADOW_ASSASSIN_SCENE: PackedScene = preload("res://scenes/enemies/shadow_assassin_enemy.tscn")
const GARGOYLE_SCENE: PackedScene = preload("res://scenes/enemies/gargoyle_enemy.tscn")
const LAVA_GIANT_BOSS_SCRIPT: Script = preload("res://scripts/enemies/lava_giant_boss.gd")
const ABYSS_EYE_BOSS_SCRIPT: Script = preload("res://scripts/enemies/abyss_eye_boss.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	test_new_enemy_scene_stats()
	await test_slime_split_behavior()
	await test_gargoyle_vulnerability_window()
	await test_floor_fifteen_boss_variant()
	await test_floor_twenty_five_boss_variant_and_cover()
	await test_treasure_room_variant_spawns_timer_and_many_chests()
	test_generator_rolls_secret_merchant_and_trap_corridors()
	_report_results()


func test_new_enemy_scene_stats() -> void:
	var slime: Variant = SLIME_SCENE.instantiate()
	var assassin: Variant = SHADOW_ASSASSIN_SCENE.instantiate()
	var gargoyle: Variant = GARGOYLE_SCENE.instantiate()
	_assert(int(slime.get("max_hp")) == 20 and int(slime.get("damage")) == 4 and is_equal_approx(float(slime.get("speed")), 38.0), "Slime base stats should match the new encounter table.")
	_assert(int(assassin.get("max_hp")) == 14 and int(assassin.get("damage")) == 16 and is_equal_approx(float(assassin.get("speed")), 92.0), "Shadow assassin base stats should stay bursty and fragile.")
	_assert(int(gargoyle.get("max_hp")) == 48 and int(gargoyle.get("damage")) == 14 and is_equal_approx(float(gargoyle.get("speed")), 28.0), "Gargoyle base stats should reflect a tougher mid-late enemy.")


func test_slime_split_behavior() -> void:
	var player: Variant = PLAYER_SCENE.instantiate()
	var slime: Variant = SLIME_SCENE.instantiate()
	var loot_root: Node2D = Node2D.new()
	player.load_persistent_state_on_ready = false
	root.add_child(player)
	root.add_child(loot_root)
	root.add_child(slime)
	await process_frame
	slime.configure_for_floor(player, 4, loot_root)
	slime.take_damage(int(slime.get("current_hp")))
	await process_frame

	var split_count: int = 0
	for child: Node in root.get_children():
		if str(child.get("enemy_kind")) != "slime":
			continue
		if int(child.get("split_generation")) == 1:
			split_count += 1
	_assert(split_count == 2, "Large slime deaths should split into exactly two small slimes.")

	player.queue_free()
	loot_root.queue_free()
	if slime != null and is_instance_valid(slime):
		slime.queue_free()
	for child: Node in root.get_children():
		if str(child.get("enemy_kind")) == "slime":
			child.queue_free()
	await process_frame


func test_gargoyle_vulnerability_window() -> void:
	var player: Variant = PLAYER_SCENE.instantiate()
	var gargoyle: Variant = GARGOYLE_SCENE.instantiate()
	var loot_root: Node2D = Node2D.new()
	player.load_persistent_state_on_ready = false
	root.add_child(player)
	root.add_child(loot_root)
	root.add_child(gargoyle)
	await process_frame
	gargoyle.configure_for_floor(player, 22, loot_root)
	var hp_before: int = int(gargoyle.get("current_hp"))
	gargoyle.take_damage(10, Vector2.RIGHT)
	_assert(int(gargoyle.get("current_hp")) == hp_before, "Perched gargoyles should ignore damage.")
	gargoyle.call("_begin_glide")
	gargoyle.take_damage(10, Vector2.RIGHT)
	_assert(int(gargoyle.get("current_hp")) < hp_before, "Moving gargoyles should become vulnerable.")

	player.queue_free()
	loot_root.queue_free()
	gargoyle.queue_free()
	await process_frame


func test_floor_fifteen_boss_variant() -> void:
	var level: Variant = DUNGEON_LEVEL_SCENE.instantiate()
	var player: Variant = PLAYER_SCENE.instantiate()
	player.load_persistent_state_on_ready = false
	level.current_floor = 15
	root.add_child(level)
	root.add_child(player)
	await process_frame
	level.place_player(player)
	await process_frame
	_assert(level.boss_enemy_ref != null, "Floor 15 should spawn a dedicated boss.")
	_assert(level.boss_enemy_ref.get_script() == LAVA_GIANT_BOSS_SCRIPT, "Floor 15 should use the lava giant boss.")
	level.queue_free()
	player.queue_free()
	await process_frame


func test_floor_twenty_five_boss_variant_and_cover() -> void:
	var level: Variant = DUNGEON_LEVEL_SCENE.instantiate()
	var player: Variant = PLAYER_SCENE.instantiate()
	player.load_persistent_state_on_ready = false
	level.current_floor = 25
	root.add_child(level)
	root.add_child(player)
	await process_frame
	level.place_player(player)
	await process_frame
	_assert(level.boss_enemy_ref != null, "Floor 25 should spawn a dedicated boss.")
	_assert(level.boss_enemy_ref.get_script() == ABYSS_EYE_BOSS_SCRIPT, "Floor 25 should use the abyss eye boss.")
	var pillar_count: int = 0
	for child: Node in level.feature_root.get_children():
		if child.name == "AbyssPillar":
			pillar_count += 1
	_assert(pillar_count >= 3, "Abyss eye arenas should spawn cover pillars.")
	level.queue_free()
	player.queue_free()
	await process_frame


func test_treasure_room_variant_spawns_timer_and_many_chests() -> void:
	var level: Variant = DUNGEON_LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	var rooms: Array = level.floor_data.get("rooms", [])
	var room: Rect2i = rooms[0]
	level._spawn_treasure_room(room, 0)

	var chest_count: int = 0
	var timer_count: int = 0
	for child: Node in level.feature_root.get_children():
		if child.get_script() == DUNGEON_CHEST_SCRIPT:
			chest_count += 1
		if child.get_script() == TIMED_TREASURE_ROOM_SCRIPT:
			timer_count += 1
	_assert(chest_count >= 3, "Treasure room variants should spawn multiple chests.")
	_assert(timer_count >= 1, "Treasure room variants should attach a timer controller.")

	level.queue_free()
	await process_frame


func test_generator_rolls_secret_merchant_and_trap_corridors() -> void:
	var generator: Variant = DUNGEON_GENERATOR_SCRIPT.new()
	var found_secret_room: bool = false
	var found_trap_corridor: bool = false
	for seed_value: int in range(1, 180):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var floor_data: Dictionary = generator.generate_floor(12, rng)
		var room_types: Array = floor_data.get("room_types", [])
		if room_types.has("secret_merchant"):
			found_secret_room = true
		for corridor_feature_variant: Variant in floor_data.get("corridor_features", []):
			var corridor_feature: Dictionary = corridor_feature_variant as Dictionary
			if bool(corridor_feature.get("trap", false)):
				found_trap_corridor = true
		if found_secret_room and found_trap_corridor:
			break
	_assert(found_secret_room, "Dungeon generator should occasionally roll a secret merchant room.")
	_assert(found_trap_corridor, "Dungeon generator should occasionally roll a trap corridor.")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All dungeon expansion tests passed.")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)

	quit(1)
