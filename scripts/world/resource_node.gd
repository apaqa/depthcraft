extends StaticBody2D
class_name ResourceNode

signal gathered(resource_id: String, quantity: int)
signal depleted
signal respawned

@export var resource_id: String = "wood"
@export var resource_name: String = "Tree"
@export var hits_to_gather: int = 3
@export var drop_quantity_min: int = 1
@export var drop_quantity_max: int = 3
@export var respawn_time: float = 60.0

var current_hits: int = 0
var is_depleted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var interaction_collision: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var respawn_timer: Timer = $RespawnTimer


func _ready() -> void:
	var timer := get_respawn_timer()
	if timer != null and not timer.timeout.is_connected(respawn):
		timer.timeout.connect(respawn)


func hit() -> void:
	if is_depleted:
		return

	current_hits += 1
	_play_hit_feedback()

	if current_hits >= hits_to_gather:
		gather()


func gather() -> void:
	if is_depleted:
		return

	var quantity := randi_range(drop_quantity_min, drop_quantity_max)
	is_depleted = true
	var current_sprite := get_sprite()
	if current_sprite != null:
		current_sprite.visible = false

	var collision := get_body_collision()
	if collision != null:
		collision.disabled = true

	var area_collision := get_interaction_collision()
	if area_collision != null:
		area_collision.disabled = true
	gathered.emit(resource_id, quantity)
	depleted.emit()

	var timer := get_respawn_timer()
	if respawn_time > 0.0 and timer != null:
		timer.start(respawn_time)


func respawn() -> void:
	current_hits = 0
	is_depleted = false
	var current_sprite := get_sprite()
	if current_sprite != null:
		current_sprite.visible = true

	var collision := get_body_collision()
	if collision != null:
		collision.disabled = false

	var area_collision := get_interaction_collision()
	if area_collision != null:
		area_collision.disabled = false
	respawned.emit()


func get_interaction_prompt() -> String:
	return "[E] %s %s" % [_get_action_verb(), resource_name]


func _get_action_verb() -> String:
	if resource_id == "wood":
		return "Chop"
	return "Mine"


func _play_hit_feedback() -> void:
	var current_sprite := get_sprite()
	if current_sprite == null:
		return

	if not is_inside_tree():
		current_sprite.position = Vector2.ZERO
		return

	current_sprite.position = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(current_sprite, "position", Vector2(3, 0), 0.05)
	tween.tween_property(current_sprite, "position", Vector2(-3, 0), 0.05)
	tween.tween_property(current_sprite, "position", Vector2.ZERO, 0.05)


func get_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	return get_node_or_null("Sprite2D")


func get_body_collision() -> CollisionShape2D:
	if body_collision != null:
		return body_collision
	return get_node_or_null("CollisionShape2D")


func get_interaction_collision() -> CollisionShape2D:
	if interaction_collision != null:
		return interaction_collision
	return get_node_or_null("InteractionArea/CollisionShape2D")


func get_respawn_timer() -> Timer:
	if respawn_timer != null:
		return respawn_timer
	return get_node_or_null("RespawnTimer")
