extends Area2D
class_name SpikeTrap

@export var cycle_time: float = 2.0
@export var damage: int = 10

var active: bool = true
var _already_hit := {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var cycle_timer: Timer = $CycleTimer


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not cycle_timer.timeout.is_connected(_on_cycle_timer_timeout):
		cycle_timer.timeout.connect(_on_cycle_timer_timeout)
	cycle_timer.wait_time = cycle_time
	cycle_timer.start()
	_refresh_visuals()


func _on_body_entered(body: Node) -> void:
	if not active or body == null or _already_hit.has(body.get_instance_id()):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, Vector2.ZERO)
		_already_hit[body.get_instance_id()] = true


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	_already_hit.erase(body.get_instance_id())


func _on_cycle_timer_timeout() -> void:
	active = not active
	_already_hit.clear()
	_refresh_visuals()


func _refresh_visuals() -> void:
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if active else Color(0.5, 0.5, 0.5, 0.75)
	if collision_shape != null:
		collision_shape.disabled = not active
