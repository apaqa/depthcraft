extends CharacterBody2D
class_name Enemy

signal died(enemy_position: Vector2)
signal damaged(amount: int)

const LOOT_DROP_SCENE: PackedScene = preload("res://scenes/dungeon/loot_drop.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/projectile.tscn")
const MonsterPrefix: Script = preload("res://scripts/enemies/monster_prefix.gd")

@export var max_hp: int = 30
@export var damage: int = 8
@export var speed: float = 45.0
@export var detection_range: float = 150.0
@export var attack_range: float = 18.0
@export var attack_cooldown: float = 1.0
@export var keeps_distance: bool = false
@export var preferred_distance: float = 60.0
@export var is_ranged: bool = false
@export var enemy_kind: String = "goblin"
@export var drop_table: Array[Dictionary] = []
@export var front_guard_enabled: bool = false
@export var zigzag_strength: float = 18.0
@export var group_spawn_min: int = 1
@export var group_spawn_max: int = 1

var current_hp: int = 0
var target: CharacterBody2D = null
var attack_timer_left: float = 0.0
var difficulty_multiplier: float = 1.0
var loot_parent: Node = null
var ai_paused: bool = false
var base_max_hp: int = 0
var base_damage: int = 0
var base_speed: float = 0.0
var is_dead: bool = false
var is_alerted: bool = false
var debug_state: String = "idle"
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var hp_bar_root: Node2D = null
var hp_bar_bg: Polygon2D = null
var hp_bar_fill: Polygon2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var slow_time_left: float = 0.0
var slow_multiplier: float = 1.0
var _currency_floor_value: int = 1
var _prefixes: Array[String] = []
var _prefix_label: Label = null
var _stealth_timer: float = 0.0
var _stealth_active: bool = false
var _stealth_interval: float = 8.0
var _stealth_duration: float = 2.0
var _prefix_damage_reduction: float = 0.0
var _prefix_reflect_ratio: float = 0.0
# Blessing status effects
var burn_time_left: float = 0.0
var burn_dps: float = 0.0
var _burn_tick_timer: float = 0.0
var poison_stacks: int = 0
var poison_dps_per_stack: float = 0.0
var _poison_tick_timer: float = 0.0
var chill_stacks: int = 0
var chill_max_stacks: int = 3
var freeze_time_left: float = 0.0
var is_frozen: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	base_max_hp = max_hp
	base_damage = damage
	base_speed = speed
	current_hp = max_hp
	_setup_hp_bar()
	call_deferred("_find_player")
	if enemy_kind != "":
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex != null:
			codex.record_enemy_seen(enemy_kind)
	call_deferred("_update_prefix_label")


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	_currency_floor_value = max(floor_number, 1)
	if floor_number <= 3:
		max_hp = 30
		damage = 8
	elif floor_number <= 6:
		max_hp = 50
		damage = 12
	elif floor_number <= 10:
		max_hp = 80
		damage = 18
	else:
		max_hp = 100 + floor_number * 5
		damage = 22 + floor_number * 2
	current_hp = max_hp
	speed = speed * (1.0 + float(floor_number) * 0.05)
	_update_hp_bar()


func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return
	_tick_prefix_effects(delta)
	_tick_status_effects(delta)
	if is_frozen:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		else:
			velocity = Vector2.ZERO
			debug_state = "idle"
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	attack_timer_left = max(attack_timer_left - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	if slow_time_left > 0.0:
		slow_time_left = max(slow_time_left - delta, 0.0)
	else:
		slow_multiplier = 1.0

	var distance: float = global_position.distance_to(target.global_position)
	var effective_speed: float = speed * slow_multiplier
	if distance <= attack_range:
		is_alerted = true
		debug_state = "attack"
		velocity = Vector2.ZERO
		if attack_timer_left <= 0.0:
			_do_attack()
	elif distance <= detection_range or (is_alerted and distance <= detection_range * 3.0):
		is_alerted = true
		debug_state = "chase"
		var direction: Vector2 = (target.global_position - global_position).normalized()
		if keeps_distance and distance < preferred_distance:
			direction = -direction
		if enemy_kind == "bat":
			var perp: Vector2 = Vector2(-direction.y, direction.x)
			direction = (direction + perp * sin(Time.get_ticks_msec() / 130.0) * 0.55).normalized()
		if direction.length_squared() > 0.0:
			facing_direction = direction
		if global_position.distance_to(_last_position) < 1.0:
			_stuck_timer += delta
			if _stuck_timer > 0.5:
				var random_offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				velocity = (direction + random_offset).normalized() * effective_speed
				_stuck_timer = 0.0
			else:
				velocity = direction * effective_speed
		else:
			_stuck_timer = 0.0
			velocity = direction * effective_speed
	else:
		is_alerted = false
		debug_state = "idle"
		velocity = Vector2.ZERO

	if velocity.x != 0.0:
		animated_sprite.flip_h = velocity.x < 0.0
	velocity += knockback_velocity
	_update_animation(velocity)
	move_and_slide()
	_last_position = global_position


func _do_attack() -> void:
	_perform_attack()
	attack_timer_left = attack_cooldown


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_ranged:
		var projectile = PROJECTILE_SCENE.instantiate()
		var fire_direction: Vector2 = (target.global_position - global_position).normalized()
		projectile.setup(global_position + fire_direction * 20.0, fire_direction, damage)
		get_parent().add_child(projectile)
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, (target.global_position - global_position).normalized())


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	var final_amount: int = amount
	if front_guard_enabled and hit_direction.length_squared() > 0.0:
		var incoming_from_attacker: Vector2 = -hit_direction.normalized()
		if incoming_from_attacker.dot(facing_direction.normalized()) > 0.35:
			final_amount = int(ceil(final_amount * 0.5))
	# Armored prefix: reduce incoming damage
	if _prefix_damage_reduction > 0.0:
		final_amount = int(ceil(float(final_amount) * (1.0 - _prefix_damage_reduction)))
	current_hp -= final_amount
	damaged.emit(final_amount)
	# Thorned prefix: reflect damage to attacker
	if _prefix_reflect_ratio > 0.0 and target != null and is_instance_valid(target) and target.has_method("take_damage"):
		var reflect_dmg: int = int(round(float(final_amount) * _prefix_reflect_ratio))
		if reflect_dmg > 0:
			target.take_damage(reflect_dmg, Vector2.ZERO)
	_update_hp_bar()
	modulate = Color(1, 0.3, 0.3, 1)
	if hit_direction.length_squared() > 0.0:
		apply_knockback(hit_direction, 120.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	if current_hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	if not (has_method("is_boss_enemy") and bool(call("is_boss_enemy"))):
		AudioManager.play_sfx("enemy_death")
	debug_state = "dead"
	velocity = Vector2.ZERO
	var enemy_type: String = enemy_kind
	if enemy_type != "":
		QuestManager.update_quest_progress("kill_enemies", enemy_type, 1)
		var codex: Node = get_node_or_null("/root/CodexManager")
		if codex != null:
			codex.record_enemy_killed(enemy_type)
	if hp_bar_root != null:
		hp_bar_root.visible = false
	died.emit(global_position)
	_apply_death_prefix_effects()
	_drop_loot()
	_drop_gold_loot()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _tick_prefix_effects(delta: float) -> void:
	if not _prefixes.has("shadowed"):
		return
	_stealth_timer -= delta
	if _stealth_active:
		if _stealth_timer <= 0.0:
			_stealth_active = false
			modulate = Color.WHITE
			_stealth_timer = _stealth_interval
	else:
		if _stealth_timer <= 0.0:
			_stealth_active = true
			modulate = Color(1.0, 1.0, 1.0, 0.2)
			_stealth_timer = _stealth_duration


func _apply_death_prefix_effects() -> void:
	if _prefixes.has("explosive"):
		_do_explosion()
	if _prefixes.has("splitting"):
		_do_split()


func _do_explosion() -> void:
	if target == null or not is_instance_valid(target):
		return
	var explosion_radius: float = 48.0
	var explosion_damage: int = int(round(float(max_hp) * 0.3))
	if target.global_position.distance_to(global_position) <= explosion_radius:
		if target.has_method("take_damage"):
			target.take_damage(explosion_damage, (target.global_position - global_position).normalized())


func _do_split() -> void:
	if loot_parent == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for _i: int in range(2):
		var split_enemy: Enemy = duplicate(false) as Enemy
		if split_enemy == null:
			continue
		split_enemy.max_hp = int(round(float(max_hp) * 0.4))
		split_enemy.current_hp = split_enemy.max_hp
		split_enemy.damage = int(round(float(damage) * 0.6))
		split_enemy._prefixes = []
		split_enemy._prefix_damage_reduction = 0.0
		split_enemy._prefix_reflect_ratio = 0.0
		split_enemy.is_dead = false
		split_enemy.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		parent_node.add_child(split_enemy)
		split_enemy.target = target
		split_enemy.loot_parent = loot_parent


func set_ai_paused(paused: bool) -> void:
	ai_paused = paused


func _drop_loot() -> void:
	if loot_parent == null:
		return
	var loot_multiplier: float = 1.0
	if target != null and target.has_method("get_loot_drop_multiplier"):
		loot_multiplier = float(target.get_loot_drop_multiplier())
	var roll: float = randf()
	var running_total: float = 0.0
	for entry_variant in drop_table:
		var entry: Dictionary = entry_variant as Dictionary
		running_total += float(entry.get("chance", 0.0)) * loot_multiplier
		if roll > min(running_total, 1.0):
			continue
		var item_id: String = str(entry.get("id", ""))
		if item_id == "":
			return
		var drop = LOOT_DROP_SCENE.instantiate()
		drop.setup(item_id, int(entry.get("quantity", 1)))
		drop.global_position = global_position
		loot_parent.add_child(drop)
		return


func _drop_gold_loot() -> void:
	if not is_elite_enemy() and not is_boss_enemy() and randf() >= 0.25:
		return
	var currency_rewards: Array[Dictionary] = _build_currency_rewards(_currency_floor_value)
	for reward: Dictionary in currency_rewards:
		_drop_gold(str(reward.get("id", "")), int(reward.get("amount", 0)))
	if is_elite_enemy():
		var elite_bonus: Dictionary = _build_elite_currency_bonus(_currency_floor_value)
		if not elite_bonus.is_empty():
			_drop_gold(str(elite_bonus.get("id", "")), int(elite_bonus.get("amount", 0)))


func _drop_gold(coin_type: String, amount: int) -> void:
	if loot_parent == null or amount <= 0:
		return
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.setup(coin_type, amount)
	drop.global_position = global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	loot_parent.add_child(drop)


func _build_currency_rewards(target_floor: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if target_floor <= 5:
		rewards.append({"id": "wooden_coin", "amount": randi_range(1, 3)})
	elif target_floor <= 10:
		rewards.append({"id": "wooden_coin", "amount": randi_range(2, 5)})
		if randf() <= 0.35:
			rewards.append({"id": "copper", "amount": 1})
	elif target_floor <= 15:
		rewards.append({"id": "copper", "amount": randi_range(1, 2)})
	elif target_floor <= 20:
		rewards.append({"id": "copper", "amount": randi_range(2, 5)})
		if randf() <= 0.35:
			rewards.append({"id": "silver", "amount": 1})
	else:
		rewards.append({"id": "silver", "amount": randi_range(1, 2)})
	return rewards


func _build_elite_currency_bonus(target_floor: int) -> Dictionary:
	if target_floor <= 10:
		return {"id": "copper", "amount": randi_range(3, 8)}
	if target_floor <= 20:
		return {"id": "silver", "amount": randi_range(1, 2)}
	return {"id": "gold", "amount": 1}


func is_elite_enemy() -> bool:
	return false


func is_boss_enemy() -> bool:
	return false


func _setup_hp_bar() -> void:
	hp_bar_root = Node2D.new()
	hp_bar_root.position = Vector2(-12, -20)
	hp_bar_root.visible = false
	add_child(hp_bar_root)

	hp_bar_bg = Polygon2D.new()
	hp_bar_bg.color = Color(0.12, 0.12, 0.16, 0.9)
	hp_bar_bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(24, 0), Vector2(24, 4), Vector2(0, 4)])
	hp_bar_root.add_child(hp_bar_bg)

	hp_bar_fill = Polygon2D.new()
	hp_bar_fill.color = Color(0.88, 0.18, 0.18, 1.0)
	hp_bar_root.add_child(hp_bar_fill)
	_update_hp_bar()


func _update_hp_bar() -> void:
	if hp_bar_root == null or hp_bar_fill == null:
		return
	var ratio: float = clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	hp_bar_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(24.0 * ratio, 0), Vector2(24.0 * ratio, 4), Vector2(0, 4)])
	hp_bar_root.visible = current_hp < max_hp and current_hp > 0


func apply_prefixes(prefix_ids: Array) -> void:
	_prefixes.clear()
	for pid_variant: Variant in prefix_ids:
		var pid: String = str(pid_variant)
		if pid == "":
			continue
		_prefixes.append(pid)
		_apply_single_prefix_stats(pid)
	_update_prefix_label()
	_update_hp_bar()


func _apply_single_prefix_stats(prefix_id: String) -> void:
	match prefix_id:
		"frenzied":
			attack_cooldown = maxf(attack_cooldown / 1.5, 0.3)
			damage = int(round(float(damage) * 1.2))
		"armored":
			max_hp = int(round(float(max_hp) * 1.43))
			current_hp = max_hp
			_prefix_damage_reduction = 0.3
		"thorned":
			_prefix_reflect_ratio = 0.15
		"shadowed":
			_stealth_interval = 8.0
			_stealth_duration = 2.0
			_stealth_timer = _stealth_interval


func _update_prefix_label() -> void:
	var is_boss: bool = is_boss_enemy()
	var is_elite: bool = is_elite_enemy()

	# Determine label color
	var label_color: Color = Color(1.0, 0.6, 0.1, 1.0)
	if is_boss:
		label_color = Color(1.0, 0.2, 0.2, 1.0)
	elif is_elite:
		label_color = Color(1.0, 0.9, 0.0, 1.0)
	elif not _prefixes.is_empty():
		label_color = MonsterPrefix.get_prefix_color(str(_prefixes[0]))

	# Build prefix portion of the name
	var prefix_names: Array[String] = []
	for pid: String in _prefixes:
		var zh_name: String = MonsterPrefix.get_prefix_display_name(pid)
		if zh_name != "":
			prefix_names.append(zh_name)

	# Build kind name
	var kind_key: String = "enemy_" + enemy_kind
	var kind_name: String = LocaleManager.L(kind_key)
	if kind_name == kind_key:
		kind_name = enemy_kind

	# Compose display text
	var display_name: String = ""
	if not prefix_names.is_empty():
		display_name = " ".join(prefix_names) + " " + kind_name
	elif is_boss or is_elite:
		display_name = kind_name
	else:
		# Plain enemy with no prefixes — no label needed
		if _prefix_label != null and is_instance_valid(_prefix_label):
			_prefix_label.queue_free()
			_prefix_label = null
		return

	if _prefix_label == null or not is_instance_valid(_prefix_label):
		_prefix_label = Label.new()
		_prefix_label.add_theme_constant_override("outline_size", 2)
		_prefix_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_prefix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prefix_label.position = Vector2(-24, -30)
		add_child(_prefix_label)

	var font_size: int = 11 if is_boss else 9
	_prefix_label.add_theme_font_size_override("font_size", font_size)
	_prefix_label.text = display_name
	_prefix_label.add_theme_color_override("font_color", label_color)


func _update_animation(direction: Vector2) -> void:
	if direction.length() > 0.1:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func apply_knockback(direction: Vector2, force: float = 120.0) -> void:
	if direction.length_squared() <= 0.0:
		return
	knockback_velocity += direction.normalized() * force


func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = clampf(multiplier, 0.1, 1.0)
	slow_time_left = max(duration, 0.0)


func apply_burn(dps: float, duration: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time_left = maxf(burn_time_left, duration)
	_burn_tick_timer = 0.0


func apply_poison(dps_per_stack: float, max_stacks: int) -> void:
	poison_stacks = mini(poison_stacks + 1, max_stacks)
	poison_dps_per_stack = dps_per_stack
	_poison_tick_timer = 0.0


func apply_chill(max_stacks_val: int, freeze_duration: float) -> void:
	if is_frozen:
		return
	chill_max_stacks = max_stacks_val
	chill_stacks += 1
	if chill_stacks >= chill_max_stacks:
		is_frozen = true
		freeze_time_left = freeze_duration
		chill_stacks = 0
		apply_slow(0.0, freeze_duration)


func is_enemy_frozen() -> bool:
	return is_frozen


func _tick_status_effects(delta: float) -> void:
	if burn_time_left > 0.0:
		burn_time_left = maxf(burn_time_left - delta, 0.0)
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 1.0
			var bdmg: int = maxi(int(round(burn_dps)), 1)
			take_damage(bdmg, Vector2.ZERO)
		if burn_time_left <= 0.0:
			burn_dps = 0.0
	if poison_stacks > 0:
		_poison_tick_timer -= delta
		if _poison_tick_timer <= 0.0:
			_poison_tick_timer = 1.0
			var pdmg: int = maxi(int(round(poison_dps_per_stack * float(poison_stacks))), 1)
			take_damage(pdmg, Vector2.ZERO)
	if is_frozen:
		freeze_time_left = maxf(freeze_time_left - delta, 0.0)
		if freeze_time_left <= 0.0:
			is_frozen = false
			slow_multiplier = 1.0
