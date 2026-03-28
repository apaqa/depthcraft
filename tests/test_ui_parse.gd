extends SceneTree

const _HUD := preload("res://scripts/ui/hud.gd")
const _MINIMAP := preload("res://scripts/ui/minimap.gd")
const _EQUIPMENT_PANEL := preload("res://scripts/ui/equipment_panel.gd")
const _CRAFTING_MENU := preload("res://scripts/ui/crafting_menu.gd")
const _REPAIR_UI := preload("res://scripts/ui/repair_ui.gd")
const _STORAGE_UI := preload("res://scripts/ui/storage_ui.gd")
const _TALENT_TREE := preload("res://scripts/ui/talent_tree.gd")
const _SETTINGS_MENU := preload("res://scripts/ui/settings_menu.gd")
const _BUFF_SELECT := preload("res://scripts/ui/buff_select.gd")
const _SKILL_EQUIP_UI := preload("res://scripts/ui/skill_equip_ui.gd")
const _ACHIEVEMENT_PANEL := preload("res://scripts/ui/achievement_panel.gd")
const _QUEST_BOARD_UI := preload("res://scripts/ui/quest_board_ui.gd")
const _MERCHANT := preload("res://scripts/world/merchant.gd")


func _initialize() -> void:
	print("PARSE_OK: all UI scripts loaded successfully")
	quit(0)
