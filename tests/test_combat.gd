extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/enemies/projectile.tscn")
const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_enemy_takes_damage()
	await test_enemy_dies_at_zero_hp()
	await test_player_takes_damage()
	await test_player_dies_at_zero_hp()
	await test_player_attack_spawns_visual()
	await test_projectile_deals_damage_on_hit()
	await test_loot_drop_created_on_enemy_death()
	_report_results()


func test_enemy_takes_damage() -> void:
	var enemy = MELEE_ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	await process_frame
	var hp_before: int = enemy.current_hp
	enemy.take_damage(5)
	_assert(enemy.current_hp == hp_before - 5, "Enemy should lose HP when damaged.")
	enemy.queue_free()
	await process_frame


func test_enemy_dies_at_zero_hp() -> void:
	var enemy = MELEE_ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	await process_frame
	enemy.take_damage(enemy.current_hp)
	_assert(enemy.state == enemy.State.DEAD, "Enemy should enter the DEAD state at zero HP.")
	await process_frame


func test_player_takes_damage() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.take_damage(12)
	_assert(player.current_hp == player.max_hp - 12, "Player should lose HP when taking damage.")
	player.queue_free()
	await process_frame


func test_player_dies_at_zero_hp() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.take_damage(player.max_hp)
	_assert(player.is_dead, "Player should be marked dead at zero HP.")
	player.queue_free()
	await process_frame


func test_player_attack_spawns_visual() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.perform_attack()
	await process_frame
	_assert(_find_attack_effect() != null, "Player attack should spawn a visible attack effect.")
	player.queue_free()
	await process_frame


func test_projectile_deals_damage_on_hit() -> void:
	var player = PLAYER_SCENE.instantiate()
	var projectile = PROJECTILE_SCENE.instantiate()
	root.add_child(player)
	root.add_child(projectile)
	await process_frame
	var hp_before: int = player.current_hp
	projectile._on_body_entered(player)
	_assert(player.current_hp < hp_before, "Projectile should damage the player on hit.")
	await process_frame
	player.queue_free()
	await process_frame


func test_loot_drop_created_on_enemy_death() -> void:
	var player = PLAYER_SCENE.instantiate()
	var loot_root := Node2D.new()
	var enemy = RANGED_ENEMY_SCENE.instantiate()
	root.add_child(player)
	root.add_child(loot_root)
	root.add_child(enemy)
	await process_frame
	seed(1)
	enemy.configure_for_floor(player, 1, loot_root)
	enemy.take_damage(enemy.current_hp)
	await process_frame
	_assert(loot_root.get_child_count() >= 1, "Enemy death should create at least one loot drop when the roll succeeds.")
	for child in loot_root.get_children():
		child.queue_free()
	loot_root.queue_free()
	player.queue_free()
	await process_frame


func _find_attack_effect() -> Node:
	for child in root.get_children():
		if child.name == "AttackEffect":
			return child
	return null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All combat tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
