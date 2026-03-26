extends StaticBody2D
class_name BuildingBase

signal building_state_changed
signal building_destroyed(origin_tile: Vector2i, refund_cost: Dictionary)

const HP_BAR_WIDTH := 24.0
const HP_BAR_HEIGHT := 4.0
const DAMAGE_BAR_DURATION := 2.5

var building_system = null
var building_id: String = ""
var origin_tile: Vector2i = Vector2i.ZERO
var building_cost: Dictionary = {}
var max_hp: int = 1
var current_hp: int = 1
var hp_bar_time_left: float = 0.0

var _sprite: Sprite2D = null
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_modulate: Color = Color.WHITE
var _hp_bar_root: Node2D = null
var _hp_bar_fill: Polygon2D = null


func _ready() -> void:
	set_process(true)
	_ensure_visual_refs()
	_ensure_hp_bar()
	_apply_upgrade_visuals()
	_update_hp_bar()


func _process(delta: float) -> void:
	hp_bar_time_left = max(hp_bar_time_left - delta, 0.0)
	_update_hp_bar_visibility()


func initialize_building(building: Dictionary, target_system, tile_pos: Vector2i, data: Dictionary = {}) -> void:
	building_system = target_system
	building_id = str(building.get("id", ""))
	origin_tile = tile_pos
	building_cost = (building.get("cost", {}) as Dictionary).duplicate(true)
	max_hp = int(data.get("max_hp", building.get("base_max_hp", 1)))
	if max_hp <= 0:
		max_hp = 1
	current_hp = clampi(int(data.get("current_hp", max_hp)), 0, max_hp)
	_load_extra_state(data)
	call_deferred("_refresh_runtime_state")


func serialize_data() -> Dictionary:
	var payload := {
		"max_hp": max_hp,
		"current_hp": current_hp,
	}
	payload.merge(_serialize_extra_state(), true)
	return payload


func take_damage(amount: int, _hit_direction: Vector2 = Vector2.ZERO) -> void:
	_take_building_damage(amount)


func take_raid_damage(amount: int) -> void:
	_take_building_damage(amount)


func is_player_owned_building() -> bool:
	return true


func get_origin_tile() -> Vector2i:
	return origin_tile


func get_refund_cost() -> Dictionary:
	return building_cost.duplicate(true)


func can_upgrade() -> bool:
	return false


func get_upgrade_level() -> int:
	return 1


func get_upgrade_button_text() -> String:
	return "Upgrade"


func get_upgrade_cost() -> Dictionary:
	return {}


func can_afford_upgrade(_inventory) -> bool:
	return false


func try_upgrade(_player) -> bool:
	return false


func get_upgrade_summary() -> String:
	return ""


func _serialize_extra_state() -> Dictionary:
	return {}


func _load_extra_state(_data: Dictionary) -> void:
	pass


func _apply_upgrade_visuals() -> void:
	_ensure_visual_refs()
	if _sprite == null:
		return
	_sprite.scale = _base_sprite_scale
	_sprite.modulate = _base_sprite_modulate


func _take_building_damage(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	hp_bar_time_left = DAMAGE_BAR_DURATION
	_update_hp_bar()
	building_state_changed.emit()
	if current_hp <= 0:
		building_destroyed.emit(origin_tile, get_refund_cost())
		queue_free()


func _refresh_runtime_state() -> void:
	_ensure_visual_refs()
	_ensure_hp_bar()
	_apply_upgrade_visuals()
	_update_hp_bar()


func _ensure_visual_refs() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D")
		if _sprite != null:
			_base_sprite_scale = _sprite.scale
			_base_sprite_modulate = _sprite.modulate


func _ensure_hp_bar() -> void:
	if _hp_bar_root != null:
		return
	_hp_bar_root = Node2D.new()
	_hp_bar_root.name = "HPBar"
	_hp_bar_root.position = Vector2(-HP_BAR_WIDTH * 0.5, -18.0)
	_hp_bar_root.visible = false
	add_child(_hp_bar_root)

	var hp_bg := Polygon2D.new()
	hp_bg.color = Color(0.12, 0.12, 0.16, 0.92)
	hp_bg.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(HP_BAR_WIDTH, 0.0),
		Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT),
		Vector2(0.0, HP_BAR_HEIGHT),
	])
	_hp_bar_root.add_child(hp_bg)

	_hp_bar_fill = Polygon2D.new()
	_hp_bar_fill.color = Color(0.9, 0.22, 0.22, 1.0)
	_hp_bar_root.add_child(_hp_bar_fill)


func _update_hp_bar() -> void:
	if _hp_bar_fill == null:
		return
	var ratio := clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	_hp_bar_fill.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(HP_BAR_WIDTH * ratio, 0.0),
		Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT),
		Vector2(0.0, HP_BAR_HEIGHT),
	])
	_update_hp_bar_visibility()


func _update_hp_bar_visibility() -> void:
	if _hp_bar_root == null:
		return
	_hp_bar_root.visible = current_hp > 0 and current_hp < max_hp and hp_bar_time_left > 0.0
