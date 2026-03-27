extends SceneTree

const FILES := [
	"res://scripts/systems/achievement_manager.gd",
	"res://scripts/ui/achievement_popup.gd",
	"res://scripts/ui/achievement_panel.gd",
	"res://scripts/ui/hud.gd",
	"res://scripts/player/player.gd",
	"res://scripts/building/building_system.gd",
	"res://scripts/dungeon/dungeon_level.gd",
	"res://scripts/dungeon/loot_drop.gd",
	"res://scripts/crafting/crafting_system.gd",
	"res://scripts/enemies/boss_enemy.gd",
	"res://scenes/ui/achievement_popup.tscn",
	"res://scenes/ui/achievement_panel.tscn",
	"res://scenes/ui/hud.tscn",
]


func _init() -> void:
	var had_error := false
	for file_path in FILES:
		var resource := load(file_path)
		if resource == null:
			had_error = true
			print("PARSE_FAIL ", file_path)
		else:
			print("PARSE_OK ", file_path)
	quit(1 if had_error else 0)
