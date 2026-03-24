extends CharacterBody2D

@export var speed: float = 80.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


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
