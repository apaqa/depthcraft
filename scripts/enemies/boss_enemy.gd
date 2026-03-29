extends Enemy
class_name BossEnemy

const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const BUFF_SYSTEM = preload("res://scripts/dungeon/buff_system.gd")
const LEGENDARY_ITEMS: Script = preload("res://scripts/dungeon/legendary_items.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")

const AOE_COOLDOWN: float = 5.0
const AOE_RADIUS: float = 56.0

var floor_value: int = 1
var aoe_cooldown_left: float = AOE_COOLDOWN
var rewards_granted: bool = false
var buff_selection_requested: bool = false


func _ready() -> void:
	super._ready()
	scale = Vector2.ONE * 1.72
	if animated_sprite != null:
		animated_sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	floor_value = floor_number
	var normal_stats: Dictionary = _get_normal_enemy_stats(floor_number)
	max_hp = int(normal_stats["hp"]) * 10
	current_hp = max_hp
	damage = int(round(float(int(normal_stats["damage"])) * 1.8))
	speed = 32.0
	detection_range = 190.0
	attack_range = 32.0
	attack_cooldown = 1.1
	drop_table.clear()
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	aoe_cooldown_left = max(aoe_cooldown_left - delta, 0.0)
	if not ai_paused and not is_dead and aoe_cooldown_left <= 0.0:
		_perform_aoe()
		aoe_cooldown_left = AOE_COOLDOWN
	super._physics_process(delta)


func is_boss_enemy() -> bool:
	return true


func apply_knockback(direction: Vector2, force: float = 120.0) -> void:
	super.apply_knockback(direction, force * 0.08)


func die() -> void:
	if rewards_granted:
		return
	rewards_granted = true
	AudioManager.play_sfx("boss_death")
	_grant_rewards_to_players()
	super.die()
	_request_buff_selection()


func _drop_loot() -> void:
	pass


func _drop_gold_loot() -> void:
	pass


func _perform_aoe() -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > detection_range * 1.1:
		return
	_spawn_aoe_indicator()
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		if player_ref.global_position.distance_to(global_position) > AOE_RADIUS:
			continue
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(int(round(damage * 0.9)), (player_ref.global_position - global_position).normalized())


func _spawn_aoe_indicator() -> void:
	var ring: Line2D = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.78, 0.2, 0.95)
	ring.closed = true
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(Vector2.RIGHT.rotated(angle) * AOE_RADIUS)
	ring.points = points
	ring.global_position = global_position
	get_parent().add_child(ring)
	var tween: Tween = create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _grant_rewards_to_players() -> void:
	var equipment_reward: Dictionary = _generate_boss_equipment()
	var silver_amount: int = 10 + floor_value * 2
	var gold_amount: int = 1 if randf() <= minf(0.08 + float(floor_value) * 0.005, 0.22) else 0
	var shard_amount: int = 4 + int(floor_value / 5)
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		var inventory: Variant = player_ref.get("inventory")
		if inventory == null:
			continue
		_grant_stack(inventory, equipment_reward.duplicate(true))
		_grant_item(inventory, "silver", silver_amount)
		if gold_amount > 0:
			_grant_item(inventory, "gold", gold_amount)
		_grant_item(inventory, "talent_shard", shard_amount)
		if player_ref.has_method("record_dungeon_loot"):
			player_ref.record_dungeon_loot(str(equipment_reward.get("id", "")), 1)
			player_ref.record_dungeon_loot("silver", silver_amount)
			if gold_amount > 0:
				player_ref.record_dungeon_loot("gold", gold_amount)
			player_ref.record_dungeon_loot("talent_shard", shard_amount)
		if player_ref.has_method("_show_floating_text"):
			player_ref._show_floating_text(player_ref.global_position, "Boss Reward!", Color(1.0, 0.9, 0.3, 1.0))


func _grant_item(inventory, item_id: String, amount: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var achievement_manager: Variant = tree.root.get_node_or_null("/root/AchievementManager")
		if achievement_manager != null:
			achievement_manager.record_currency_gain(item_id, amount)
	if inventory.add_item(item_id, amount):
		return
	var fallback_stack: Dictionary = {
		"id": item_id,
		"name": item_id.replace("_", " ").capitalize(),
		"type": "resource",
		"quantity": amount,
		"max_stack": 9999,
	}
	_force_add_stack(inventory, fallback_stack)


func _grant_stack(inventory, stack: Dictionary) -> void:
	if inventory.add_stack(stack):
		return
	_force_add_stack(inventory, stack)


func _force_add_stack(inventory, stack: Dictionary) -> void:
	inventory.items.append(stack.duplicate(true))
	inventory.inventory_changed.emit()


func _generate_boss_equipment() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [name, floor_value, Time.get_ticks_usec()])
	if floor_value >= 29:
		var legendary: Dictionary = LEGENDARY_ITEMS.get_random_legendary(rng)
		if not legendary.is_empty():
			return legendary
	var boss_set_drop: Dictionary = ITEM_DATABASE.get_random_boss_set_item(floor_value, rng)
	if not boss_set_drop.is_empty() and rng.randf() <= 0.5:
		return boss_set_drop
	for _attempt in range(16):
		var reward: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(floor_value + 2, rng)
		var rarity: String = str(reward.get("rarity", "Common"))
		if rarity == "Epic" or rarity == "Legendary":
			return reward
	var fallback: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(floor_value + 3, rng)
	fallback["rarity"] = "Epic"
	fallback["color"] = DUNGEON_LOOT.get_rarity_color("Epic")
	return fallback


func _get_normal_enemy_stats(floor_number: int) -> Dictionary:
	if floor_number <= 3:
		return {"hp": 30, "damage": 8}
	if floor_number <= 6:
		return {"hp": 50, "damage": 12}
	if floor_number <= 10:
		return {"hp": 80, "damage": 18}
	return {"hp": 100 + floor_number * 5, "damage": 22 + floor_number * 2}


func _request_buff_selection() -> void:
	if buff_selection_requested:
		return
	var level: Variant = get_parent()
	while level != null and not level.has_signal("buff_selection_requested"):
		level = level.get_parent()
	if level == null or not level.has_signal("buff_selection_requested"):
		return
	buff_selection_requested = true
	if level.has_method("set_gameplay_paused"):
		level.set_gameplay_paused(true)
	var buff_options: Array[Dictionary] = BUFF_SYSTEM.generate_random_buffs(3)
	level.buff_selection_requested.emit(buff_options)
