extends Node2D

@onready var hud: Control = $HUDCanvas/HUD
@onready var dungeon_level: Node2D = $DungeonLevel


func _ready() -> void:
	if hud.has_method("update_hp"):
		hud.update_hp(100, 100)
