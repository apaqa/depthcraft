extends Camera2D

@export var smoothing_speed: float = 8.0
@export var default_zoom: Vector2 = Vector2(2.0, 2.0)


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	zoom = default_zoom
	_load_zoom_from_settings()


func shake(intensity: float, duration: float) -> void:
	var tween: Tween = create_tween()
	var steps: int = int(duration / 0.02)
	for i: int in range(steps):
		tween.tween_property(self, "offset",
			Vector2(randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)), 0.02)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.02)


func _load_zoom_from_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var file: FileAccess = FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return
	var settings: Dictionary = data as Dictionary
	if settings.has("camera_zoom"):
		var saved_zoom: float = clampf(float(settings["camera_zoom"]), 1.0, 4.0)
		zoom = Vector2(saved_zoom, saved_zoom)

