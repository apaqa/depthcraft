extends Area2D
class_name EnemyProjectile

@export var speed: float = 120.0
@export var damage: int = 12
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT

@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not lifetime_timer.timeout.is_connected(queue_free):
		lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start(lifetime)


func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta


func setup(start_position: Vector2, travel_direction: Vector2, projectile_damage: int) -> void:
	global_position = start_position
	direction = travel_direction.normalized()
	damage = projectile_damage
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if body != null and body.has_method("take_damage") and not body.is_in_group("enemies"):
		body.take_damage(damage)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var owner_node = area.get_parent()
	if owner_node != null and owner_node.has_method("take_damage") and not owner_node.is_in_group("enemies"):
		owner_node.take_damage(damage)
		queue_free()

