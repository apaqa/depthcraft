extends Node2D
class_name PlayerAttackEffect

@onready var sprite: Sprite2D = $Sprite2D


func play_swing(facing_left: bool) -> void:
	scale = Vector2(0.5, 0.5)
	modulate = Color(1, 1, 1, 1)
	sprite.flip_h = facing_left
	sprite.rotation = deg_to_rad(-25 if facing_left else 25)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free)
