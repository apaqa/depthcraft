extends Node
class_name PlayerStats

signal stats_changed

const TALENT_DATA: Script = preload("res://scripts/talent/talent_data.gd")

var base_attack: int = 8
var base_defense: int = 0
var base_max_hp: int = 100
var base_speed: float = 80.0
var crit_chance: float = 0.0
var loot_bonus: float = 0.0
var gather_bonus: int = 0
var craft_cost_multiplier: float = 1.0
var regen_amount: int = 0
var regen_interval: float = 5.0
var execute_bonus: float = 0.0
var block_chance: float = 0.0
var undying_will: bool = false
var full_minimap: bool = false

var _talent_effects: Dictionary = {}
var _equipment_effects: Dictionary = {}
var _runtime_effects: Dictionary = {}


func rebuild_talent_bonuses(unlocked_talents: Array[String]) -> void:
	_talent_effects = {}
	for talent_id: String in unlocked_talents:
		var talent: Dictionary = TALENT_DATA.get_talent(talent_id)
		for effect_id_variant: Variant in talent.get("effects", {}).keys():
			var effect_id: String = str(effect_id_variant)
			_talent_effects[effect_id] = float(_talent_effects.get(effect_id, 0.0)) + float(talent["effects"][effect_id])
	_emit_changed()


func set_equipment_bonuses(effects: Dictionary) -> void:
	_equipment_effects = effects.duplicate(true)
	_emit_changed()


func set_runtime_bonuses(effects: Dictionary) -> void:
	_runtime_effects = effects.duplicate(true)
	_emit_changed()


func get_total_attack() -> int:
	return get_attack_with_effects(_equipment_effects)


func get_attack_with_effects(equipment_effects: Dictionary) -> int:
	var flat_attack: float = float(base_attack) + _get_combined_effect("attack", equipment_effects)
	var percent_bonus: float = _get_combined_effect("attack_percent", equipment_effects)
	return int(round(flat_attack * (1.0 + percent_bonus)))


func get_total_defense() -> int:
	return get_defense_with_effects(_equipment_effects)


func get_defense_with_effects(equipment_effects: Dictionary) -> int:
	var flat_defense: float = float(base_defense) + _get_combined_effect("defense", equipment_effects)
	var percent_bonus: float = _get_combined_effect("defense_percent", equipment_effects)
	return int(round(flat_defense * (1.0 + percent_bonus)))


func get_total_max_hp() -> int:
	return get_max_hp_with_effects(_equipment_effects)


func get_max_hp_with_effects(equipment_effects: Dictionary) -> int:
	var flat_max_hp: float = float(base_max_hp) + _get_combined_effect("max_hp", equipment_effects)
	var percent_bonus: float = _get_combined_effect("max_hp_percent", equipment_effects)
	return int(round(flat_max_hp * (1.0 + percent_bonus)))


func get_total_speed() -> float:
	return get_speed_with_effects(_equipment_effects)


func get_speed_with_effects(equipment_effects: Dictionary) -> float:
	return base_speed * (1.0 + _get_combined_effect("speed_multiplier", equipment_effects)) + _get_combined_effect("speed", equipment_effects)


func get_total_crit_chance() -> float:
	return crit_chance + _get_combined_effect("crit_chance", _equipment_effects)


func get_total_loot_bonus() -> float:
	return loot_bonus + _get_combined_effect("loot_bonus", _equipment_effects)


func get_total_gather_bonus() -> int:
	return gather_bonus + int(round(_get_combined_effect("gather_bonus", _equipment_effects)))


func get_crafting_cost_multiplier() -> float:
	return max(craft_cost_multiplier + _get_combined_effect("craft_cost_multiplier", _equipment_effects), 0.1)


func get_regen_amount() -> int:
	return regen_amount + int(round(_get_combined_effect("regen_amount", _equipment_effects)))


func get_regen_interval() -> float:
	var interval_bonus: float = _get_combined_effect("regen_interval", _equipment_effects)
	return interval_bonus if interval_bonus > 0.0 else regen_interval


func get_execute_bonus() -> float:
	return execute_bonus + _get_combined_effect("execute_bonus", _equipment_effects)


func get_block_chance() -> float:
	return block_chance + _get_combined_effect("block_chance", _equipment_effects)


func has_undying_will() -> bool:
	return undying_will or _get_combined_effect("undying_will", _equipment_effects) > 0.0


func has_full_minimap() -> bool:
	return full_minimap or _get_combined_effect("full_minimap", _equipment_effects) > 0.0


func get_loot_pickup_range() -> float:
	return 30.0 + _get_combined_effect("loot_pickup_range", _equipment_effects)


func _get_effect(effect_id: String) -> float:
	return float(_talent_effects.get(effect_id, 0.0)) + float(_equipment_effects.get(effect_id, 0.0)) + float(_runtime_effects.get(effect_id, 0.0))


func _get_combined_effect(effect_id: String, equipment_effects: Dictionary) -> float:
	return float(_talent_effects.get(effect_id, 0.0)) + float(equipment_effects.get(effect_id, 0.0))


func _emit_changed() -> void:
	stats_changed.emit()
