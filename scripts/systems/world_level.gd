extends Node

signal world_level_changed(world_level: int, deepest_floor_reached: int)

var deepest_floor_reached: int = 1
var world_level: int = 1


func _ready() -> void:
	_recalculate_world_level()


func set_deepest_floor_reached(floor_number: int) -> void:
	var resolved_floor: int = maxi(floor_number, 1)
	deepest_floor_reached = resolved_floor
	_recalculate_world_level()
	world_level_changed.emit(world_level, deepest_floor_reached)


func get_world_level() -> int:
	return world_level


func get_stat_multiplier() -> float:
	return 1.0 + float(world_level) * 0.04


func get_merchant_floor_value() -> int:
	return maxi(world_level * 5, 1)


func get_merchant_min_rarity() -> String:
	if world_level >= 8:
		return "Legendary"
	if world_level >= 6:
		return "Epic"
	if world_level >= 4:
		return "Rare"
	if world_level >= 2:
		return "Uncommon"
	return "Common"


func _recalculate_world_level() -> void:
	world_level = maxi(int(floor(float(deepest_floor_reached) / 5.0)), 1)
