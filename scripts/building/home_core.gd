extends StaticBody2D
class_name HomeCore

signal core_placed(position: Vector2)
signal destroyed

@onready var sprite: Sprite2D = $Sprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var hp_bar_root: Node2D = $HPBar
@onready var hp_fill: Polygon2D = $HPBar/Fill

var is_placed: bool = false
var core_position: Vector2 = Vector2.ZERO
var pulse_tween: Tween = null
var max_hp: int = 500
var current_hp: int = 500
var raid_active: bool = false
var hp_bar_time_left: float = 0.0


func _ready() -> void:
	set_process(true)
	_start_pulse()
	_update_hp_bar()


func place_at(world_position: Vector2) -> void:
	global_position = world_position
	core_position = world_position
	is_placed = true
	current_hp = max_hp
	_update_hp_bar()
	core_placed.emit(world_position)


func set_raid_active(active: bool) -> void:
	raid_active = active
	if hp_bar_root != null:
		hp_bar_root.visible = (raid_active or hp_bar_time_left > 0.0) and current_hp > 0


func take_raid_damage(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	hp_bar_time_left = 2.5
	_update_hp_bar()
	if current_hp <= 0:
		destroyed.emit()
		queue_free()


func restore_to_full() -> void:
	current_hp = max_hp
	hp_bar_time_left = 0.0
	_update_hp_bar()


func _process(delta: float) -> void:
	hp_bar_time_left = max(hp_bar_time_left - delta, 0.0)
	if hp_bar_root != null:
		hp_bar_root.visible = (raid_active or hp_bar_time_left > 0.0) and current_hp > 0


func _start_pulse() -> void:
	if pulse_tween != null:
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.2, 1.0), 1.0)
	pulse_tween.parallel().tween_property(point_light, "energy", 0.9, 1.0)
	pulse_tween.tween_property(sprite, "modulate", Color(0.9, 0.9, 0.9, 1.0), 1.0)
	pulse_tween.parallel().tween_property(point_light, "energy", 0.55, 1.0)


func _update_hp_bar() -> void:
	if hp_fill == null:
		return
	var ratio := clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	hp_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(28.0 * ratio, 0), Vector2(28.0 * ratio, 4), Vector2(0, 4)])

