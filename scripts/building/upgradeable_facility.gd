extends "res://scripts/building/building_base.gd"
class_name UpgradeableFacility

const MAX_UPGRADE_LEVEL := 5
const UPGRADE_COSTS := {
	2: {"wood": 10, "stone": 5},
	3: {"wood": 20, "stone": 10, "iron_ore": 5},
	4: {"wood": 30, "stone": 15, "iron_ore": 10},
	5: {"wood": 45, "stone": 25, "iron_ore": 15},
}

var upgrade_level: int = 1
var _star_label: Label = null


func _ready() -> void:
	super._ready()
	_create_star_label()


func _create_star_label() -> void:
	if _star_label != null:
		return
	_star_label = Label.new()
	_star_label.position = Vector2(-8.0, -40.0)
	_star_label.add_theme_font_size_override("font_size", 9)
	_star_label.modulate = Color(1.0, 0.9, 0.2, 1.0)
	_star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star_label)
	_update_star_label()


func _update_star_label() -> void:
	if _star_label == null:
		return
	_star_label.text = "★".repeat(upgrade_level)


func get_upgrade_level() -> int:
	return upgrade_level


func can_upgrade() -> bool:
	return upgrade_level < MAX_UPGRADE_LEVEL


func get_upgrade_button_text() -> String:
	return LocaleManager.L("upgrade_to_lv") % (upgrade_level + 1)


func get_upgrade_cost() -> Dictionary:
	if not can_upgrade():
		return {}
	return (UPGRADE_COSTS.get(upgrade_level + 1, {}) as Dictionary).duplicate(true)


func can_afford_upgrade(inventory) -> bool:
	if inventory == null or not can_upgrade():
		return false
	for resource_id in get_upgrade_cost().keys():
		if inventory.get_item_count(str(resource_id)) < int(get_upgrade_cost()[resource_id]):
			return false
	return true


func try_upgrade(player) -> bool:
	if player == null or player.inventory == null or not can_upgrade():
		return false
	if not can_afford_upgrade(player.inventory):
		return false
	var cost := get_upgrade_cost()
	for resource_id in cost.keys():
		player.inventory.remove_item(str(resource_id), int(cost[resource_id]))
	upgrade_level += 1
	_update_star_label()
	_on_upgrade_applied()
	AudioManager.play_sfx("upgrade")
	hp_bar_time_left = DAMAGE_BAR_DURATION
	building_state_changed.emit()
	return true


func _serialize_extra_state() -> Dictionary:
	return {"upgrade_level": upgrade_level}


func get_upgrade_summary() -> String:
	return ""


func _load_extra_state(data: Dictionary) -> void:
	upgrade_level = clampi(int(data.get("upgrade_level", 1)), 1, MAX_UPGRADE_LEVEL)
	_update_star_label()


func _apply_upgrade_visuals() -> void:
	super._apply_upgrade_visuals()
	if _sprite == null:
		return
	var level_offset = max(upgrade_level - 1, 0)
	_sprite.scale = _base_sprite_scale * (1.0 + float(level_offset) * 0.1)
	_sprite.modulate = _base_sprite_modulate.lerp(Color(1.0, 1.0, 1.0, 1.0), min(float(level_offset) * 0.1, 0.2))


func _on_upgrade_applied() -> void:
	_apply_upgrade_visuals()
