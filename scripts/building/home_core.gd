extends StaticBody2D
class_name HomeCore

signal core_placed(position: Vector2)

@onready var sprite: Sprite2D = $Sprite2D
@onready var point_light: PointLight2D = $PointLight2D

var is_placed: bool = false
var core_position: Vector2 = Vector2.ZERO
var pulse_tween: Tween = null


func _ready() -> void:
	_start_pulse()


func place_at(world_position: Vector2) -> void:
	global_position = world_position
	core_position = world_position
	is_placed = true
	core_placed.emit(world_position)


func _start_pulse() -> void:
	if pulse_tween != null:
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.2, 1.0), 1.0)
	pulse_tween.parallel().tween_property(point_light, "energy", 0.9, 1.0)
	pulse_tween.tween_property(sprite, "modulate", Color(0.9, 0.9, 0.9, 1.0), 1.0)
	pulse_tween.parallel().tween_property(point_light, "energy", 0.55, 1.0)
