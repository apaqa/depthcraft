extends Node2D
class_name ArrowTrapLauncher

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/projectile.tscn")

@export var shot_interval: float = 1.45
@export var arrow_damage: int = 10
@export var projectile_speed: float = 190.0

var _direction: Vector2 = Vector2.RIGHT
var _timer_left: float = 0.0


func setup(fire_direction: Vector2, initial_delay: float = 0.0, damage_value: int = 10, interval_value: float = 1.45) -> void:
	_direction = fire_direction.normalized()
	if _direction.length_squared() <= 0.0:
		_direction = Vector2.RIGHT
	_timer_left = max(initial_delay, 0.0)
	arrow_damage = max(damage_value, 1)
	shot_interval = max(interval_value, 0.3)


func _ready() -> void:
	_build_visuals()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_timer_left = max(_timer_left - delta, 0.0)
	if _timer_left > 0.0:
		return
	_fire_arrow()
	_timer_left = shot_interval


func set_gameplay_paused(paused: bool) -> void:
	set_physics_process(not paused)


func _fire_arrow() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		return
	projectile.speed = projectile_speed
	projectile.lifetime = 2.1
	projectile.setup(global_position + _direction * 8.0, _direction, arrow_damage)
	parent_node.add_child(projectile)


func _build_visuals() -> void:
	if get_node_or_null("Base") != null:
		return
	var base: Polygon2D = Polygon2D.new()
	base.name = "Base"
	base.color = Color(0.48, 0.26, 0.12, 1.0)
	base.polygon = PackedVector2Array([
		Vector2(-7.0, -5.0),
		Vector2(7.0, -5.0),
		Vector2(7.0, 5.0),
		Vector2(-7.0, 5.0),
	])
	add_child(base)

	var slit: Line2D = Line2D.new()
	slit.width = 2.0
	slit.default_color = Color(0.92, 0.82, 0.58, 1.0)
	slit.points = PackedVector2Array([Vector2(-4.0, 0.0), Vector2(4.0, 0.0)])
	add_child(slit)
