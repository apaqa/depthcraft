extends CharacterBody2D

@export var speed: float = 80.0

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal interaction_prompt_changed(prompt_text: String)
signal interaction_prompt_cleared
signal portal_requested(target_level_id: String)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var inventory = $Inventory

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")

var nearby_resource = null
var nearby_portal = null
var last_interacted_resource = null


func _ready() -> void:
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)


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


func apply_input_direction(input_direction: Vector2) -> void:
	velocity = input_direction * speed
	update_sprite_state(input_direction)


func update_sprite_state(input_direction: Vector2) -> void:
	var sprite := get_animated_sprite()
	if sprite == null:
		return

	if input_direction.x != 0.0:
		sprite.flip_h = input_direction.x < 0.0

	if input_direction.is_zero_approx():
		sprite.play("idle")
	else:
		sprite.play("run")


func get_animated_sprite() -> AnimatedSprite2D:
	if animated_sprite != null:
		return animated_sprite
	return get_node_or_null("AnimatedSprite2D")


func _physics_process(_delta: float) -> void:
	var input_direction := get_input_vector()
	apply_input_direction(input_direction)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_gather()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("enter"):
		_try_enter_portal()
		get_viewport().set_input_as_handled()


func _try_gather() -> void:
	if nearby_resource == null or nearby_resource.is_depleted:
		return

	last_interacted_resource = nearby_resource
	nearby_resource.hit()
	if nearby_resource != null and nearby_resource.is_depleted:
		_clear_nearby_resource()


func _try_enter_portal() -> void:
	if nearby_portal == null:
		return

	portal_requested.emit(nearby_portal.target_level_id)


func _on_interaction_area_entered(area: Area2D) -> void:
	var owner = area.get_parent()

	if owner != null and owner.has_method("hit") and owner.has_method("get_interaction_prompt"):
		_set_nearby_resource(owner)
	elif owner != null and owner.has_method("get_interaction_prompt") and owner.has_method("get") and owner.get("target_level_id") != null:
		nearby_portal = owner
		_update_prompt()


func _on_interaction_area_exited(area: Area2D) -> void:
	var owner = area.get_parent()

	if owner == nearby_resource:
		_clear_nearby_resource()
	elif owner == nearby_portal:
		nearby_portal = null
		_update_prompt()


func _set_nearby_resource(resource) -> void:
	if nearby_resource == resource:
		_update_prompt()
		return

	if nearby_resource != null:
		_disconnect_resource_signals(nearby_resource)

	nearby_resource = resource
	nearby_resource.gathered.connect(_on_resource_gathered)
	nearby_resource.depleted.connect(_on_resource_depleted)
	nearby_resource.respawned.connect(_on_resource_respawned)
	_update_prompt()


func _clear_nearby_resource() -> void:
	if nearby_resource != null:
		_disconnect_resource_signals(nearby_resource)

	nearby_resource = null
	_update_prompt()


func _disconnect_resource_signals(resource) -> void:
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
	get_tree().current_scene.add_child(floating_text)


func _update_prompt() -> void:
	if nearby_resource != null and not nearby_resource.is_depleted:
		interaction_prompt_changed.emit(nearby_resource.get_interaction_prompt())
		return

	if nearby_portal != null:
		interaction_prompt_changed.emit(nearby_portal.get_interaction_prompt())
		return

	interaction_prompt_cleared.emit()
