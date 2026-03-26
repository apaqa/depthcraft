extends "res://scripts/building/upgradeable_facility.gd"
class_name TalentAltarFacility


func get_interaction_prompt() -> String:
	return LocaleManager.L("prompt_talent")


func interact(player) -> void:
	if player != null and player.has_method("request_talent_menu"):
		player.request_talent_menu(self)


func requires_home_core() -> bool:
	return true


func get_menu_title() -> String:
	return "%s Lv%d" % [LocaleManager.L("prompt_talent"), get_upgrade_level()]


func get_upgrade_summary() -> String:
	match get_upgrade_level():
		1:
			return "A simple altar for awakening talents."
		2:
			return "The altar shines brighter with each ritual."
		_:
			return "The altar is fully awakened."
