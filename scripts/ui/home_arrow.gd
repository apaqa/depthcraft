extends Control

const EDGE_MARGIN := 28.0
const ARROW_SIZE := 28.0
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)

var player = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	size = Vector2.ONE * ARROW_SIZE
	pivot_offset = size * 0.5
	visible = false
	set_process(true)


func bind_player(new_player) -> void:
	player = new_player
	_update_arrow()


func _process(_delta: float) -> void:
	_update_arrow()


func _draw() -> void:
	var center := size * 0.5
	var tip := Vector2(center.x, 2.0)
	var left := Vector2(5.0, size.y - 6.0)
	var right := Vector2(size.x - 5.0, size.y - 6.0)
	var points := PackedVector2Array([tip, right, center + Vector2(0.0, 5.0), left])
	var outline := PackedVector2Array([tip, right, center + Vector2(0.0, 5.0), left, tip])
	draw_colored_polygon(points, ARROW_COLOR)
	draw_polyline(outline, OUTLINE_COLOR, 2.0, true)


func _update_arrow() -> void:
	var core = _get_home_core()
	var camera := get_viewport().get_camera_2d()
	if core == null or camera == null:
		visible = false
		return

	var viewport_rect := get_viewport_rect()
	var screen_pos: Vector2 = camera.unproject_position(core.global_position)
	var bounds := viewport_rect.grow(-EDGE_MARGIN)
	if bounds.has_point(screen_pos):
		visible = false
		return

	var center := viewport_rect.size * 0.5
	var direction := screen_pos - center
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	var edge_point := _project_to_edge(center, direction, bounds)
	position = edge_point - size * 0.5
	rotation = direction.angle() + PI * 0.5
	visible = true


func _project_to_edge(center: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var half_size := bounds.size * 0.5
	var scale_x := INF if is_zero_approx(direction.x) else absf(half_size.x / direction.x)
	var scale_y := INF if is_zero_approx(direction.y) else absf(half_size.y / direction.y)
	var scale := minf(scale_x, scale_y)
	return center + direction * scale


func _get_home_core():
	if player == null or not is_instance_valid(player):
		return null
	var building_system = player.building_system
	if building_system == null or not building_system.has_method("get_home_core"):
		return null
	var core = building_system.get_home_core()
	if core == null or not is_instance_valid(core):
		return null
	return core
