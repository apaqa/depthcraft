extends CharacterBody2D

@export var speed: float = 80.0
@export var sprint_speed: float = 140.0

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const ATTACK_EFFECT_SCENE := preload("res://scenes/player/attack_effect.tscn")
const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")

signal interaction_prompt_changed(prompt_text: String)
signal interaction_prompt_cleared
signal portal_requested(target_level_id: String)
signal build_mode_changed(active: bool)
signal crafting_requested(facility)
signal storage_requested(facility)
signal repair_requested(facility)
signal hp_changed(current_hp: int, max_hp: int)
signal buffs_changed(active_buffs: Array)
signal died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var inventory = $Inventory
@onready var building_system = $BuildingSystem

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")

var max_hp: int = 100
var current_hp: int = 100
var last_interacted_resource = null
var build_mode: bool = false
var nearby_interactables: Array = []
var ui_blocked: bool = false
var in_menu: bool = false
var invincible_time_left: float = 0.0
var attack_cooldown_left: float = 0.0
var consumable_cooldown_left: float = 0.0
var is_dead: bool = false
var active_buff_ids: Array[String] = []
var dungeon_run_loot: Array[Dictionary] = []
var regen_tick_progress: float = 0.0
var damage_multiplier: float = 1.0
var crit_chance: float = 0.0
var attack_cooldown_multiplier: float = 1.0
var lifesteal_ratio: float = 0.0
var armor_reduction: float = 0.0
var dodge_chance: float = 0.0
var move_speed_multiplier: float = 1.0
var loot_drop_multiplier: float = 1.0
var aoe_attack_multiplier: float = 1.0
var bonus_max_hp: int = 0
var regen_amount: int = 0
var regen_interval: float = 3.0

const BASE_MAX_HP := 100
const BASE_ATTACK_DAMAGE := 15
const BASE_ATTACK_COOLDOWN := 0.4
const BANDAGE_COOLDOWN := 1.0


func _ready() -> void:
	_configure_input_actions()
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	building_system.build_state_changed.connect(_on_build_state_changed)
	_recalculate_buff_state()
	hp_changed.emit(current_hp, max_hp)


static func compute_input_vector(left_strength: float, right_strength: float, up_strength: float, down_strength: float) -> Vector2:
	var input_vector := Vector2(right_strength - left_strength, down_strength - up_strength)
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()
	return input_vector


func get_input_vector() -> Vector2:
	return compute_input_vector(
		Input.get_action_strength("move_left"),
		Input.get_action_strength("move_right"),
		Input.get_action_strength("move_up"),
		Input.get_action_strength("move_down")
	)


func apply_input_direction(input_direction: Vector2, move_speed: float = -1.0) -> void:
	if move_speed < 0.0:
		move_speed = speed
	velocity = input_direction * move_speed
	update_sprite_state(input_direction, move_speed > speed)


func update_sprite_state(input_direction: Vector2, is_sprinting: bool = false) -> void:
	var sprite := get_animated_sprite()
	if sprite == null:
		return

	if input_direction.x != 0.0:
		sprite.flip_h = input_direction.x < 0.0

	if input_direction.is_zero_approx():
		sprite.speed_scale = 1.0
		sprite.play("idle")
	else:
		sprite.speed_scale = 1.5 if is_sprinting else 1.0
		sprite.play("run")


func get_animated_sprite() -> AnimatedSprite2D:
	if animated_sprite != null:
		return animated_sprite
	return get_node_or_null("AnimatedSprite2D")


func _physics_process(_delta: float) -> void:
	if invincible_time_left > 0.0:
		invincible_time_left = max(invincible_time_left - _delta, 0.0)
	if attack_cooldown_left > 0.0:
		attack_cooldown_left = max(attack_cooldown_left - _delta, 0.0)
	if consumable_cooldown_left > 0.0:
		consumable_cooldown_left = max(consumable_cooldown_left - _delta, 0.0)

	if is_dead:
		velocity = Vector2.ZERO
		update_sprite_state(Vector2.ZERO)
		move_and_slide()
		return

	if in_menu:
		velocity = Vector2.ZERO
		update_sprite_state(Vector2.ZERO)
		move_and_slide()
		return

	if regen_amount > 0:
		regen_tick_progress += _delta
		if regen_tick_progress >= regen_interval:
			regen_tick_progress = 0.0
			heal(regen_amount)

	var input_direction := get_input_vector()
	var move_speed := (sprint_speed if Input.is_action_pressed("sprint") else speed) * move_speed_multiplier
	apply_input_direction(input_direction, move_speed)
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		building_system.toggle_debug_mode()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("dev_reset") or event.is_action_pressed("dev_reset_save"):
		return

	if event.is_action_pressed("toggle_build"):
		if building_system.toggle_build_mode():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("attack") and not build_mode and not ui_blocked and not is_dead:
		perform_attack()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("use_consumable") and not build_mode and not ui_blocked and not is_dead:
		use_first_consumable()
		get_viewport().set_input_as_handled()
		return

	if build_mode:
		if building_system.handle_input(event):
			get_viewport().set_input_as_handled()
		return

	if ui_blocked:
		return


func _unhandled_input(event: InputEvent) -> void:
	if build_mode or ui_blocked:
		return

	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("enter"):
		_try_secondary_interact()
		get_viewport().set_input_as_handled()


func _try_interact() -> void:
	var interactable = _get_closest_interactable()
	if interactable == null or not interactable.has_method("interact"):
		return

	if interactable.has_method("hit"):
		last_interacted_resource = interactable
	interactable.interact(self)


func _try_secondary_interact() -> void:
	var interactable = _get_closest_interactable()
	if interactable == null or not interactable.has_method("secondary_interact"):
		return
	interactable.secondary_interact(self)


func _on_interaction_area_entered(area: Area2D) -> void:
	var owner = area.get_parent()
	if owner == null or not owner.has_method("get_interaction_prompt"):
		return

	if not nearby_interactables.has(owner):
		nearby_interactables.append(owner)

	if owner.has_signal("gathered") and not owner.gathered.is_connected(_on_resource_gathered):
		owner.gathered.connect(_on_resource_gathered)
	if owner.has_signal("depleted") and not owner.depleted.is_connected(_on_resource_depleted):
		owner.depleted.connect(_on_resource_depleted)
	if owner.has_signal("respawned") and not owner.respawned.is_connected(_on_resource_respawned):
		owner.respawned.connect(_on_resource_respawned)
	_update_prompt()


func _on_interaction_area_exited(area: Area2D) -> void:
	var owner = area.get_parent()
	if owner != null and nearby_interactables.has(owner):
		nearby_interactables.erase(owner)
	_disconnect_resource_signals(owner)
	_update_prompt()


func _disconnect_resource_signals(resource) -> void:
	if resource == null:
		return
	if not resource.has_signal("gathered"):
		return
	if resource.gathered.is_connected(_on_resource_gathered):
		resource.gathered.disconnect(_on_resource_gathered)
	if resource.depleted.is_connected(_on_resource_depleted):
		resource.depleted.disconnect(_on_resource_depleted)
	if resource.respawned.is_connected(_on_resource_respawned):
		resource.respawned.disconnect(_on_resource_respawned)


func _on_resource_gathered(resource_id: String, quantity: int) -> void:
	var item_data: Dictionary = ITEM_DATABASE.get_item(resource_id)
	var display_name: String = str(item_data.get("name", resource_id.capitalize()))
	var source_position := global_position
	if last_interacted_resource != null:
		source_position = last_interacted_resource.global_position

	if inventory.add_item(resource_id, quantity):
		_show_floating_text(source_position, "+%d %s" % [quantity, display_name], Color(0.75, 1.0, 0.75, 1.0))
	else:
		_show_floating_text(source_position, "Bag Full", Color(1.0, 0.6, 0.6, 1.0))


func _on_resource_depleted() -> void:
	_update_prompt()


func _on_resource_respawned() -> void:
	_update_prompt()


func _show_floating_text(world_position: Vector2, text_value: String, color: Color) -> void:
	var floating_text = FLOATING_TEXT_SCENE.instantiate()
	floating_text.position = world_position + Vector2(0, -12)
	floating_text.display_text = text_value
	floating_text.text_color = color
	var floating_text_parent = get_tree().current_scene
	if floating_text_parent == null:
		floating_text_parent = get_tree().root
	floating_text_parent.add_child(floating_text)


func _update_prompt() -> void:
	if build_mode or ui_blocked:
		interaction_prompt_cleared.emit()
		return

	var interactable = _get_closest_interactable()
	if interactable != null:
		if interactable.has_method("get") and interactable.get("is_depleted") == true:
			interaction_prompt_cleared.emit()
			return
		interaction_prompt_changed.emit(interactable.get_interaction_prompt())
		return

	interaction_prompt_cleared.emit()


func _on_build_state_changed() -> void:
	build_mode = building_system.is_build_mode_active()
	build_mode_changed.emit(build_mode)
	_update_prompt()


func set_ui_blocked(blocked: bool) -> void:
	ui_blocked = blocked
	in_menu = blocked
	set_physics_process(true)
	_update_prompt()


func request_crafting_menu(facility) -> void:
	crafting_requested.emit(facility)


func request_storage_menu(facility) -> void:
	storage_requested.emit(facility)


func request_repair_menu(facility) -> void:
	repair_requested.emit(facility)


func take_damage(amount: int) -> void:
	if is_dead or invincible_time_left > 0.0:
		return
	if dodge_chance > 0.0 and randf() < dodge_chance:
		_show_floating_text(global_position, "Dodge", Color(0.75, 1.0, 1.0, 1.0))
		return
	var reduced_amount: int = max(int(round(float(amount) * (1.0 - armor_reduction))), 1)
	current_hp = max(current_hp - reduced_amount, 0)
	hp_changed.emit(current_hp, max_hp)
	invincible_time_left = 0.5
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.45, 0.45, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	if current_hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	_show_floating_text(global_position, "You Died", Color(1.0, 0.35, 0.35, 1.0))
	died.emit()


func heal_to_full() -> void:
	is_dead = false
	current_hp = max_hp
	invincible_time_left = 0.0
	regen_tick_progress = 0.0
	hp_changed.emit(current_hp, max_hp)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)


func perform_attack() -> void:
	if attack_cooldown_left > 0.0:
		return
	attack_cooldown_left = get_attack_cooldown_duration()
	_spawn_attack_effect()
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = Vector2(24, 20) * aoe_attack_multiplier
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(0.0, global_position + _get_attack_offset())
	query.collision_mask = 1
	var results := get_world_2d().direct_space_state.intersect_shape(query)
	var total_damage_dealt := 0
	for result in results:
		var collider = result.get("collider", null)
		if collider != null and collider.has_method("take_damage") and collider != self:
			var attack_damage := get_attack_damage()
			if crit_chance > 0.0 and randf() < crit_chance:
				attack_damage *= 2
			collider.take_damage(attack_damage)
			total_damage_dealt += attack_damage
	if lifesteal_ratio > 0.0 and total_damage_dealt > 0:
		heal(int(max(round(total_damage_dealt * lifesteal_ratio), 1.0)))


func _spawn_attack_effect() -> void:
	var attack_effect = ATTACK_EFFECT_SCENE.instantiate()
	var attack_effect_parent = get_parent()
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().current_scene
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().root
	attack_effect_parent.add_child(attack_effect)
	attack_effect.global_position = global_position + _get_attack_offset()
	if attack_effect.has_method("play_swing"):
		attack_effect.play_swing(animated_sprite.flip_h)


func _get_attack_offset() -> Vector2:
	return Vector2(-16 if animated_sprite.flip_h else 16, 2)


func _get_closest_interactable():
	var closest = null
	var closest_distance := INF
	for interactable in nearby_interactables:
		if interactable == null or not is_instance_valid(interactable):
			continue
		var distance := global_position.distance_squared_to(interactable.global_position)
		if distance < closest_distance:
			closest = interactable
			closest_distance = distance
	return closest


func _configure_input_actions() -> void:
	_set_key_action("sprint", KEY_SPACE)
	_set_key_action("debug_toggle", KEY_8)
	_set_key_action("dev_reset", KEY_0)
	_set_key_action("dev_reset_save", KEY_9)
	_set_key_action("dodge", KEY_SHIFT)
	_set_key_action("use_consumable", KEY_Q)


func _set_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)

	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func apply_buff(buff_id: String) -> bool:
	var buff: Dictionary = BUFF_SYSTEM.get_buff(buff_id)
	if buff.is_empty():
		return false
	active_buff_ids.append(buff_id)
	_recalculate_buff_state()
	buffs_changed.emit(get_active_buffs())
	return true


func clear_dungeon_buffs() -> void:
	active_buff_ids.clear()
	_recalculate_buff_state()
	buffs_changed.emit(get_active_buffs())


func get_active_buffs() -> Array[Dictionary]:
	var buffs: Array[Dictionary] = []
	for buff_id in active_buff_ids:
		buffs.append(BUFF_SYSTEM.get_buff(buff_id))
	return buffs


func get_attack_damage() -> int:
	return int(round(BASE_ATTACK_DAMAGE * damage_multiplier))


func get_attack_cooldown_duration() -> float:
	return BASE_ATTACK_COOLDOWN * attack_cooldown_multiplier


func get_loot_drop_multiplier() -> float:
	return loot_drop_multiplier


func start_dungeon_run() -> void:
	dungeon_run_loot.clear()
	clear_dungeon_buffs()


func finish_dungeon_run(safe_return: bool) -> void:
	if not safe_return:
		lose_dungeon_run_loot()
		apply_equipment_durability_penalty()
	dungeon_run_loot.clear()
	clear_dungeon_buffs()


func record_dungeon_loot(item_id: String, quantity: int) -> void:
	for entry in dungeon_run_loot:
		if str(entry.get("id", "")) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			return
	dungeon_run_loot.append({
		"id": item_id,
		"quantity": quantity,
	})


func lose_dungeon_run_loot() -> void:
	for entry in dungeon_run_loot:
		inventory.remove_item(str(entry.get("id", "")), int(entry.get("quantity", 0)))


func apply_equipment_durability_penalty() -> void:
	for stack in inventory.items:
		if str(stack.get("type", "")) != "equipment":
			continue
		if not stack.has("durability") or not stack.has("max_durability"):
			continue
		stack["durability"] = max(int(round(float(stack["durability"]) * 0.8)), 0)
	inventory.inventory_changed.emit()


func use_first_consumable() -> bool:
	if consumable_cooldown_left > 0.0:
		return false
	for stack in inventory.items:
		if str(stack.get("id", "")) != "bandage":
			continue
		if inventory.remove_item("bandage", 1):
			heal(20)
			consumable_cooldown_left = BANDAGE_COOLDOWN
			_show_floating_text(global_position, "+20 HP", Color(0.45, 1.0, 0.45, 1.0))
			return true
	return false


func _recalculate_buff_state() -> void:
	damage_multiplier = 1.0
	crit_chance = 0.0
	attack_cooldown_multiplier = 1.0
	lifesteal_ratio = 0.0
	armor_reduction = 0.0
	dodge_chance = 0.0
	move_speed_multiplier = 1.0
	loot_drop_multiplier = 1.0
	aoe_attack_multiplier = 1.0
	bonus_max_hp = 0
	regen_amount = 0
	regen_interval = 3.0
	for buff_id in active_buff_ids:
		match buff_id:
			"atk_up_1":
				damage_multiplier *= 1.15
			"atk_up_2":
				damage_multiplier *= 1.25
				move_speed_multiplier *= 0.9
			"crit_chance":
				crit_chance += 0.15
			"atk_speed":
				attack_cooldown_multiplier *= 0.7
			"lifesteal":
				lifesteal_ratio += 0.1
			"hp_up":
				bonus_max_hp += 30
			"armor":
				armor_reduction += 0.2
			"dodge_chance":
				dodge_chance += 0.15
			"regen":
				regen_amount += 1
				regen_interval = 3.0
			"speed_up":
				move_speed_multiplier *= 1.25
			"loot_up":
				loot_drop_multiplier *= 2.0
			"aoe_attack":
				aoe_attack_multiplier *= 1.5
	max_hp = BASE_MAX_HP + bonus_max_hp
	current_hp = min(current_hp, max_hp)
	hp_changed.emit(current_hp, max_hp)
