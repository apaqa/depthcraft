extends StaticBody2D
class_name HomeCore

signal core_placed(position: Vector2)
signal destroyed

@onready var sprite: Sprite2D = $Sprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var hp_bar_root: Node2D = $HPBar
@onready var hp_fill: Polygon2D = $HPBar/Fill

const MAX_UPGRADE_LEVEL: int = 5
const HP_PER_LEVEL: int = 50

var is_placed: bool = false
var core_position: Vector2 = Vector2.ZERO
var pulse_tween: Tween = null
var max_hp: int = 500
var current_hp: int = 500
var raid_active: bool = false
var hp_bar_time_left: float = 0.0
var upgrade_level: int = 1


func _ready() -> void:
	set_process(false)
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
	if raid_active:
		set_process(true)
	if hp_bar_root != null:
		hp_bar_root.visible = (raid_active or hp_bar_time_left > 0.0) and current_hp > 0


func take_raid_damage(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	hp_bar_time_left = 2.5
	set_process(true)
	_update_hp_bar()
	if current_hp <= 0:
		destroyed.emit()
		queue_free()


func restore_to_full() -> void:
	current_hp = max_hp
	hp_bar_time_left = 0.0
	_update_hp_bar()


func get_upgrade_level() -> int:
	return upgrade_level


func can_upgrade() -> bool:
	return upgrade_level < MAX_UPGRADE_LEVEL


func get_upgrade_cost() -> Dictionary:
	if not can_upgrade():
		return {}
	return {"wood": upgrade_level * 5, "stone": upgrade_level * 3}


func can_afford_upgrade(inventory: Node) -> bool:
	if inventory == null or not can_upgrade():
		return false
	var cost: Dictionary = get_upgrade_cost()
	for resource_id: Variant in cost.keys():
		if inventory.get_item_count(str(resource_id)) < int(cost[resource_id]):
			return false
	return true


func try_upgrade(p: Node) -> bool:
	if p == null or not can_upgrade():
		return false
	var inv: Variant = p.get("inventory")
	if inv == null or not can_afford_upgrade(inv):
		return false
	var cost: Dictionary = get_upgrade_cost()
	for resource_id: Variant in cost.keys():
		inv.remove_item(str(resource_id), int(cost[resource_id]))
	upgrade_level += 1
	max_hp += HP_PER_LEVEL
	current_hp = min(current_hp + HP_PER_LEVEL, max_hp)
	_update_hp_bar()
	print("Home Core upgraded to level %d" % upgrade_level)
	return true


func _process(delta: float) -> void:
	hp_bar_time_left = max(hp_bar_time_left - delta, 0.0)
	if hp_bar_root != null:
		hp_bar_root.visible = (raid_active or hp_bar_time_left > 0.0) and current_hp > 0
	if hp_bar_time_left <= 0.0 and not raid_active:
		set_process(false)


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
	var ratio: float = clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	hp_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(28.0 * ratio, 0), Vector2(28.0 * ratio, 4), Vector2(0, 4)])

