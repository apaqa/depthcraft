extends "res://scripts/building/upgradeable_facility.gd"
class_name CookingBenchFacility


const RECIPE_LEVELS := {
	1: ["bread", "stew"],
	2: ["bread", "stew"],
	3: ["bread", "stew", "herb_tea"],
}


func get_interaction_prompt() -> String:
	return LocaleManager.L("prompt_cooking")


func interact(player) -> void:
	if player != null and player.has_method("request_crafting_menu"):
		player.request_crafting_menu(self)


func get_recipe_ids() -> PackedStringArray:
	return PackedStringArray(RECIPE_LEVELS.get(get_upgrade_level(), RECIPE_LEVELS[1]))


func get_menu_title() -> String:
	return "%s Lv%d" % [LocaleManager.L("menu_title_cooking"), get_upgrade_level()]


func requires_home_core() -> bool:
	return true


func get_upgrade_summary() -> String:
	match get_upgrade_level():
		1:
			return LocaleManager.L("cooking_upgrade_1")
		2:
			return LocaleManager.L("cooking_upgrade_2")
		_:
			return LocaleManager.L("cooking_upgrade_3")
