extends CharacterBody2D

@export var speed: float = 80.0
@export var sprint_speed: float = 140.0

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal interaction_prompt_changed(prompt_text: String)
signal interaction_prompt_cleared
signal portal_requested(target_level_id: String)
signal build_mode_changed(active: bool)
signal crafting_requested(facility)
signal storage_requested(facility)
signal repair_requested(facility)
signal hp_changed(current_hp: int, max_hp: int)
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
var is_dead: bool = false


func _ready() -> void:
	_configure_input_actions()
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	building_system.build_state_changed.connect(_on_build_state_changed)
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

	var input_direction := get_input_vector()
	var move_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
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
	current_hp = max(current_hp - amount, 0)
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
	await get_tree().create_timer(2.0).timeout
	died.emit()


func heal_to_full() -> void:
	is_dead = false
	current_hp = max_hp
	invincible_time_left = 0.0
	hp_changed.emit(current_hp, max_hp)


func perform_attack() -> void:
	if attack_cooldown_left > 0.0:
		return
	attack_cooldown_left = 0.4
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = Vector2(24, 20)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(0.0, global_position + Vector2(16 if not animated_sprite.flip_h else -16, 0))
	query.collision_mask = 1
	var results := get_world_2d().direct_space_state.intersect_shape(query)
	for result in results:
		var collider = result.get("collider", null)
		if collider != null and collider.has_method("take_damage") and collider != self:
			collider.take_damage(15)


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


func _set_key_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, event)

	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
