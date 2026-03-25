extends Node2D
class_name PlayerAttackEffect

@onready var sprite: Sprite2D = $Sprite2D


func play_swing(attack_direction: Vector2) -> void:
	var resolved_direction := attack_direction.normalized() if attack_direction.length_squared() > 0.0 else Vector2.RIGHT
	scale = Vector2(0.5, 0.5)
	modulate = Color(1, 1, 1, 1)
	rotation = resolved_direction.angle()
	sprite.flip_h = resolved_direction.x < 0.0
	sprite.rotation = deg_to_rad(35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.tween_property(self, "rotation", rotation + deg_to_rad(110 if resolved_direction.x >= 0.0 else -110), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free)
