extends Camera2D

@export var smoothing_speed: float = 8.0
@export var default_zoom: Vector2 = Vector2(1.5, 1.5)


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	zoom = default_zoom
