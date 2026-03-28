extends Area2D
class_name LavaPatch

var damage: int = 8
var duration: float = 6.0
var tick_interval: float = 1.0

var _time_left: float = 0.0
var _tracked_bodies: Dictionary = {}


func setup(patch_damage: int, lifetime: float = 6.0, tick_seconds: float = 1.0) -> void:
	damage = max(patch_damage, 1)
	duration = max(lifetime, 0.5)
	tick_interval = max(tick_seconds, 0.2)
	_time_left = duration


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visuals()
	if _time_left <= 0.0:
		_time_left = duration
	set_process(true)


func _process(delta: float) -> void:
	_time_left = max(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		queue_free()
		return

	var expired_ids: Array[int] = []
	for body_id_variant: Variant in _tracked_bodies.keys():
		var body_id: int = int(body_id_variant)
		var body_state: Dictionary = _tracked_bodies[body_id] as Dictionary
		var body: Node = body_state.get("body", null)
		if body == null or not is_instance_valid(body):
			expired_ids.append(body_id)
			continue
		body_state["elapsed"] = float(body_state.get("elapsed", 0.0)) + delta
		while float(body_state.get("elapsed", 0.0)) >= tick_interval:
			body_state["elapsed"] = float(body_state.get("elapsed", 0.0)) - tick_interval
			_damage_body(body)
		_tracked_bodies[body_id] = body_state
	for expired_id: int in expired_ids:
		_tracked_bodies.erase(expired_id)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	_tracked_bodies[body.get_instance_id()] = {"body": body, "elapsed": 0.0}
	_damage_body(body)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	_tracked_bodies.erase(body.get_instance_id())


func _damage_body(body: Node) -> void:
	if body == null or not body.has_method("take_damage"):
		return
	body.take_damage(damage, Vector2.ZERO)


func _build_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 14.0
		collision_shape.shape = shape
		add_child(collision_shape)

	var outer_pool: Polygon2D = Polygon2D.new()
	outer_pool.color = Color(0.92, 0.24, 0.06, 0.84)
	outer_pool.polygon = _make_circle(16.0, 24)
	add_child(outer_pool)

	var inner_pool: Polygon2D = Polygon2D.new()
	inner_pool.color = Color(1.0, 0.68, 0.12, 0.92)
	inner_pool.polygon = _make_circle(9.0, 16)
	add_child(inner_pool)


func _make_circle(radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(point_count):
		var angle: float = TAU * float(point_index) / float(point_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
