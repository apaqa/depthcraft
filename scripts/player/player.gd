extends CharacterBody2D

@export var speed: float = 80.0
@export var sprint_speed: float = 140.0

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const ATTACK_EFFECT_SCENE = preload("res://scenes/player/attack_effect.tscn")
const BUFF_SYSTEM = preload("res://scripts/dungeon/buff_system.gd")
const TALENT_DATA = preload("res://scripts/talent/talent_data.gd")
const PLAYER_SAVE = preload("res://scripts/player/player_save.gd")

signal interaction_prompt_changed(prompt_text: String)
signal interaction_prompt_cleared
signal portal_requested(target_level_id: String, start_floor: int)
signal build_mode_changed(active: bool)
signal crafting_requested(facility)
signal storage_requested(facility)
signal repair_requested(facility)
signal talent_requested(facility)
signal equipment_panel_requested
signal tavern_requested(facility)
signal hp_changed(current_hp: int, max_hp: int)
signal buffs_changed(active_buffs: Array)
signal stats_changed
signal died
signal status_message_requested(message: String, color: Color, duration: float)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var inventory: Inventory = $Inventory
@onready var building_system: BuildingSystem = $BuildingSystem
@onready var player_stats: Node = $PlayerStats
@onready var equipment_system: Node = $EquipmentSystem
@onready var player_camera: Camera2D = $Camera2D

const FLOATING_TEXT_SCENE = preload("res://scenes/ui/floating_text.tscn")
const CLASS_VISUAL_PREFIXES: Dictionary = {
	"warrior": "knight_m",
	"mage": "wizzard_m",
	"ranger": "elf_m",
}
const CLASS_IDLE_ANIMATION_SPEED: float = 8.0
const CLASS_RUN_ANIMATION_SPEED: float = 10.0

var max_hp: int = 100
var current_hp: int = 100
var last_interacted_resource: Variant = null
var build_mode: bool = false
var nearby_interactables: Array = []
var ui_blocked: bool = false
var in_menu: bool = false
var invincible_time_left: float = 0.0
var attack_cooldown_left: float = 0.0
var consumable_cooldown_left: float = 0.0
var consumable_q_id: String = ""
var consumable_r_id: String = ""
var is_dead: bool = false
var active_buff_ids: Array[String] = []
var unlocked_talents: Array[String] = []
var dungeon_run_loot: Array[Dictionary] = []
var regen_tick_progress: float = 0.0
var damage_multiplier: float = 1.0
var crit_chance_bonus: float = 0.0
var attack_cooldown_multiplier: float = 1.0
var lifesteal_ratio: float = 0.0
var armor_reduction: float = 0.0
var dodge_chance: float = 0.0
var move_speed_multiplier: float = 1.0
var loot_drop_multiplier: float = 1.0
var aoe_attack_multiplier: float = 1.0
var bonus_max_hp: int = 0
var buff_regen_amount: int = 0
var buff_regen_interval: float = 3.0
var undying_will_available: bool = false
var network_peer_id: int = 1
var load_persistent_state_on_ready: bool = true
var knockback_velocity: Vector2 = Vector2.ZERO
var iframes_flash_accumulator: float = 0.0
var equipment_lifesteal_ratio: float = 0.0
var torch_light_time_left: float = 0.0
var last_attack_direction: Vector2 = Vector2.RIGHT
var execute_skill_armed: bool = false
var sprint_skill_time_left: float = 0.0
var sprint_skill_multiplier: float = 1.0
var sprint_afterimage_timer: float = 0.0
var dungeon_max_hp_penalty: int = 0

@onready var torch_light: PointLight2D = PointLight2D.new()

const BASE_ATTACK_COOLDOWN = 0.4
const BANDAGE_COOLDOWN = 1.0


func _ready() -> void:
	add_to_group("player")
	safe_margin = 0.001
	_configure_input_actions()
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	building_system.build_state_changed.connect(_on_build_state_changed)
	player_stats.stats_changed.connect(_on_player_stats_changed)
	equipment_system.equipment_changed.connect(_on_equipment_changed)
	if load_persistent_state_on_ready:
		_load_persistent_state()
	var _class_system: Node = get_node_or_null("/root/ClassSystem")
	if _class_system != null:
		_class_system.apply_to_stats(player_stats)
	refresh_class_visuals()
	_recalculate_buff_state()
	_refresh_all_stats()
	_setup_torch_light()
	configure_for_network_role(load_persistent_state_on_ready)


func refresh_class_visuals() -> void:
	var sprite: AnimatedSprite2D = get_animated_sprite()
	if sprite == null:
		return
	var current_animation: StringName = sprite.animation if sprite.animation != StringName() else &"idle"
	sprite.sprite_frames = _build_class_sprite_frames(_get_current_class_id())
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(current_animation):
		sprite.play(String(current_animation))
	else:
		sprite.play("idle")


func _get_current_class_id() -> String:
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	if class_system != null:
		var class_id_value: Variant = class_system.get("current_class_id")
		if class_id_value != null and str(class_id_value) != "":
			return str(class_id_value)
	return "warrior"


func _build_class_sprite_frames(class_id: String) -> SpriteFrames:
	var resolved_class_id: String = class_id if CLASS_VISUAL_PREFIXES.has(class_id) else "warrior"
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var prefix: String = str(CLASS_VISUAL_PREFIXES.get(resolved_class_id, "knight_m"))
	_append_class_animation_frames(sprite_frames, "idle", prefix, CLASS_IDLE_ANIMATION_SPEED)
	_append_class_animation_frames(sprite_frames, "run", prefix, CLASS_RUN_ANIMATION_SPEED)
	return sprite_frames


func _append_class_animation_frames(sprite_frames: SpriteFrames, animation_name: String, prefix: String, animation_speed: float) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name, animation_speed)
	for frame_index: int in range(4):
		var frame_path: String = "res://assets/%s_%s_anim_f%d.png" % [prefix, animation_name, frame_index]
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			sprite_frames.add_frame(animation_name, frame_texture)


static func compute_input_vector(left_strength: float, right_strength: float, up_strength: float, down_strength: float) -> Vector2:
	var input_vector: Vector2 = Vector2(right_strength - left_strength, down_strength - up_strength)
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
	var sprite: AnimatedSprite2D = get_animated_sprite()
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


func _physics_process(delta: float) -> void:
	if invincible_time_left > 0.0:
		invincible_time_left = max(invincible_time_left - delta, 0.0)
		iframes_flash_accumulator += delta
		if iframes_flash_accumulator >= 0.1:
			iframes_flash_accumulator = 0.0
			animated_sprite.visible = not animated_sprite.visible
	else:
		animated_sprite.visible = true
		iframes_flash_accumulator = 0.0
	if attack_cooldown_left > 0.0:
		attack_cooldown_left = max(attack_cooldown_left - delta, 0.0)
	if consumable_cooldown_left > 0.0:
		consumable_cooldown_left = max(consumable_cooldown_left - delta, 0.0)
	if torch_light_time_left > 0.0:
		torch_light_time_left = max(torch_light_time_left - delta, 0.0)
		torch_light.visible = true
	else:
		torch_light.visible = false
	if sprint_skill_time_left > 0.0:
		sprint_skill_time_left = max(sprint_skill_time_left - delta, 0.0)
		sprint_afterimage_timer += delta
		if sprint_afterimage_timer >= 0.1:
			sprint_afterimage_timer = 0.0
			_spawn_afterimage()
	else:
		sprint_skill_multiplier = 1.0
		sprint_afterimage_timer = 0.0
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

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

	var total_regen: int = player_stats.get_regen_amount() + buff_regen_amount
	var total_regen_interval: float = min(player_stats.get_regen_interval(), buff_regen_interval)
	if total_regen > 0:
		regen_tick_progress += delta
		if regen_tick_progress >= total_regen_interval:
			regen_tick_progress = 0.0
			heal(total_regen)

	var input_direction: Vector2 = get_input_vector()
	var base_speed_value: float = player_stats.get_total_speed()
	var move_speed_value: float = (sprint_speed if Input.is_action_pressed("sprint") else base_speed_value) * move_speed_multiplier * sprint_skill_multiplier
	velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	apply_input_direction(input_direction, move_speed_value)
	velocity += knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	_broadcast_state()
	if not nearby_interactables.is_empty():
		_update_prompt()


func _input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	if event.is_action_pressed("dev_reset") or event.is_action_pressed("dev_reset_save") or event.is_action_pressed("dev_class_reset"):
		return

	if event.is_action_pressed("toggle_build"):
		if building_system.toggle_build_mode():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_equipment") and not build_mode and not is_dead:
		equipment_panel_requested.emit()
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
	if event.is_action_pressed("use_consumable_2") and not build_mode and not ui_blocked and not is_dead:
		use_second_consumable()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skill_slot_1") and not build_mode and not ui_blocked and not is_dead:
		var skill_system = _skill_system()
		if skill_system != null:
			skill_system.use_skill_slot(0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skill_slot_2") and not build_mode and not ui_blocked and not is_dead:
		var skill_system = _skill_system()
		if skill_system != null:
			skill_system.use_skill_slot(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skill_slot_3") and not build_mode and not ui_blocked and not is_dead:
		var skill_system = _skill_system()
		if skill_system != null:
			skill_system.use_skill_slot(2)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pickup_loot") and not build_mode and not is_dead:
		_pickup_nearby_loot()
		get_viewport().set_input_as_handled()
		return

	if build_mode:
		if building_system.handle_input(event):
			get_viewport().set_input_as_handled()
		return

	if ui_blocked:
		return


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if event.is_action_pressed("debug_toggle"):
		_toggle_debug_mode_and_grant_resources()
		get_viewport().set_input_as_handled()
		return
	if build_mode or ui_blocked:
		return

	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("enter"):
		_try_secondary_interact()
		get_viewport().set_input_as_handled()


func _toggle_debug_mode_and_grant_resources() -> void:
	if building_system != null:
		building_system.toggle_debug_mode()
	var debug_resource_entries: Array[Dictionary] = [
		{"id": "gold", "amount": 100},
		{"id": "silver", "amount": 100},
		{"id": "copper", "amount": 100},
		{"id": "wood", "amount": 99},
		{"id": "stone", "amount": 99},
		{"id": "iron_ore", "amount": 99},
		{"id": "fiber", "amount": 99},
		{"id": "wheat", "amount": 99},
		{"id": "talent_shard", "amount": 99},
	]
	for entry: Dictionary in debug_resource_entries:
		var item_id: String = str(entry.get("id", ""))
		var amount: int = int(entry.get("amount", 0))
		if item_id != "" and amount > 0:
			inventory.add_item(item_id, amount)
	print("DEBUG: Added currency and test resources")


func _try_interact() -> void:
	var interactable = _get_closest_interactable()
	if interactable == null or not interactable.has_method("interact"):
		return
	if _interaction_requires_core(interactable):
		show_status_message("?????????", Color(1.0, 0.65, 0.4, 1.0))
		return
	if interactable.has_method("hit"):
		last_interacted_resource = interactable
	interactable.interact(self)


func _try_secondary_interact() -> void:
	var interactable = _get_closest_interactable()
	if interactable == null or not interactable.has_method("secondary_interact"):
		return
	interactable.secondary_interact(self)


func _pickup_nearby_loot() -> void:
	var pickup_radius: float = 64.0
	var drops: Array = get_tree().get_nodes_in_group("loot_drop")
	print("F pressed, searching loot... found ", drops.size(), " drops in group")
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		var drop_node: Node2D = drop as Node2D
		if drop_node == null:
			continue
		var dist: float = global_position.distance_to(drop_node.global_position)
		print("Found loot: ", drop_node.name, " dist=", dist, " radius=", pickup_radius)
		if dist <= pickup_radius:
			if drop_node.has_method("try_pickup"):
				drop_node.try_pickup(self)


func _interaction_requires_core(interactable) -> bool:
	if building_system == null or building_system.active_level_id != "overworld":
		return false
	if not interactable.has_method("requires_home_core"):
		return false
	return interactable.requires_home_core() and not building_system.has_functional_core()


func _on_interaction_area_entered(area: Area2D) -> void:
	var owner = area.get_parent()
	if owner == null or not owner.has_method("get_interaction_prompt"):
		if area.has_method("get_interaction_prompt"):
			owner = area
		else:
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
	if owner == null or not owner.has_method("get_interaction_prompt"):
		if area.has_method("get_interaction_prompt"):
			owner = area
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
	var total_quantity: int = quantity + player_stats.get_total_gather_bonus()
	var item_data: Dictionary = ITEM_DATABASE.get_item(resource_id)
	var display_name: String = str(item_data.get("name", ITEM_DATABASE.get_display_name(resource_id)))
	var source_position: Vector2 = global_position
	if last_interacted_resource != null:
		source_position = last_interacted_resource.global_position
	if inventory.add_item(resource_id, total_quantity):
		_show_floating_text(source_position, "+%d %s" % [total_quantity, display_name], Color(0.75, 1.0, 0.75, 1.0))
	else:
		_show_floating_text(source_position, LocaleManager.L("bag_full"), Color(1.0, 0.6, 0.6, 1.0))


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


func request_talent_menu(facility) -> void:
	talent_requested.emit(facility)


func request_tavern_menu(facility) -> void:
	tavern_requested.emit(facility)


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead or invincible_time_left > 0.0:
		return
	if dodge_chance > 0.0 and randf() < dodge_chance:
		_show_floating_text(global_position, "Dodge", Color(0.75, 1.0, 1.0, 1.0))
		return
	if player_stats.get_block_chance() > 0.0 and randf() < player_stats.get_block_chance():
		_show_floating_text(global_position, "Block", Color(0.7, 0.85, 1.0, 1.0))
		return
	var defense_value: int = player_stats.get_total_defense()
	var reduced_amount: int = max(int(round(float(max(amount - defense_value, 1)) * (1.0 - armor_reduction))), 1)
	current_hp = max(current_hp - reduced_amount, 0)
	equipment_system.consume_damage_durability()
	hp_changed.emit(current_hp, max_hp)
	invincible_time_left = 0.8
	apply_knockback(hit_direction, 110.0)
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.45, 0.45, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	if current_hp <= 0:
		if undying_will_available and player_stats.has_undying_will():
			undying_will_available = false
			current_hp = 1
			hp_changed.emit(current_hp, max_hp)
			_show_floating_text(global_position, "Undying Will", Color(1.0, 0.95, 0.35, 1.0))
			return
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	_show_floating_text(global_position, "???", Color(1.0, 0.35, 0.35, 1.0))
	died.emit()


func heal_to_full() -> void:
	is_dead = false
	set_physics_process(true)
	current_hp = max_hp
	invincible_time_left = 0.0
	regen_tick_progress = 0.0
	hp_changed.emit(current_hp, max_hp)
	animated_sprite.visible = true


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)


func perform_attack(override_direction: Vector2 = Vector2.ZERO) -> void:
	if attack_cooldown_left > 0.0:
		return
	var attack_direction: Vector2 = _get_attack_direction(override_direction)
	last_attack_direction = attack_direction
	attack_cooldown_left = get_attack_cooldown_duration()
	AudioManager.play_sfx("attack_swing")
	_spawn_attack_effect(attack_direction)
	equipment_system.consume_attack_durability()
	var attack_shape: RectangleShape2D = RectangleShape2D.new()
	attack_shape.size = Vector2(28, 20) * aoe_attack_multiplier
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_direction.angle(), global_position + _get_attack_offset(attack_direction))
	query.collision_mask = 4
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	var total_damage_dealt: int = 0
	for result: Dictionary in results:
		var collider: Variant = result.get("collider", null)
		if collider == null or not collider.has_method("take_damage") or collider == self:
			continue
		if collider.has_method("is_player_owned_building") and collider.is_player_owned_building():
			continue
		var attack_damage: int = get_attack_damage()
		if execute_skill_armed:
			var execute_enemy_hp: int = int(collider.get("current_hp"))
			var execute_enemy_max_hp: int = int(collider.get("max_hp"))
			if execute_enemy_max_hp > 0 and float(execute_enemy_hp) / float(execute_enemy_max_hp) <= 0.3:
				attack_damage *= 3
			execute_skill_armed = false
		if player_stats.get_total_crit_chance() + crit_chance_bonus > 0.0 and randf() < (player_stats.get_total_crit_chance() + crit_chance_bonus):
			attack_damage *= 2
		if player_stats.get_execute_bonus() > 0.0:
			var enemy_hp: int = int(collider.get("current_hp"))
			var enemy_max_hp: int = int(collider.get("max_hp"))
			if enemy_max_hp > 0 and float(enemy_hp) / float(enemy_max_hp) <= 0.3:
				attack_damage = int(round(float(attack_damage) * (1.0 + player_stats.get_execute_bonus())))
		collider.take_damage(attack_damage, attack_direction)
		if collider.has_method("apply_knockback"):
			collider.apply_knockback(attack_direction, 120.0)
		total_damage_dealt += attack_damage
	if (lifesteal_ratio + equipment_lifesteal_ratio) > 0.0 and total_damage_dealt > 0:
		heal(int(max(round(total_damage_dealt * (lifesteal_ratio + equipment_lifesteal_ratio)), 1.0)))
	# Also hit the closest nearby resource node (trees, rocks, ore)
	var closest_resource: Variant = _get_closest_interactable()
	if closest_resource != null and closest_resource.has_method("hit"):
		last_interacted_resource = closest_resource
		closest_resource.hit()
	_save_persistent_state()


func _spawn_attack_effect(attack_direction: Vector2) -> void:
	var attack_effect = ATTACK_EFFECT_SCENE.instantiate()
	var attack_effect_parent = get_parent()
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().current_scene
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().root
	attack_effect_parent.add_child(attack_effect)
	attack_effect.global_position = global_position + _get_attack_offset(attack_direction)
	if attack_effect.has_method("play_swing"):
		attack_effect.play_swing(attack_direction)


func _get_attack_offset(attack_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	var direction: Vector2 = attack_direction.normalized() if attack_direction.length_squared() > 0.0 else last_attack_direction
	return direction * 18.0 + Vector2(0, 2)


func _get_closest_interactable():
	var closest = null
	var closest_distance: float = INF
	for interactable in nearby_interactables:
		if interactable == null or not is_instance_valid(interactable):
			continue
		if interactable.has_method("get_interaction_prompt") and str(interactable.get_interaction_prompt()) == "":
			continue
		var distance: float = global_position.distance_squared_to(interactable.global_position)
		if distance < closest_distance:
			closest = interactable
			closest_distance = distance
	return closest


func _configure_input_actions() -> void:
	_set_key_action("sprint", KEY_SPACE)
	_set_key_action("debug_toggle", KEY_8)
	_set_key_action("dev_reset", KEY_MINUS)
	_set_key_action("dev_reset_save", KEY_9)
	_set_key_action("dev_class_reset", KEY_0)
	_set_key_action("pickup_loot", KEY_F)
	_set_key_action("dodge", KEY_SHIFT)
	_set_key_action("use_consumable", KEY_Q)
	_set_key_action("use_consumable_2", KEY_R)
	_set_key_action("toggle_build", KEY_C)
	_set_key_action("toggle_equipment", KEY_B)
	_set_key_action("toggle_skills", KEY_K)
	_set_key_action("toggle_achievements", KEY_J)
	_set_key_action("skill_slot_1", KEY_Z)
	_set_key_action("skill_slot_2", KEY_X)
	_set_key_action("skill_slot_3", KEY_V)
	_set_key_action("toggle_map", KEY_M)


func _set_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)
	var key_event: InputEventKey = InputEventKey.new()
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
	return int(round(float(player_stats.get_total_attack()) * damage_multiplier))


func get_attack_cooldown_duration() -> float:
	return BASE_ATTACK_COOLDOWN * attack_cooldown_multiplier


func get_loot_drop_multiplier() -> float:
	return loot_drop_multiplier * (1.0 + player_stats.get_total_loot_bonus())


func get_loot_pickup_range() -> float:
	return player_stats.get_loot_pickup_range()


func get_crafting_cost_multiplier() -> float:
	return player_stats.get_crafting_cost_multiplier()


func get_stats_summary() -> Dictionary:
	return {
		"attack": get_attack_damage(),
		"defense": player_stats.get_total_defense(),
		"max_hp": max_hp,
		"speed": int(round(player_stats.get_total_speed())),
	}


func get_stats_summary_for_item(item: Dictionary) -> Dictionary:
	var current_summary: Dictionary = get_stats_summary()
	var current_bonuses: Dictionary = equipment_system.get_total_bonus_map()
	var preview_bonuses: Dictionary = equipment_system.get_preview_bonus_map(item)
	var attack_delta: float = float(preview_bonuses.get("attack", 0.0)) - float(current_bonuses.get("attack", 0.0))
	var defense_delta: float = float(preview_bonuses.get("defense", 0.0)) - float(current_bonuses.get("defense", 0.0))
	var hp_delta: float = float(preview_bonuses.get("max_hp", 0.0)) - float(current_bonuses.get("max_hp", 0.0))
	var preview_speed_bonus: float = player_stats.base_speed * float(preview_bonuses.get("speed_multiplier", 0.0)) + float(preview_bonuses.get("speed", 0.0))
	var equipment_speed_delta: float = preview_speed_bonus - (float(current_bonuses.get("speed", 0.0)) + player_stats.base_speed * float(current_bonuses.get("speed_multiplier", 0.0)))
	return {
		"attack": int(round(float(current_summary.get("attack", 0.0)) + attack_delta)),
		"defense": int(round(float(current_summary.get("defense", 0.0)) + defense_delta)),
		"max_hp": int(round(float(current_summary.get("max_hp", 0.0)) + hp_delta)),
		"speed": int(round(float(current_summary.get("speed", 0.0)) + equipment_speed_delta)),
	}


func get_unlocked_talents() -> Array[String]:
	return unlocked_talents.duplicate()


func unlock_talent(talent_id: String) -> bool:
	if not TALENT_DATA.can_unlock(unlocked_talents, inventory.get_item_count("talent_shard"), talent_id):
		return false
	var talent: Dictionary = TALENT_DATA.get_talent(talent_id)
	if not inventory.remove_item("talent_shard", int(talent.get("cost", 0))):
		return false
	unlocked_talents.append(talent_id)
	unlocked_talents.sort()
	player_stats.rebuild_talent_bonuses(unlocked_talents)
	if str(talent.get("skill_unlock", "")) != "":
		print("SKILL UNLOCKED: %s" % str(talent.get("skill_unlock", "")))
		var skill_system = _skill_system()
		if skill_system != null:
			skill_system.unlock_skill_from_talent(talent_id)
	_refresh_all_stats()
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.record_talent_unlocked(unlocked_talents.size())
	_save_persistent_state()
	return true


func has_talent(talent_id: String) -> bool:
	return unlocked_talents.has(talent_id)


func start_dungeon_run() -> void:
	dungeon_run_loot.clear()
	dungeon_max_hp_penalty = 0
	clear_dungeon_buffs()
	undying_will_available = player_stats.has_undying_will()
	execute_skill_armed = false
	sprint_skill_time_left = 0.0
	sprint_skill_multiplier = 1.0
	var skill_system: Variant = _skill_system()
	if skill_system != null:
		skill_system.clear_dungeon_cooldowns()
	var achievement_manager: Variant = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.start_dungeon_run()


func finish_dungeon_run(safe_return: bool) -> void:
	if not safe_return:
		lose_dungeon_run_loot()
		equipment_system.apply_death_penalty()
	dungeon_run_loot.clear()
	dungeon_max_hp_penalty = 0
	clear_dungeon_buffs()
	execute_skill_armed = false
	sprint_skill_time_left = 0.0
	sprint_skill_multiplier = 1.0
	_refresh_all_stats()
	_save_persistent_state()


func record_dungeon_loot(item_id: String, quantity: int) -> void:
	for entry in dungeon_run_loot:
		if str(entry.get("id", "")) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			return
	dungeon_run_loot.append({"id": item_id, "quantity": quantity})


func lose_dungeon_run_loot() -> void:
	for entry in dungeon_run_loot:
		inventory.remove_item(str(entry.get("id", "")), int(entry.get("quantity", 0)))


func show_status_message(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	status_message_requested.emit(message, color, duration)


func get_run_max_hp_penalty() -> int:
	return dungeon_max_hp_penalty


func sacrifice_max_hp_percent_for_run(percent: float) -> int:
	if percent <= 0.0:
		return 0
	var sacrifice_amount: int = maxi(int(ceil(float(max_hp) * percent)), 1)
	if max_hp - sacrifice_amount < 1:
		return 0
	dungeon_max_hp_penalty += sacrifice_amount
	_refresh_all_stats()
	current_hp = mini(current_hp, max_hp)
	hp_changed.emit(current_hp, max_hp)
	return sacrifice_amount


func configure_for_network_role(is_local_player: bool) -> void:
	load_persistent_state_on_ready = is_local_player
	if player_camera != null:
		player_camera.enabled = is_local_player
	if not is_local_player:
		ui_blocked = true
		in_menu = false
		nearby_interactables.clear()
		interaction_prompt_cleared.emit()


func _broadcast_state() -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return
	var current_animation: StringName = animated_sprite.animation if animated_sprite != null else &"idle"
	sync_state.rpc(global_position, velocity, str(current_animation), animated_sprite.flip_h if animated_sprite != null else false, animated_sprite.speed_scale if animated_sprite != null else 1.0)


@rpc("authority", "call_remote", "unreliable")
func sync_state(pos: Vector2, synced_velocity: Vector2, animation_name: String, flipped: bool, speed_scale_value: float) -> void:
	global_position = pos
	velocity = synced_velocity
	if animated_sprite == null:
		return
	animated_sprite.flip_h = flipped
	animated_sprite.speed_scale = speed_scale_value
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(StringName(animation_name)):
		animated_sprite.play(animation_name)


func _recalculate_buff_state() -> void:
	damage_multiplier = 1.0
	crit_chance_bonus = 0.0
	attack_cooldown_multiplier = 1.0
	lifesteal_ratio = 0.0
	armor_reduction = 0.0
	dodge_chance = 0.0
	move_speed_multiplier = 1.0
	loot_drop_multiplier = 1.0
	aoe_attack_multiplier = 1.0
	bonus_max_hp = 0
	buff_regen_amount = 0
	buff_regen_interval = 3.0
	for buff_id in active_buff_ids:
		match buff_id:
			"atk_up_1":
				damage_multiplier *= 1.15
			"atk_up_2":
				damage_multiplier *= 1.25
				move_speed_multiplier *= 0.9
			"crit_chance":
				crit_chance_bonus += 0.15
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
				buff_regen_amount += 1
				buff_regen_interval = 3.0
			"speed_up":
				move_speed_multiplier *= 1.25
			"loot_up":
				loot_drop_multiplier *= 2.0
			"aoe_attack":
				aoe_attack_multiplier *= 1.5
	_refresh_all_stats()


func _on_player_stats_changed() -> void:
	_refresh_all_stats()


func _on_equipment_changed() -> void:
	player_stats.set_equipment_bonuses(equipment_system.get_total_bonus_map())
	equipment_lifesteal_ratio = float(equipment_system.get_total_bonus_map().get("lifesteal_ratio", 0.0))
	_save_persistent_state()


func _refresh_all_stats() -> void:
	speed = player_stats.get_total_speed()
	max_hp = maxi(player_stats.get_total_max_hp() + bonus_max_hp - dungeon_max_hp_penalty, 1)
	current_hp = clamp(current_hp, 0, max_hp)
	stats_changed.emit()
	hp_changed.emit(current_hp, max_hp)


func set_consumable_slot(slot_index: int, item_id_val: String) -> void:
	if slot_index == 0:
		consumable_q_id = item_id_val
	elif slot_index == 1:
		consumable_r_id = item_id_val
	if inventory != null:
		inventory.inventory_changed.emit()


func get_consumable_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = [{}, {}]
	for stack in inventory.items:
		if str(stack.get("type", "")) != "consumable":
			continue
		var id: String = str(stack.get("id", ""))
		if id == consumable_q_id:
			slots[0] = stack.duplicate(true)
		elif id == consumable_r_id:
			slots[1] = stack.duplicate(true)
	# Fall back: fill empty slots with any consumable not already pinned
	if slots[0].is_empty() and slots[1].is_empty():
		for stack in inventory.items:
			if str(stack.get("type", "")) != "consumable":
				continue
			if slots[0].is_empty():
				slots[0] = stack.duplicate(true)
			elif str(stack.get("id", "")) != str(slots[0].get("id", "")):
				slots[1] = stack.duplicate(true)
				break
	while slots.size() > 0 and (slots as Array).back().is_empty():
		slots.pop_back()
	return slots


func use_second_consumable() -> bool:
	return _use_consumable_at_slot(1)


func _load_persistent_state() -> void:
	var payload: Dictionary = PLAYER_SAVE.load_state()
	unlocked_talents.clear()
	for talent_id in payload.get("unlocked_talents", []):
		unlocked_talents.append(str(talent_id))
	equipment_system.load_state(payload.get("equipment", {}))
	player_stats.rebuild_talent_bonuses(unlocked_talents)
	player_stats.set_equipment_bonuses(equipment_system.get_total_bonus_map())
	undying_will_available = player_stats.has_undying_will()


func _save_persistent_state() -> void:
	PLAYER_SAVE.save_state({
		"unlocked_talents": unlocked_talents,
		"equipment": equipment_system.serialize_state(),
	})


func use_first_consumable() -> bool:
	return _use_consumable_at_slot(0)


func _use_consumable_at_slot(slot_index: int) -> bool:
	if consumable_cooldown_left > 0.0:
		return false
	var slots: Array[Dictionary] = get_consumable_slots()
	if slot_index < 0 or slot_index >= slots.size():
		show_status_message("Consumable slot empty", Color(0.7, 0.7, 0.7, 1.0))
		return false
	var stack: Dictionary = slots[slot_index]
	var item_id: String = str(stack.get("id", ""))
	var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
	if not inventory.remove_item(item_id, 1):
		return false
	var effects: Dictionary = item_data.get("effect", {}) as Dictionary
	var heal_amount: int = int(effects.get("heal", 0))
	if heal_amount > 0:
		heal(heal_amount)
		_play_heal_feedback(heal_amount)
	if bool(effects.get("light", false)):
		torch_light_time_left = 30.0
		show_status_message("Torch lit", Color(1.0, 0.85, 0.45, 1.0))
	consumable_cooldown_left = BANDAGE_COOLDOWN
	return true


func _play_heal_feedback(heal_amount: int) -> void:
	_show_floating_text(global_position, "+%d HP" % heal_amount, Color(0.45, 1.0, 0.45, 1.0))
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(0.45, 1.0, 0.45, 1.0), 0.08)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.22)


func apply_knockback(direction: Vector2, force: float = 110.0) -> void:
	if direction.length_squared() <= 0.0:
		return
	knockback_velocity += direction.normalized() * force


func _get_attack_direction(override_direction: Vector2 = Vector2.ZERO) -> Vector2:
	if override_direction.length_squared() > 0.0:
		return override_direction.normalized()
	var mouse_position: Vector2 = get_global_mouse_position()
	var direction: Vector2 = mouse_position - global_position
	if direction.length_squared() <= 0.001:
		return Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	return direction.normalized()


func _setup_torch_light() -> void:
	torch_light.texture_scale = 2.8
	torch_light.energy = 1.2
	torch_light.color = Color(1.0, 0.8, 0.45, 1.0)
	torch_light.visible = false
	torch_light.position = Vector2(0, -2)
	add_child(torch_light)


func _skill_system():
	return get_node_or_null("/root/SkillSystem")


func arm_execute_skill() -> void:
	execute_skill_armed = true


func activate_sprint_skill(duration: float, multiplier: float) -> void:
	sprint_skill_time_left = max(duration, 0.0)
	sprint_skill_multiplier = max(multiplier, 1.0)
	sprint_afterimage_timer = 0.0
	show_status_message("Sprint active", Color(0.75, 0.9, 1.0, 1.0))


func _spawn_afterimage() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var animation_name: StringName = animated_sprite.animation
	if animation_name == StringName():
		return
	var texture: Texture2D = animated_sprite.sprite_frames.get_frame_texture(animation_name, animated_sprite.frame)
	if texture == null:
		return
	var afterimage: Sprite2D = Sprite2D.new()
	afterimage.texture = texture
	afterimage.global_position = animated_sprite.global_position
	afterimage.scale = animated_sprite.scale
	afterimage.flip_h = animated_sprite.flip_h
	afterimage.modulate = Color(0.75, 0.95, 1.0, 0.45)
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		return
	parent_node.add_child(afterimage)
	var tween: Tween = afterimage.create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_callback(afterimage.queue_free)

