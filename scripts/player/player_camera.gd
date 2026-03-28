extends Camera2D

@export var smoothing_speed: float = 8.0
@export var default_zoom: Vector2 = Vector2(2.0, 2.0)


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	zoom = default_zoom
	_load_zoom_from_settings()


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

