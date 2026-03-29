extends Node2D
class_name SkeletonServant

const BODY_COLOR: Color = Color(0.86, 0.86, 0.92, 0.95)
const SHADOW_COLOR: Color = Color(0.18, 0.18, 0.22, 0.55)
const WEAPON_COLOR: Color = Color(0.55, 0.75, 1.0, 0.95)

var owner_player: Node2D = null
var lifetime_left: float = 15.0
var move_speed: float = 110.0
var attack_damage: int = 18
var attack_range: float = 20.0
var attack_cooldown: float = 0.9
var _attack_cooldown_left: float = 0.0
var _target_enemy: Node2D = null
var _body_polygon: Polygon2D = null
var _head_polygon: Polygon2D = null
var _weapon_polygon: Polygon2D = null


func _ready() -> void:
	add_to_group("player_summons")
	z_index = 3
	_build_visuals()


func setup(player_ref: Node2D, duration: float, damage_value: int) -> void:
	owner_player = player_ref
	lifetime_left = max(duration, 0.1)
	attack_damage = max(damage_value, 1)


func _process(delta: float) -> void:
	lifetime_left = max(lifetime_left - delta, 0.0)
	if lifetime_left <= 0.0:
		queue_free()
		return
	_attack_cooldown_left = max(_attack_cooldown_left - delta, 0.0)
	_target_enemy = _pick_target()
	if _target_enemy == null:
		if owner_player != null and is_instance_valid(owner_player):
			global_position = global_position.move_toward(owner_player.global_position + Vector2(18.0, -10.0), move_speed * delta)
		_update_facing(Vector2.RIGHT)
		return
	var to_enemy: Vector2 = _target_enemy.global_position - global_position
	if to_enemy.length() > attack_range:
		global_position += to_enemy.normalized() * move_speed * delta
	_update_facing(to_enemy)
	if to_enemy.length() <= attack_range and _attack_cooldown_left <= 0.0:
		_attack_target(to_enemy)


func _build_visuals() -> void:
	var shadow: Polygon2D = Polygon2D.new()
	shadow.color = SHADOW_COLOR
	shadow.polygon = PackedVector2Array([
		Vector2(-8.0, 8.0),
		Vector2(8.0, 8.0),
		Vector2(10.0, 11.0),
		Vector2(-10.0, 11.0),
	])
	add_child(shadow)

	_body_polygon = Polygon2D.new()
	_body_polygon.color = BODY_COLOR
	_body_polygon.polygon = PackedVector2Array([
		Vector2(-5.0, -4.0),
		Vector2(5.0, -4.0),
		Vector2(4.0, 8.0),
		Vector2(-4.0, 8.0),
	])
	add_child(_body_polygon)

	_head_polygon = Polygon2D.new()
	_head_polygon.color = BODY_COLOR.lightened(0.08)
	_head_polygon.polygon = PackedVector2Array([
		Vector2(-4.5, -10.0),
		Vector2(4.5, -10.0),
		Vector2(4.5, -2.0),
		Vector2(-4.5, -2.0),
	])
	add_child(_head_polygon)

	_weapon_polygon = Polygon2D.new()
	_weapon_polygon.color = WEAPON_COLOR
	_weapon_polygon.polygon = PackedVector2Array([
		Vector2(4.0, -1.0),
		Vector2(11.0, -4.0),
		Vector2(12.0, -2.0),
		Vector2(5.0, 1.0),
	])
	add_child(_weapon_polygon)


func _pick_target() -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance_sq: float = INF
	for enemy_variant: Variant in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if bool(enemy.get("is_dead")):
			continue
		var distance_sq: float = global_position.distance_squared_to(enemy.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy
	return closest_enemy


func _update_facing(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0:
		return
	var facing_sign: float = 1.0 if direction.x >= 0.0 else -1.0
	scale.x = absf(scale.x) * facing_sign


func _attack_target(direction: Vector2) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		return
	_attack_cooldown_left = attack_cooldown
	if _target_enemy.has_method("take_damage"):
		_target_enemy.take_damage(attack_damage, direction.normalized())
	if _target_enemy.has_method("apply_knockback"):
		_target_enemy.apply_knockback(direction.normalized(), 75.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.55), 0.08)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
