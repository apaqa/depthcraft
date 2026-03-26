extends Node2D
class_name SafeRoom

const TILE_SIZE := 16.0
const BACKDROP_FILL_COLOR := Color(0.22, 0.62, 0.34, 0.24)
const BACKDROP_BORDER_COLOR := Color(0.58, 0.92, 0.68, 0.9)
const POOL_OUTER_COLOR := Color(0.24, 0.78, 0.4, 0.88)
const POOL_INNER_COLOR := Color(0.72, 1.0, 0.82, 0.94)
const HEAL_INTERVAL := 1.0
const HEAL_PERCENT_PER_TICK := 0.05

var _room: Rect2i
var _built: bool = false
var _healing_bodies: Dictionary = {}


func setup(room: Rect2i) -> void:
	_room = room
	_build_room()
	set_physics_process(true)


func _ready() -> void:
	_build_room()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _healing_bodies.is_empty():
		return
	var expired_ids: Array[int] = []
	for body_id in _healing_bodies.keys():
		var state := _healing_bodies[body_id] as Dictionary
		var body = state.get("body", null)
		if body == null or not is_instance_valid(body):
			expired_ids.append(body_id)
			continue
		state["elapsed"] = float(state.get("elapsed", 0.0)) + delta
		while float(state.get("elapsed", 0.0)) >= HEAL_INTERVAL:
			state["elapsed"] = float(state.get("elapsed", 0.0)) - HEAL_INTERVAL
			_heal_body(body)
		_healing_bodies[body_id] = state
	for body_id in expired_ids:
		_healing_bodies.erase(body_id)


func _build_room() -> void:
	if _built or _room.size == Vector2i.ZERO:
		return
	_built = true
	_add_backdrop()
	_add_healing_pool()


func _add_backdrop() -> void:
	var room_start := Vector2(_room.position.x * TILE_SIZE, _room.position.y * TILE_SIZE)
	var room_end := Vector2(_room.end.x * TILE_SIZE, _room.end.y * TILE_SIZE)

	var fill := Polygon2D.new()
	fill.z_index = -2
	fill.color = BACKDROP_FILL_COLOR
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	add_child(fill)

	var border := Line2D.new()
	border.z_index = -1
	border.width = 2.0
	border.default_color = BACKDROP_BORDER_COLOR
	border.closed = true
	border.points = PackedVector2Array([
		room_start + Vector2(2.0, 2.0),
		Vector2(room_end.x - 2.0, room_start.y + 2.0),
		room_end - Vector2(2.0, 2.0),
		Vector2(room_start.x + 2.0, room_end.y - 2.0),
	])
	add_child(border)


func _add_healing_pool() -> void:
	var center := _room_center_world()
	var pool_area := Area2D.new()
	pool_area.position = center
	pool_area.monitoring = true
	pool_area.monitorable = true
	pool_area.body_entered.connect(_on_pool_body_entered)
	pool_area.body_exited.connect(_on_pool_body_exited)
	add_child(pool_area)

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	pool_area.add_child(collision)

	var outer_ring := Polygon2D.new()
	outer_ring.color = POOL_OUTER_COLOR
	outer_ring.polygon = _make_circle_polygon(20.0, 24)
	pool_area.add_child(outer_ring)

	var inner_ring := Polygon2D.new()
	inner_ring.color = POOL_INNER_COLOR
	inner_ring.polygon = _make_circle_polygon(12.0, 18)
	pool_area.add_child(inner_ring)

	var title := Label.new()
	title.position = center + Vector2(-40.0, -40.0)
	title.size = Vector2(80.0, 20.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Healing Pool"
	title.label_settings = _create_label_settings(Color(0.92, 1.0, 0.94, 1.0), Color(0.05, 0.16, 0.08, 1.0), 12)
	add_child(title)


func _on_pool_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	_healing_bodies[body.get_instance_id()] = {"body": body, "elapsed": 0.0}


func _on_pool_body_exited(body: Node) -> void:
	if body == null:
		return
	_healing_bodies.erase(body.get_instance_id())


func _heal_body(body: Node) -> void:
	if body == null or not body.has_method("heal"):
		return
	var max_hp := int(body.get("max_hp"))
	if max_hp <= 0:
		return
	var heal_amount := maxi(int(round(max_hp * HEAL_PERCENT_PER_TICK)), 1)
	body.heal(heal_amount)


func _room_center_world() -> Vector2:
	var center_tile := _room.position + _room.size / 2
	return Vector2(center_tile.x * TILE_SIZE + 8.0, center_tile.y * TILE_SIZE + 8.0)


func _create_label_settings(font_color: Color, outline_color: Color, font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_color = font_color
	settings.outline_color = outline_color
	settings.outline_size = 2
	settings.font_size = font_size
	return settings


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(point_count):
		var angle := TAU * float(point_index) / float(point_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
