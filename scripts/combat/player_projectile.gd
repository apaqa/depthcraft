extends Area2D
class_name PlayerProjectile

var speed: float = 300.0
var direction: Vector2 = Vector2.RIGHT
var max_range: float = 200.0
var pierce_count: int = 0
var owner_player: Variant = null
var guaranteed_crit: bool = false

var _distance_traveled: float = 0.0
var _hit_bodies: Array = []


func setup(proj_direction: Vector2, proj_speed: float, proj_max_range: float, proj_pierce: int, texture: Texture2D, player: Variant, proj_guaranteed_crit: bool, modulate_color: Color = Color.WHITE) -> void:
	direction = proj_direction.normalized()
	speed = proj_speed
	max_range = proj_max_range
	pierce_count = proj_pierce
	owner_player = player
	guaranteed_crit = proj_guaranteed_crit
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = 4
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 5.0
	shape_node.shape = shape
	add_child(shape_node)
	var sprite_node: Sprite2D = Sprite2D.new()
	sprite_node.name = "Sprite2D"
	sprite_node.texture = texture
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_node.modulate = modulate_color
	add_child(sprite_node)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var move: Vector2 = direction * speed * delta
	global_position += move
	_distance_traveled += move.length()
	if _distance_traveled >= max_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _hit_bodies.has(body):
		return
	if not body.has_method("take_damage"):
		return
	_hit_bodies.append(body)
	if owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("on_projectile_hit"):
		owner_player.on_projectile_hit(body, direction, guaranteed_crit)
	if pierce_count == 0:
		queue_free()
	elif pierce_count > 0:
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
