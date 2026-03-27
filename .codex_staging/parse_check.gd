extends SceneTree
const FILES = [
    "res://scripts/building/facilities/cooking_bench.gd",
    "res://scripts/crafting/crafting_system.gd",
    "res://scripts/dungeon/challenge_room.gd",
    "res://scripts/dungeon/dungeon_level.gd",
    "res://scripts/dungeon/dungeon_merchant.gd",
    "res://scripts/dungeon/event_room.gd",
    "res://scripts/dungeon/loot_drop.gd",
    "res://scripts/dungeon/puzzle_room.gd",
    "res://scripts/dungeon/safe_room.gd",
    "res://scripts/dungeon/stairway.gd",
    "res://scripts/equipment/equipment_system.gd",
    "res://scripts/inventory/item_database.gd",
    "res://scripts/localization/locale_manager.gd",
    "res://scripts/player/player.gd",
    "res://scripts/skills/skill_system.gd",
    "res://scripts/talent/talent_data.gd",
    "res://scripts/ui/crafting_menu.gd",
    "res://scripts/ui/equipment_panel.gd",
    "res://scripts/ui/hud.gd",
    "res://scripts/ui/repair_ui.gd",
    "res://scripts/ui/settings_menu.gd",
    "res://scripts/ui/skill_equip_ui.gd",
    "res://scripts/ui/storage_ui.gd",
    "res://scripts/ui/talent_tree.gd",
    "res://scripts/world/merchant.gd",
    "res://scripts/world/tutorial_manager.gd",
    "res://scripts/building/facilities/talent_altar.gd",
]
func _init() -> void:
    var had_error := false
    for file_path in FILES:
        var script := load(file_path)
        if script == null:
            had_error = true
            print(file_path, ' PARSE_FAIL')
            continue
        print(file_path, ' PARSE_OK')
    quit(1 if had_error else 0)
