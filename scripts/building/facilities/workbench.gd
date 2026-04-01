extends "res://scripts/building/upgradeable_facility.gd"
class_name WorkbenchFacility


const RECIPE_LEVELS = {
	1: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch"],
	2: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch", "iron_sword"],
	3: ["wood_sword", "wood_shield", "stone_pickaxe", "leather_cap", "leather_vest", "bandage", "torch", "iron_sword", "iron_shield"],
}


func get_interaction_prompt() -> String:
	var lv_str: String = " Lv.%d" % get_upgrade_level()
	var upgrade_part: String = " / [U] " + LocaleManager.L("upgrade") if can_upgrade() else ""
	return "[E] " + LocaleManager.L("craft") + lv_str + upgrade_part


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
		3:
			return "Unlocks top-tier workbench recipes."
		4:
			return "Workbench mastery: all recipes available."
		_:
			return "Legendary craftsmanship unlocked."


func _on_upgrade_applied() -> void:
	super._on_upgrade_applied()
	print("Workbench upgraded to level %d" % get_upgrade_level())
