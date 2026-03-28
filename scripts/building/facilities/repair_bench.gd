extends "res://scripts/building/upgradeable_facility.gd"
class_name RepairBenchFacility


func get_interaction_prompt() -> String:
	return "[E] " + LocaleManager.L("repair")


func interact(player) -> void:
	if player != null and player.has_method("request_repair_menu"):
		player.request_repair_menu(self)


func requires_home_core() -> bool:
	return true


func get_repair_cost_multiplier() -> float:
	match get_upgrade_level():
		2:
			return 0.85
		3:
			return 0.7
		_:
			return 1.0


func get_upgrade_summary() -> String:
	match get_upgrade_level():
		1:
			return LocaleManager.L("repair_upgrade_1")
		2:
			return LocaleManager.L("repair_upgrade_2")
		_:
			return LocaleManager.L("repair_upgrade_3")
