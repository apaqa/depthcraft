extends CharacterBody2D

@export var speed: float = 80.0
@export var sprint_speed: float = 140.0

const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")
const ATTACK_EFFECT_SCENE: PackedScene = preload("res://scenes/player/attack_effect.tscn")
const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const TALENT_DATA: Script = preload("res://scripts/talent/talent_data.gd")
const PLAYER_SAVE: Script = preload("res://scripts/player/player_save.gd")
const LEGENDARY_ITEMS: Script = preload("res://scripts/dungeon/legendary_items.gd")
const SKELETON_SERVANT_SCRIPT: Script = preload("res://scripts/player/skeleton_servant.gd")
const PLAYER_PROJECTILE_SCRIPT: Script = preload("res://scripts/combat/player_projectile.gd")
const PROJECTILE_ARROW_TEXTURE: Texture2D = preload("res://assets/icons/kyrise/arrow_01a.png")
const PROJECTILE_ORB_TEXTURE: Texture2D = preload("res://assets/icons/kyrise/crystal_01a.png")

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
signal safe_return_requested
signal run_max_hp_penalty_changed(lost_percent: int)

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
var _god_mode: bool = false
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
var active_meal_buff: Dictionary = {}
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
var dungeon_max_hp_penalty_percent: int = 0
var dungeon_max_hp_reference: int = 0
var current_dungeon_floor: int = 0
var _run_stat_modifiers: Dictionary = {}
var _floor_stat_modifiers: Dictionary = {}
var _tavern_buffs: Array[Dictionary] = []
var set_attack_cooldown_reduction: float = 0.0
var necromancer_summon_on_kill: bool = false
var lava_burst_on_hit: bool = false
var abyss_crit_heal: bool = false
var shadow_combo_crit: bool = false
var dragon_emergency_guard: bool = false
var shadow_combo_count: int = 0
var shadow_guaranteed_crit_ready: bool = false
var dragon_guard_trigger_floor: int = -1
var legend_on_kill_aoe: bool = false
var legend_block_heal: bool = false
var legend_crit_lifesteal: bool = false
var legend_dodge_on_sprint: bool = false
var legend_eclipse_crit: bool = false
var legend_chain_lightning: bool = false
var legend_kill_count_bonus: bool = false
var legend_kill_count: int = 0
var _dungeon_run_time: float = 0.0
var _is_charging: bool = false
var _charge_time: float = 0.0
const _MAX_CHARGE: float = 2.0
var _charge_bar_root: Node2D = null
var _charge_bar_fill: Polygon2D = null

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
	_setup_charge_bar()
	configure_for_network_role(load_persistent_state_on_ready)
	var _bs: Node = get_node_or_null("/root/BlessingSystem")
	if _bs != null and _bs.has_signal("blessings_changed") and not _bs.blessings_changed.is_connected(_refresh_all_stats):
		_bs.blessings_changed.connect(_refresh_all_stats)


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
	if current_dungeon_floor > 0 and not is_dead:
		_dungeon_run_time += delta
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
	if _is_charging and not is_dead and not in_menu:
		_charge_time = minf(_charge_time + delta, _MAX_CHARGE)
		_update_charge_bar()
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

	if event.is_action_pressed("dev_reset"):
		return
	if event.is_action_pressed("dev_reset_save"):
		_toggle_god_mode()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dev_class_reset"):
		_grant_debug_resources()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_build"):
		if building_system.toggle_build_mode():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_equipment") and not build_mode and not is_dead:
		equipment_panel_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_status") and not build_mode and not is_dead:
		var hud_node: Node = get_tree().current_scene
		if hud_node != null:
			hud_node = hud_node.get_node_or_null("HUDCanvas/HUD")
		if hud_node != null and hud_node.has_method("toggle_status_panel"):
			hud_node.toggle_status_panel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("attack") and not build_mode and not ui_blocked and not is_dead:
		perform_attack()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("attack_secondary") and not build_mode and not ui_blocked and not is_dead:
		_start_charge()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("attack_secondary") and _is_charging:
		_release_charge()
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
		var found_loot: bool = _pickup_nearby_loot()
		if not found_loot and current_dungeon_floor <= 0:
			safe_return_requested.emit()
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


func _toggle_god_mode() -> void:
	_god_mode = not _god_mode
	if _god_mode:
		damage_multiplier = 10.0
		move_speed_multiplier = 2.0
		max_hp = max_hp * 5
		current_hp = max_hp
		hp_changed.emit(current_hp, max_hp)
		show_status_message("GOD MODE ON", Color(1.0, 0.85, 0.2, 1.0), 2.0)
	else:
		damage_multiplier = 1.0
		move_speed_multiplier = 1.0
		_refresh_all_stats()
		current_hp = max_hp
		hp_changed.emit(current_hp, max_hp)
		show_status_message("GOD MODE OFF", Color(0.7, 0.7, 0.7, 1.0), 2.0)


func _grant_debug_resources() -> void:
	inventory.add_item("gold", 100)
	inventory.add_item("silver", 100)
	inventory.add_item("copper", 1000)
	inventory.add_item("talent_shard", 50)
	show_status_message("DEBUG: +100G +100S +1000C +50 shards", Color(0.5, 1.0, 0.5, 1.0), 2.0)


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


func _pickup_nearby_loot() -> bool:
	var pickup_radius: float = 64.0
	var drops: Array = get_tree().get_nodes_in_group("loot_drop")
	var picked_any: bool = false
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		var drop_node: Node2D = drop as Node2D
		if drop_node == null:
			continue
		var dist: float = global_position.distance_to(drop_node.global_position)
		if dist <= pickup_radius:
			if drop_node.has_method("try_pickup"):
				drop_node.try_pickup(self)
				picked_any = true
	return picked_any


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
		var prompt_text: String = interactable.get_interaction_prompt()
		if Input.is_key_pressed(KEY_ALT) and interactable.has_method("get_lore_key"):
			var lore_key: String = str(interactable.get_lore_key())
			var lore_text: String = LocaleManager.L(lore_key)
			if lore_text != lore_key and lore_text != "":
				prompt_text += "\n" + lore_text
		interaction_prompt_changed.emit(prompt_text)
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
	if is_dead or invincible_time_left > 0.0 or _god_mode:
		return
	var equip_dodge: float = float(equipment_system.get_total_equipment_bonus("dodge_chance"))
	var effective_dodge: float = dodge_chance + equip_dodge
	if legend_dodge_on_sprint and sprint_skill_time_left > 0.0:
		effective_dodge += 0.30
	if effective_dodge > 0.0 and randf() < effective_dodge:
		_show_floating_text(global_position, "Dodge", Color(0.75, 1.0, 1.0, 1.0))
		return
	if player_stats.get_block_chance() > 0.0 and randf() < player_stats.get_block_chance():
		_show_floating_text(global_position, "Block", Color(0.7, 0.85, 1.0, 1.0))
		if legend_block_heal:
			heal(max(int(round(float(max_hp) * 0.05)), 1))
		return
	var def_bonus: float = _get_blessing_value("def_percent")
	var defense_value: int = int(round(float(player_stats.get_total_defense()) * (1.0 + def_bonus)))
	var reduced_amount: int = max(int(round(float(max(amount - defense_value, 1)) * (1.0 - armor_reduction))), 1)
	current_hp = max(current_hp - reduced_amount, 0)
	AudioManager.play_sfx("player_hurt")
	equipment_system.consume_damage_durability()
	var dragon_triggered: bool = _try_trigger_dragon_guard()
	if lava_burst_on_hit and randf() < 0.2:
		_trigger_lava_counterburst()
	hp_changed.emit(current_hp, max_hp)
	if not dragon_triggered:
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
	AudioManager.play_sfx("player_die")
	_show_floating_text(global_position, "???", Color(1.0, 0.35, 0.35, 1.0))
	var bs_die: Node = get_node_or_null("/root/BlessingSystem")
	if bs_die != null and bs_die.has_method("clear_all"):
		bs_die.call("clear_all")
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
	if amount > 5:
		AudioManager.play_sfx("heal")


func perform_attack(override_direction: Vector2 = Vector2.ZERO) -> void:
	if attack_cooldown_left > 0.0:
		return
	var attack_direction: Vector2 = _get_attack_direction(override_direction)
	last_attack_direction = attack_direction
	attack_cooldown_left = get_attack_cooldown_duration()
	AudioManager.play_sfx("attack_swing")
	equipment_system.consume_attack_durability()
	var guaranteed_crit_ready: bool = shadow_combo_crit and shadow_guaranteed_crit_ready
	var class_id: String = _get_current_class_id()
	if class_id == "ranger" or class_id == "mage":
		_spawn_class_projectile(attack_direction, class_id, guaranteed_crit_ready)
		_update_shadow_combo_state(false, guaranteed_crit_ready)
		_save_persistent_state()
		return
	# Warrior fan/arc melee
	_spawn_attack_effect(attack_direction)
	var attack_shape: RectangleShape2D = RectangleShape2D.new()
	attack_shape.size = Vector2(48, 36) * aoe_attack_multiplier
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_direction.angle(), global_position + attack_direction.normalized() * 24.0 + Vector2(0, 2))
	query.collision_mask = 4
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	var total_damage_dealt: int = 0
	var attack_connected: bool = false
	var crit_landed: bool = false
	for result: Dictionary in results:
		var hit_result: Dictionary = _apply_single_hit(result.get("collider", null), attack_direction, guaranteed_crit_ready)
		if hit_result["damage"] > 0:
			total_damage_dealt += hit_result["damage"]
			if hit_result["crit"]:
				crit_landed = true
			attack_connected = true
	_apply_post_attack_effects(total_damage_dealt, crit_landed, attack_connected, guaranteed_crit_ready)
	# Also hit the closest nearby resource node (trees, rocks, ore)
	var closest_resource: Variant = _get_closest_interactable()
	if closest_resource != null and closest_resource.has_method("hit"):
		last_interacted_resource = closest_resource
		closest_resource.hit()
	_save_persistent_state()


func _apply_single_hit(collider: Variant, attack_direction: Vector2, guaranteed_crit: bool, damage_scale: float = 1.0) -> Dictionary:
	if collider == null or not collider.has_method("take_damage") or collider == self:
		return {"damage": 0, "crit": false}
	if collider.has_method("is_player_owned_building") and collider.is_player_owned_building():
		return {"damage": 0, "crit": false}
	var attack_damage: int = int(round(float(get_attack_damage()) * damage_scale))
	if execute_skill_armed:
		var execute_enemy_hp: int = int(collider.get("current_hp"))
		var execute_enemy_max_hp: int = int(collider.get("max_hp"))
		if execute_enemy_max_hp > 0 and float(execute_enemy_hp) / float(execute_enemy_max_hp) <= 0.3:
			attack_damage *= 3
		execute_skill_armed = false
	var is_critical: bool = guaranteed_crit
	var total_crit_chance: float = player_stats.get_total_crit_chance() + crit_chance_bonus + _get_blessing_value("crit_rate_bonus")
	if not is_critical and total_crit_chance > 0.0 and randf() < total_crit_chance:
		is_critical = true
	if is_critical:
		var crit_multi: float = 4.0 if legend_eclipse_crit else 2.0
		var equip_crit_dmg: float = float(equipment_system.get_total_equipment_bonus("crit_damage_multiplier"))
		var crit_dmg_bonus: float = _get_blessing_value("crit_damage_bonus")
		attack_damage = int(round(float(attack_damage) * (crit_multi + equip_crit_dmg + crit_dmg_bonus)))
	if player_stats.get_execute_bonus() > 0.0:
		var enemy_hp: int = int(collider.get("current_hp"))
		var enemy_max_hp: int = int(collider.get("max_hp"))
		if enemy_max_hp > 0 and float(enemy_hp) / float(enemy_max_hp) <= 0.3:
			attack_damage = int(round(float(attack_damage) * (1.0 + player_stats.get_execute_bonus())))
	collider.take_damage(attack_damage, attack_direction)
	if collider.has_method("apply_knockback"):
		collider.apply_knockback(attack_direction, 120.0)
	_apply_blessing_on_hit(collider, attack_damage)
	_handle_enemy_kill_trigger(collider)
	return {"damage": attack_damage, "crit": is_critical}


func _apply_post_attack_effects(total_damage: int, crit_landed: bool, attack_connected: bool, guaranteed_crit_was_ready: bool) -> void:
	var blessing_lifesteal: float = _get_blessing_value("lifesteal")
	var total_lifesteal: float = lifesteal_ratio + equipment_lifesteal_ratio + blessing_lifesteal
	var low_hp_threshold: float = _get_blessing_value("lifesteal_low_hp")
	if low_hp_threshold > 0.0 and max_hp > 0 and float(current_hp) / float(max_hp) < low_hp_threshold:
		total_lifesteal *= 2.0
	if total_lifesteal > 0.0 and total_damage > 0:
		heal(int(max(round(float(total_damage) * total_lifesteal), 1.0)))
	if abyss_crit_heal and crit_landed:
		var heal_amount: int = max(int(round(float(max_hp) * 0.05)), 1)
		heal(heal_amount)
		_show_floating_text(global_position, "+%d HP" % heal_amount, Color(0.55, 1.0, 0.7, 1.0))
	if legend_crit_lifesteal and crit_landed and total_damage > 0:
		heal(max(int(round(float(total_damage) * 0.10)), 1))
	if crit_landed and _get_blessing_value("crit_shockwave") > 0.0:
		_trigger_blessing_crit_shockwave(total_damage)
	if attack_connected:
		AudioManager.play_sfx("attack_hit")
	if legend_chain_lightning and attack_connected and randf() < 0.20:
		_trigger_chain_lightning()
	_update_shadow_combo_state(attack_connected, guaranteed_crit_was_ready)


func _spawn_class_projectile(attack_direction: Vector2, class_id: String, guaranteed_crit: bool) -> void:
	var proj = PLAYER_PROJECTILE_SCRIPT.new()
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(proj)
	proj.global_position = global_position
	match class_id:
		"ranger":
			proj.setup(attack_direction, 300.0, 200.0, 0, PROJECTILE_ARROW_TEXTURE, self, guaranteed_crit)
		"mage":
			proj.setup(attack_direction, 200.0, 160.0, -1, PROJECTILE_ORB_TEXTURE, self, guaranteed_crit, Color(0.5, 0.7, 1.0, 1.0))


func on_projectile_hit(collider: Variant, proj_direction: Vector2, guaranteed_crit: bool) -> void:
	var hit_result: Dictionary = _apply_single_hit(collider, proj_direction, guaranteed_crit)
	if hit_result["damage"] <= 0:
		return
	_apply_post_attack_effects(hit_result["damage"], hit_result["crit"], true, guaranteed_crit)


func _setup_charge_bar() -> void:
	_charge_bar_root = Node2D.new()
	_charge_bar_root.position = Vector2(-12, -30)
	_charge_bar_root.visible = false
	add_child(_charge_bar_root)
	var bar_bg: Polygon2D = Polygon2D.new()
	bar_bg.color = Color(0.12, 0.12, 0.16, 0.9)
	bar_bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(24, 0), Vector2(24, 4), Vector2(0, 4)])
	_charge_bar_root.add_child(bar_bg)
	_charge_bar_fill = Polygon2D.new()
	_charge_bar_fill.color = Color(0.9, 0.55, 0.1, 1.0)
	_charge_bar_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(0, 0), Vector2(0, 4), Vector2(0, 4)])
	_charge_bar_root.add_child(_charge_bar_fill)


func _update_charge_bar() -> void:
	if _charge_bar_fill == null:
		return
	var fill_ratio: float = _charge_time / _MAX_CHARGE
	var fill_width: float = 24.0 * fill_ratio
	_charge_bar_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(fill_width, 0), Vector2(fill_width, 4), Vector2(0, 4)])
	_charge_bar_fill.color = Color(0.9, lerp(0.55, 0.9, fill_ratio), lerp(0.1, 0.0, fill_ratio), 1.0)


func _start_charge() -> void:
	_is_charging = true
	_charge_time = 0.0
	if _charge_bar_root != null:
		_charge_bar_root.visible = true
	_update_charge_bar()


func _release_charge() -> void:
	_is_charging = false
	if _charge_bar_root != null:
		_charge_bar_root.visible = false
	var saved_charge_time: float = _charge_time
	var charge_ratio: float = saved_charge_time / _MAX_CHARGE
	_charge_time = 0.0
	if attack_cooldown_left > 0.0:
		return
	var class_id: String = _get_current_class_id()
	attack_cooldown_left = get_attack_cooldown_duration() * 1.5
	AudioManager.play_sfx("attack_swing")
	equipment_system.consume_attack_durability()
	match class_id:
		"warrior":
			_perform_charged_warrior(charge_ratio)
		"ranger":
			_perform_charged_ranger(saved_charge_time)
		"mage":
			_perform_charged_mage(charge_ratio)


func _perform_charged_warrior(charge_ratio: float) -> void:
	var attack_direction: Vector2 = _get_attack_direction()
	last_attack_direction = attack_direction
	var visual_scale: float = 1.0 + charge_ratio * 1.5
	_spawn_attack_effect(attack_direction, visual_scale)
	var range_px: float = lerp(48.0, 96.0, charge_ratio)
	var dmg_scale: float = lerp(1.0, 3.0, charge_ratio)
	var attack_shape: RectangleShape2D = RectangleShape2D.new()
	attack_shape.size = Vector2(range_px, range_px * 0.75) * aoe_attack_multiplier
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(attack_direction.angle(), global_position + attack_direction.normalized() * range_px * 0.5 + Vector2(0, 2))
	query.collision_mask = 4
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	var guaranteed_crit: bool = shadow_combo_crit and shadow_guaranteed_crit_ready
	var total_damage: int = 0
	var crit_landed: bool = false
	var connected: bool = false
	for result: Dictionary in results:
		var hit_result: Dictionary = _apply_single_hit(result.get("collider", null), attack_direction, guaranteed_crit, dmg_scale)
		if hit_result["damage"] > 0:
			total_damage += hit_result["damage"]
			if hit_result["crit"]:
				crit_landed = true
			connected = true
	_apply_post_attack_effects(total_damage, crit_landed, connected, guaranteed_crit)


func _perform_charged_ranger(charge_time: float) -> void:
	var arrow_count: int = 2
	if charge_time >= 2.0:
		arrow_count = 7
	elif charge_time >= 1.5:
		arrow_count = 5
	elif charge_time >= 1.0:
		arrow_count = 3
	var attack_direction: Vector2 = _get_attack_direction()
	last_attack_direction = attack_direction
	var guaranteed_crit: bool = shadow_combo_crit and shadow_guaranteed_crit_ready
	var spread_rad: float = deg_to_rad(12.0)
	var base_angle: float = attack_direction.angle()
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	for i: int in range(arrow_count):
		var angle_offset: float = 0.0
		if arrow_count > 1:
			angle_offset = lerp(-spread_rad, spread_rad, float(i) / float(arrow_count - 1))
		var dir: Vector2 = Vector2.from_angle(base_angle + angle_offset)
		var proj = PLAYER_PROJECTILE_SCRIPT.new()
		parent.add_child(proj)
		proj.global_position = global_position
		proj.setup(dir, 300.0, 200.0, 0, PROJECTILE_ARROW_TEXTURE, self, guaranteed_crit)
	_update_shadow_combo_state(false, guaranteed_crit)


func _perform_charged_mage(charge_ratio: float) -> void:
	var target_pos: Vector2 = get_global_mouse_position()
	var offset_dir: Vector2 = target_pos - global_position
	if offset_dir.length() > 120.0:
		target_pos = global_position + offset_dir.normalized() * 120.0
	var radius: float = lerp(32.0, 80.0, charge_ratio)
	var guaranteed_crit: bool = shadow_combo_crit and shadow_guaranteed_crit_ready
	_spawn_mage_aoe_indicator(target_pos, radius)
	var tween: Tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(_trigger_mage_aoe.bind(target_pos, radius, guaranteed_crit))
	_update_shadow_combo_state(false, guaranteed_crit)


func _spawn_mage_aoe_indicator(center: Vector2, radius: float) -> void:
	var ring: Line2D = Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.5, 0.7, 1.0, 0.8)
	ring.closed = true
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(20):
		var angle: float = TAU * float(i) / 20.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	ring.points = points
	ring.global_position = center
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _trigger_mage_aoe(target_pos: Vector2, radius: float, guaranteed_crit: bool) -> void:
	if not is_instance_valid(self):
		return
	var attack_shape: CircleShape2D = CircleShape2D.new()
	attack_shape.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(0.0, target_pos)
	query.collision_mask = 4
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	var total_damage: int = 0
	var crit_landed: bool = false
	var connected: bool = false
	for result: Dictionary in results:
		var collider: Variant = result.get("collider", null)
		var dir_to_collider: Vector2 = Vector2.ZERO
		if collider != null and "global_position" in collider:
			dir_to_collider = (Vector2(collider.global_position) - target_pos).normalized()
		var hit_result: Dictionary = _apply_single_hit(collider, dir_to_collider, guaranteed_crit)
		if hit_result["damage"] > 0:
			total_damage += hit_result["damage"]
			if hit_result["crit"]:
				crit_landed = true
			connected = true
	_apply_post_attack_effects(total_damage, crit_landed, connected, guaranteed_crit)


func _handle_enemy_kill_trigger(enemy_ref: Variant) -> void:
	if enemy_ref == null:
		return
	if not bool(enemy_ref.get("is_dead")):
		return
	if necromancer_summon_on_kill and randf() < 0.10:
		_spawn_skeleton_servant()
	if legend_on_kill_aoe:
		_trigger_legend_kill_aoe()
	if legend_kill_count_bonus:
		legend_kill_count += 1
		if legend_kill_count % 10 == 0:
			damage_multiplier = minf(damage_multiplier + 0.02, damage_multiplier + 0.50 - maxf(damage_multiplier - 1.0, 0.0))
			_show_floating_text(global_position, "ATK+2%", Color(0.9, 0.5, 1.0, 1.0))
	var heal_kill: float = _get_blessing_value("heal_on_kill")
	if heal_kill > 0.0:
		var hk_amount: int = maxi(int(round(float(max_hp) * heal_kill)), 1)
		heal(hk_amount)
	if _get_blessing_value("burn_spread") > 0.0 and enemy_ref.get("burn_time_left") != null and float(enemy_ref.get("burn_time_left")) > 0.0:
		_trigger_burn_spread(enemy_ref)


func _spawn_skeleton_servant() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var servant: Node2D = SKELETON_SERVANT_SCRIPT.new() as Node2D
	if servant == null:
		return
	parent_node.add_child(servant)
	servant.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
	if servant.has_method("setup"):
		var summon_damage: int = max(int(round(float(get_attack_damage()) * 0.55)), 12)
		servant.setup(self, 15.0, summon_damage)
	_show_floating_text(global_position, "Skeleton", Color(0.82, 0.92, 1.0, 1.0))


func _trigger_lava_counterburst() -> void:
	var burst_damage: int = max(int(round(float(get_attack_damage()) * 0.6)), 12)
	var hit_enemy: bool = false
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(global_position) > 78.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(burst_damage, (enemy.global_position - global_position).normalized())
			hit_enemy = true
	if hit_enemy:
		_show_floating_text(global_position, "Flame Burst", Color(1.0, 0.55, 0.2, 1.0))


func _trigger_legend_kill_aoe() -> void:
	var aoe_damage: int = max(int(round(float(get_attack_damage()) * 0.40)), 1)
	var hit_enemy: bool = false
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(global_position) > 80.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(aoe_damage, (enemy.global_position - global_position).normalized())
			hit_enemy = true
	if hit_enemy:
		_show_floating_text(global_position, "Ragnarok", Color(1.0, 0.3, 0.1, 1.0))


func _trigger_chain_lightning() -> void:
	var chain_damage: int = max(int(round(float(get_attack_damage()) * 0.50)), 1)
	var hit_count: int = 0
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(global_position) > 100.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(chain_damage, (enemy.global_position - global_position).normalized())
			hit_count += 1
	if hit_count > 0:
		_show_floating_text(global_position, "Lightning", Color(0.8, 0.9, 1.0, 1.0))


func _apply_blessing_on_hit(collider: Variant, attack_damage: int) -> void:
	var burn_val: float = _get_blessing_value("burn_on_hit")
	if burn_val > 0.0 and randf() < burn_val:
		if collider.has_method("apply_burn"):
			var burn_dps_val: float = float(attack_damage) * 0.03
			var burn_duration_bonus: float = _get_blessing_value("freeze_duration_bonus")
			collider.apply_burn(burn_dps_val, 3.0 + burn_duration_bonus)
	var chill_val: float = _get_blessing_value("chill_on_hit")
	if chill_val > 0.0 and collider.has_method("apply_chill"):
		var freeze_dur: float = 2.0 + _get_blessing_value("freeze_duration_bonus")
		collider.apply_chill(int(round(chill_val)), freeze_dur)
	var poison_val: float = _get_blessing_value("poison_on_hit")
	if poison_val > 0.0 and collider.has_method("apply_poison"):
		var pdps: float = float(attack_damage) * 0.02
		collider.apply_poison(pdps, int(round(poison_val)))
	var frozen_bonus: float = _get_blessing_value("frozen_bonus_damage")
	if frozen_bonus > 0.0 and collider.get("is_frozen") != null and bool(collider.get("is_frozen")):
		var bonus_dmg: int = maxi(int(round(float(attack_damage) * frozen_bonus)), 1)
		collider.take_damage(bonus_dmg, Vector2.ZERO)


func _trigger_blessing_crit_shockwave(base_damage: int) -> void:
	var wave_ratio: float = _get_blessing_value("crit_shockwave")
	if wave_ratio <= 0.0:
		return
	var wave_damage: int = maxi(int(round(float(base_damage) * wave_ratio)), 1)
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(global_position) > 80.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(wave_damage, (enemy.global_position - global_position).normalized())
	_show_floating_text(global_position, "Shockwave", Color(1.0, 0.75, 0.1, 1.0))


func _trigger_burn_spread(source_enemy: Variant) -> void:
	var spread_damage: int = maxi(int(round(float(get_attack_damage()) * 0.2)), 1)
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy == source_enemy:
			continue
		if bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to((source_enemy as Node2D).global_position) > 60.0:
			continue
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(float(spread_damage) * 0.03, 3.0)
		if enemy.has_method("take_damage"):
			enemy.take_damage(spread_damage, ((source_enemy as Node2D).global_position - enemy.global_position).normalized())
	_show_floating_text((source_enemy as Node2D).global_position, "Wildfire", Color(1.0, 0.45, 0.05, 1.0))


func _try_trigger_dragon_guard() -> bool:
	if not dragon_emergency_guard:
		return false
	if current_hp > int(floor(float(max_hp) * 0.3)):
		return false
	var current_floor: int = _get_current_floor_context()
	if current_floor == dragon_guard_trigger_floor:
		return false
	dragon_guard_trigger_floor = current_floor
	current_hp = min(current_hp + max(int(round(float(max_hp) * 0.5)), 1), max_hp)
	invincible_time_left = max(invincible_time_left, 5.0)
	_show_floating_text(global_position, "Dragon Guard", Color(1.0, 0.88, 0.45, 1.0))
	return true


func _update_shadow_combo_state(attack_connected: bool, guaranteed_crit_ready: bool) -> void:
	if not shadow_combo_crit:
		shadow_combo_count = 0
		shadow_guaranteed_crit_ready = false
		return
	if not attack_connected:
		return
	if guaranteed_crit_ready:
		shadow_combo_count = 0
		shadow_guaranteed_crit_ready = false
		return
	shadow_combo_count += 1
	if shadow_combo_count < 3:
		return
	shadow_combo_count = 0
	shadow_guaranteed_crit_ready = true
	show_status_message("影刃套裝：下一擊必定暴擊", Color(0.75, 0.78, 1.0, 1.0), 1.2)


func _get_current_floor_context() -> int:
	var node: Node = get_parent()
	while node != null:
		var floor_value: Variant = node.get("current_floor")
		if floor_value != null:
			return int(floor_value)
		node = node.get_parent()
	return 0


func _spawn_attack_effect(attack_direction: Vector2, effect_scale: float = 1.0) -> void:
	var attack_effect = ATTACK_EFFECT_SCENE.instantiate()
	var attack_effect_parent = get_parent()
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().current_scene
	if attack_effect_parent == null:
		attack_effect_parent = get_tree().root
	attack_effect_parent.add_child(attack_effect)
	attack_effect.global_position = global_position + _get_attack_offset(attack_direction) * effect_scale
	if effect_scale != 1.0:
		attack_effect.scale = Vector2(effect_scale, effect_scale)
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
	_set_key_action("toggle_status", KEY_TAB)
	_set_mouse_action("attack_secondary", MOUSE_BUTTON_RIGHT)


func _set_mouse_action(action_name: String, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = button
	InputMap.action_add_event(action_name, mouse_event)


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
	active_meal_buff.clear()
	_recalculate_buff_state()
	buffs_changed.emit(get_active_buffs())


func apply_run_stat_modifier(modifier_id: String, effects: Dictionary) -> void:
	if modifier_id == "" or effects.is_empty():
		return
	_run_stat_modifiers[modifier_id] = effects.duplicate(true)
	_refresh_runtime_stat_modifiers()


func apply_floor_stat_modifier(modifier_id: String, effects: Dictionary) -> void:
	if modifier_id == "" or effects.is_empty():
		return
	_floor_stat_modifiers[modifier_id] = effects.duplicate(true)
	_refresh_runtime_stat_modifiers()


func on_dungeon_floor_changed(floor_number: int) -> void:
	if floor_number <= 0:
		current_dungeon_floor = 0
		clear_floor_stat_modifiers()
		return
	if current_dungeon_floor == floor_number:
		return
	current_dungeon_floor = floor_number
	clear_floor_stat_modifiers()


func clear_floor_stat_modifiers() -> void:
	if _floor_stat_modifiers.is_empty():
		return
	_floor_stat_modifiers.clear()
	_refresh_runtime_stat_modifiers()


func clear_run_stat_modifiers() -> void:
	if _run_stat_modifiers.is_empty():
		return
	_run_stat_modifiers.clear()
	_refresh_runtime_stat_modifiers()


func _refresh_runtime_stat_modifiers() -> void:
	var merged_effects: Dictionary = {}
	_merge_modifier_effects(merged_effects, _run_stat_modifiers)
	_merge_modifier_effects(merged_effects, _floor_stat_modifiers)
	if player_stats != null and player_stats.has_method("set_runtime_bonuses"):
		player_stats.set_runtime_bonuses(merged_effects)


func _merge_modifier_effects(target: Dictionary, source: Dictionary) -> void:
	for modifier_id_variant: Variant in source.keys():
		var modifier_id: String = str(modifier_id_variant)
		var modifier_effects: Variant = source.get(modifier_id, {})
		if typeof(modifier_effects) != TYPE_DICTIONARY:
			continue
		var effect_map: Dictionary = modifier_effects as Dictionary
		for effect_id_variant: Variant in effect_map.keys():
			var effect_id: String = str(effect_id_variant)
			target[effect_id] = float(target.get(effect_id, 0.0)) + float(effect_map[effect_id_variant])


func get_active_buffs() -> Array[Dictionary]:
	var buff_counts: Dictionary = {}
	for buff_id: String in active_buff_ids:
		buff_counts[buff_id] = int(buff_counts.get(buff_id, 0)) + 1
	var buffs: Array[Dictionary] = []
	for buff_id: String in buff_counts.keys():
		var buff: Dictionary = BUFF_SYSTEM.get_buff(buff_id)
		if not buff.is_empty():
			buff["stack_count"] = int(buff_counts[buff_id])
			buffs.append(buff)
	return buffs


func get_buff_stacks() -> Dictionary:
	var buff_counts: Dictionary = {}
	for buff_id: String in active_buff_ids:
		buff_counts[buff_id] = int(buff_counts.get(buff_id, 0)) + 1
	return buff_counts


func get_attack_damage() -> int:
	var atk_bonus: float = _get_blessing_value("atk_percent")
	return int(round(float(player_stats.get_total_attack()) * damage_multiplier * (1.0 + atk_bonus)))


func get_attack_cooldown_duration() -> float:
	var set_cooldown_multiplier: float = maxf(1.0 - set_attack_cooldown_reduction, 0.2)
	return BASE_ATTACK_COOLDOWN * attack_cooldown_multiplier * set_cooldown_multiplier


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
	var preview_bonuses: Dictionary = equipment_system.get_preview_bonus_map(item)
	return {
		"attack": int(round(float(player_stats.get_attack_with_effects(preview_bonuses)) * damage_multiplier)),
		"defense": player_stats.get_defense_with_effects(preview_bonuses),
		"max_hp": max(player_stats.get_max_hp_with_effects(preview_bonuses) + bonus_max_hp - dungeon_max_hp_penalty, 1),
		"speed": int(round(player_stats.get_speed_with_effects(preview_bonuses))),
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


func reset_all_talents() -> void:
	if unlocked_talents.is_empty():
		return
	var total_cost: int = 0
	for talent_id: String in unlocked_talents:
		var talent: Dictionary = TALENT_DATA.get_talent(talent_id)
		total_cost += int(talent.get("cost", 0))
	var refund: int = int(floor(float(total_cost) * 0.9))
	unlocked_talents.clear()
	player_stats.rebuild_talent_bonuses(unlocked_talents)
	if refund > 0:
		inventory.add_item("talent_shard", refund)
	_refresh_all_stats()
	_save_persistent_state()


func start_dungeon_run() -> void:
	dungeon_run_loot.clear()
	_dungeon_run_time = 0.0
	dungeon_max_hp_penalty = 0
	dungeon_max_hp_penalty_percent = 0
	dungeon_max_hp_reference = 0
	current_dungeon_floor = 0
	_run_stat_modifiers.clear()
	_floor_stat_modifiers.clear()
	_refresh_runtime_stat_modifiers()
	clear_dungeon_buffs()
	equipment_system.mark_entry_equipment()
	_apply_tavern_buffs()
	undying_will_available = player_stats.has_undying_will()
	execute_skill_armed = false
	shadow_combo_count = 0
	shadow_guaranteed_crit_ready = false
	dragon_guard_trigger_floor = -1
	sprint_skill_time_left = 0.0
	sprint_skill_multiplier = 1.0
	var skill_system: Variant = _skill_system()
	if skill_system != null:
		skill_system.clear_dungeon_cooldowns()
	var achievement_manager: Variant = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.start_dungeon_run()
	dungeon_max_hp_reference = max(max_hp, 1)
	run_max_hp_penalty_changed.emit(dungeon_max_hp_penalty_percent)


func finish_dungeon_run(safe_return: bool) -> void:
	if not safe_return:
		lose_dungeon_run_loot()
		equipment_system.strip_dungeon_equipment()
		inventory.remove_item("copper", inventory.get_item_count("copper"))
		inventory.remove_item("silver", inventory.get_item_count("silver"))
		inventory.remove_item("gold", inventory.get_item_count("gold"))
		equipment_system.apply_death_penalty()
	equipment_system.clear_entry_locks()
	_tavern_buffs.clear()
	dungeon_run_loot.clear()
	dungeon_max_hp_penalty = 0
	dungeon_max_hp_penalty_percent = 0
	dungeon_max_hp_reference = 0
	current_dungeon_floor = 0
	_run_stat_modifiers.clear()
	_floor_stat_modifiers.clear()
	_refresh_runtime_stat_modifiers()
	clear_dungeon_buffs()
	execute_skill_armed = false
	shadow_combo_count = 0
	shadow_guaranteed_crit_ready = false
	dragon_guard_trigger_floor = -1
	sprint_skill_time_left = 0.0
	sprint_skill_multiplier = 1.0
	_refresh_all_stats()
	run_max_hp_penalty_changed.emit(dungeon_max_hp_penalty_percent)
	_save_persistent_state()


func record_dungeon_loot(item_id: String, quantity: int) -> void:
	for entry in dungeon_run_loot:
		if str(entry.get("id", "")) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			return
	dungeon_run_loot.append({"id": item_id, "quantity": quantity})


func add_tavern_buff(buff_type: String, buff_value: float) -> void:
	_tavern_buffs.append({"type": buff_type, "value": buff_value})


func _apply_tavern_buffs() -> void:
	for buff: Dictionary in _tavern_buffs:
		var btype: String = str(buff.get("type", ""))
		var bval: float = float(buff.get("value", 0.0))
		match btype:
			"damage_multiplier":
				damage_multiplier += bval
			"armor_reduction":
				armor_reduction += bval
			"loot_drop_multiplier":
				loot_drop_multiplier += bval
			"move_speed_multiplier":
				move_speed_multiplier += bval


func lose_dungeon_run_loot() -> void:
	for entry in dungeon_run_loot:
		inventory.remove_item(str(entry.get("id", "")), int(entry.get("quantity", 0)))


func get_dungeon_run_summary() -> Dictionary:
	var coins_gained: int = 0
	var coins_lost: int = 0
	var equips_gained: int = 0
	for entry: Dictionary in dungeon_run_loot:
		var item_id: String = str(entry.get("id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		if item_id == "" or quantity <= 0:
			continue
		var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
		if str(item_data.get("type", "")) == "equipment":
			equips_gained += quantity
		coins_gained += _get_currency_copper_value(item_id, quantity)
		var current_quantity: int = inventory.get_item_count(item_id) if inventory != null else 0
		coins_lost += _get_currency_copper_value(item_id, mini(quantity, current_quantity))
	return {
		"coins_gained": coins_gained,
		"coins_lost": coins_lost,
		"equips_gained": equips_gained,
		"loot_items": dungeon_run_loot.duplicate(true),
		"play_time": _dungeon_run_time,
	}


func _get_currency_copper_value(item_id: String, quantity: int) -> int:
	if quantity <= 0:
		return 0
	match item_id:
		"gold":
			return quantity * 1000
		"silver":
			return quantity * 10
		"copper":
			return quantity
		"wooden_coin":
			return int(floor(float(quantity) / 10.0))
		_:
			return 0


func show_status_message(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	status_message_requested.emit(message, color, duration)


func get_run_max_hp_penalty() -> int:
	return dungeon_max_hp_penalty


func get_run_max_hp_penalty_percent() -> int:
	return dungeon_max_hp_penalty_percent


func sacrifice_max_hp_percent_for_run(percent: float) -> int:
	if percent <= 0.0:
		return 0
	if dungeon_max_hp_reference <= 0:
		dungeon_max_hp_reference = max(max_hp, 1)
	var sacrifice_amount: int = maxi(int(ceil(float(dungeon_max_hp_reference) * percent)), 1)
	if max_hp - sacrifice_amount < 1:
		return 0
	dungeon_max_hp_penalty += sacrifice_amount
	dungeon_max_hp_penalty_percent += maxi(int(round(percent * 100.0)), 1)
	_refresh_all_stats()
	run_max_hp_penalty_changed.emit(dungeon_max_hp_penalty_percent)
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

	# Count stacks per buff
	var buff_counts: Dictionary = {}
	for buff_id: String in active_buff_ids:
		buff_counts[buff_id] = int(buff_counts.get(buff_id, 0)) + 1

	# Count unique buffs per tag for synergy check
	var tag_unique_counts: Dictionary = {}
	for buff_id: String in buff_counts.keys():
		var tag: String = BUFF_SYSTEM.get_buff_tag(buff_id)
		if tag != "":
			tag_unique_counts[tag] = int(tag_unique_counts.get(tag, 0)) + 1

	# Apply each buff with diminishing returns + synergy bonus
	for buff_id: String in buff_counts.keys():
		var stacks: int = int(buff_counts[buff_id])
		var scale: float = 1.0 + 0.5 * float(stacks - 1)
		var tag: String = BUFF_SYSTEM.get_buff_tag(buff_id)
		var synergy_mult: float = 1.1 if int(tag_unique_counts.get(tag, 0)) >= 3 else 1.0
		var eff: float = scale * synergy_mult
		match buff_id:
			"atk_up_1":
				damage_multiplier += 0.15 * eff
			"atk_up_2":
				damage_multiplier += 0.25 * eff
				move_speed_multiplier -= 0.1 * eff
			"crit_chance":
				crit_chance_bonus += 0.15 * eff
			"atk_speed":
				attack_cooldown_multiplier -= 0.3 * eff
			"lifesteal":
				lifesteal_ratio += 0.1 * eff
			"hp_up":
				bonus_max_hp += int(round(30.0 * eff))
			"armor":
				armor_reduction += 0.2 * eff
			"dodge_chance":
				dodge_chance += 0.15 * eff
			"regen":
				buff_regen_amount += int(round(1.0 * eff))
				buff_regen_interval = 3.0
			"speed_up":
				move_speed_multiplier += 0.25 * eff
			"loot_up":
				loot_drop_multiplier += 1.0 * eff
			"aoe_attack":
				aoe_attack_multiplier += 0.5 * eff

	# Apply meal buff (from cooked food consumed this run)
	if not active_meal_buff.is_empty():
		damage_multiplier += float(active_meal_buff.get("damage_multiplier", 0.0))
		armor_reduction += float(active_meal_buff.get("armor_reduction", 0.0))
		move_speed_multiplier += float(active_meal_buff.get("move_speed_multiplier", 0.0))
		attack_cooldown_multiplier += float(active_meal_buff.get("attack_cooldown_multiplier", 0.0))
		bonus_max_hp += int(active_meal_buff.get("bonus_max_hp", 0))
		buff_regen_amount += int(active_meal_buff.get("buff_regen_amount", 0))

	# Clamp to sensible ranges
	move_speed_multiplier = maxf(move_speed_multiplier, 0.5)
	attack_cooldown_multiplier = maxf(attack_cooldown_multiplier, 0.2)
	armor_reduction = minf(armor_reduction, 0.85)
	dodge_chance = minf(dodge_chance, 0.75)
	_refresh_all_stats()


func _on_player_stats_changed() -> void:
	_refresh_all_stats()


func _on_equipment_changed() -> void:
	var bonus_map: Dictionary = equipment_system.get_total_bonus_map()
	player_stats.set_equipment_bonuses(bonus_map)
	equipment_lifesteal_ratio = float(bonus_map.get("lifesteal_ratio", 0.0))
	set_attack_cooldown_reduction = float(bonus_map.get("attack_cooldown_reduction", 0.0))
	necromancer_summon_on_kill = float(bonus_map.get("necromancer_summon_on_kill", 0.0)) > 0.0
	lava_burst_on_hit = float(bonus_map.get("lava_burst_on_hit", 0.0)) > 0.0
	abyss_crit_heal = float(bonus_map.get("abyss_crit_heal", 0.0)) > 0.0
	shadow_combo_crit = float(bonus_map.get("shadow_combo_crit", 0.0)) > 0.0
	dragon_emergency_guard = float(bonus_map.get("dragon_emergency_guard", 0.0)) > 0.0
	if not shadow_combo_crit:
		shadow_combo_count = 0
		shadow_guaranteed_crit_ready = false
	legend_on_kill_aoe = false
	legend_block_heal = false
	legend_crit_lifesteal = false
	legend_dodge_on_sprint = false
	legend_eclipse_crit = false
	legend_chain_lightning = false
	legend_kill_count_bonus = false
	_apply_legendary_passives()
	_refresh_all_stats()
	_save_persistent_state()


func _apply_legendary_passives() -> void:
	var all_equipped: Dictionary = equipment_system.get_all_equipped()
	for slot_name: Variant in all_equipped.keys():
		var item: Dictionary = all_equipped[slot_name] as Dictionary
		if item.is_empty():
			continue
		if str(item.get("rarity", "")) == "Legendary" and item.has("legendary_effect"):
			LEGENDARY_ITEMS.apply_legendary_passive(self, item)


func _refresh_all_stats() -> void:
	var spd_bonus: float = _get_blessing_value("speed_percent")
	speed = player_stats.get_total_speed() * (1.0 + spd_bonus)
	var hp_bonus: float = _get_blessing_value("hp_percent")
	var base_max: int = player_stats.get_total_max_hp() + bonus_max_hp - dungeon_max_hp_penalty
	var cm_node: Node = get_node_or_null("/root/CycleModifier")
	if cm_node != null and cm_node.has_method("get_total_hp_modifier"):
		var hp_mod: float = float(cm_node.get_total_hp_modifier())
		if hp_mod < 0.0:
			base_max = maxi(int(round(float(base_max) * (1.0 + hp_mod))), 1)
	max_hp = maxi(int(round(float(base_max) * (1.0 + hp_bonus))), 1)
	current_hp = clamp(current_hp, 0, max_hp)
	if inventory != null:
		var base_inv_slots: int = 12
		var inv_bonus: int = player_stats.get_inventory_slots_bonus()
		inventory.max_slots = maxi(base_inv_slots + inv_bonus, base_inv_slots)
	stats_changed.emit()
	hp_changed.emit(current_hp, max_hp)


func _get_blessing_value(effect_name: String) -> float:
	var bs: Node = get_node_or_null("/root/BlessingSystem")
	if bs == null or not bs.has_method("get_total_effect_value"):
		return 0.0
	return float(bs.call("get_total_effect_value", effect_name))


func set_consumable_slot(slot_index: int, item_id_val: String) -> void:
	if slot_index == 0:
		consumable_q_id = item_id_val
	elif slot_index == 1:
		consumable_r_id = item_id_val
	if inventory != null:
		inventory.mark_dirty()


func get_consumable_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = [{}, {}]
	var pinned_ids: Array[String] = [consumable_q_id, consumable_r_id]
	var used_auto_ids: Array[String] = []
	for slot_index: int in range(slots.size()):
		var pinned_id: String = pinned_ids[slot_index]
		if pinned_id == "":
			continue
		slots[slot_index] = _find_consumable_stack_by_id(pinned_id)
		if not slots[slot_index].is_empty():
			used_auto_ids.append(str(slots[slot_index].get("id", "")))
	for slot_index: int in range(slots.size()):
		if not slots[slot_index].is_empty():
			continue
		if pinned_ids[slot_index] != "":
			continue
		var fallback_stack: Dictionary = _find_next_available_consumable(used_auto_ids)
		if fallback_stack.is_empty():
			continue
		slots[slot_index] = fallback_stack
		used_auto_ids.append(str(fallback_stack.get("id", "")))
	return slots


func _find_consumable_stack_by_id(item_id: String) -> Dictionary:
	if inventory == null or item_id == "":
		return {}
	for stack: Dictionary in inventory.items:
		if str(stack.get("type", "")) != "consumable":
			continue
		if str(stack.get("id", "")) == item_id:
			return stack.duplicate(true)
	return {}


func _find_next_available_consumable(excluded_ids: Array[String]) -> Dictionary:
	if inventory == null:
		return {}
	for stack: Dictionary in inventory.items:
		if str(stack.get("type", "")) != "consumable":
			continue
		var item_id: String = str(stack.get("id", ""))
		if excluded_ids.has(item_id):
			continue
		return stack.duplicate(true)
	return {}


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
	var meal_buff_data: Variant = effects.get("meal_buff", null)
	if meal_buff_data != null and typeof(meal_buff_data) == TYPE_DICTIONARY:
		var cm_famine: Node = get_node_or_null("/root/CycleModifier")
		if cm_famine != null and cm_famine.has_method("is_cooking_disabled") and cm_famine.is_cooking_disabled():
			show_status_message(LocaleManager.L("famine_cooking_blocked"), Color(1.0, 0.5, 0.3, 1.0), 2.5)
		else:
			var new_buff: Dictionary = meal_buff_data as Dictionary
			for key: Variant in new_buff.keys():
				var k: String = str(key)
				active_meal_buff[k] = float(active_meal_buff.get(k, 0.0)) + float(new_buff[k])
			_recalculate_buff_state()
			show_status_message(LocaleManager.L("meal_buff_active"), Color(1.0, 0.85, 0.45, 1.0))
	consumable_cooldown_left = BANDAGE_COOLDOWN
	if inventory != null:
		inventory.mark_dirty()
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
