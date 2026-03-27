extends "res://scripts/building/upgradeable_facility.gd"
class_name WorkbenchFacility


const RECIPE_LEVELS = {
	1: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch"],
	2: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch", "iron_sword"],
	3: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch", "iron_sword", "iron_shield"],
}


func get_interaction_prompt() -> String:
	return "[E] " + LocaleManager.L("craft")


func interact(player) -> void:
	if player != null and player.has_method("request_crafting_menu"):
		player.request_crafting_menu(self)


func get_menu_title() -> String:
	return "%s Lv%d" % [LocaleManager.L("workbench"), get_upgrade_level()]


func get_recipe_ids() -> PackedStringArray:
	return PackedStringArray(RECIPE_LEVELS.get(get_upgrade_level(), RECIPE_LEVELS[1]))


func requires_home_core() -> bool:
	return true


func get_upgrade_summary() -> String:
	match get_upgrade_level():
		1:
			return "Unlocks basic crafting recipes."
		2:
			return "Unlocks advanced leather and tool recipes."
		_:
			return "Unlocks top-tier workbench recipes."
