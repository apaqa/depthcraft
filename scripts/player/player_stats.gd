extends Node
class_name PlayerStats

signal stats_changed

const TALENT_DATA := preload("res://scripts/talent/talent_data.gd")

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

var _talent_effects := {}
var _equipment_effects := {}


func rebuild_talent_bonuses(unlocked_talents: Array[String]) -> void:
	_talent_effects = {}
	for talent_id in unlocked_talents:
		var talent: Dictionary = TALENT_DATA.get_talent(talent_id)
		for effect_id in talent.get("effects", {}).keys():
			_talent_effects[effect_id] = float(_talent_effects.get(effect_id, 0.0)) + float(talent["effects"][effect_id])
	_emit_changed()


func set_equipment_bonuses(effects: Dictionary) -> void:
	_equipment_effects = effects.duplicate(true)
	_emit_changed()


func get_total_attack() -> int:
	return int(round(base_attack + _get_effect("attack")))


func get_total_defense() -> int:
	return int(round(base_defense + _get_effect("defense")))


func get_total_max_hp() -> int:
	return int(round(base_max_hp + _get_effect("max_hp")))


func get_total_speed() -> float:
	return base_speed * (1.0 + _get_effect("speed_multiplier")) + _get_effect("speed")


func get_total_crit_chance() -> float:
	return crit_chance + _get_effect("crit_chance")


func get_total_loot_bonus() -> float:
	return loot_bonus + _get_effect("loot_bonus")


func get_total_gather_bonus() -> int:
	return gather_bonus + int(round(_get_effect("gather_bonus")))


func get_crafting_cost_multiplier() -> float:
	return max(craft_cost_multiplier + _get_effect("craft_cost_multiplier"), 0.1)


func get_regen_amount() -> int:
	return regen_amount + int(round(_get_effect("regen_amount")))


func get_regen_interval() -> float:
	return _get_effect("regen_interval") if _get_effect("regen_interval") > 0.0 else regen_interval


func get_execute_bonus() -> float:
	return execute_bonus + _get_effect("execute_bonus")


func get_block_chance() -> float:
	return block_chance + _get_effect("block_chance")


func has_undying_will() -> bool:
	return undying_will or _get_effect("undying_will") > 0.0


func has_full_minimap() -> bool:
	return full_minimap or _get_effect("full_minimap") > 0.0


func get_loot_pickup_range() -> float:
	return 30.0 + _get_effect("loot_pickup_range")


func _get_effect(effect_id: String) -> float:
	return float(_talent_effects.get(effect_id, 0.0)) + float(_equipment_effects.get(effect_id, 0.0))


func _emit_changed() -> void:
	stats_changed.emit()

