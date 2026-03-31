extends StaticBody2D
class_name LevelPortal

@export var target_level_id: String = "dungeon"
@export var prompt_text: String = "[E] Enter Portal"

const DOWN_TEXTURE: Texture2D = preload("res://assets/floor_stairs.png")

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite != null:
		sprite.texture = DOWN_TEXTURE
		sprite.modulate = Color(0.95, 0.95, 0.95, 1.0)


func get_interaction_prompt() -> String:
	if target_level_id == "dungeon" and _is_dungeon_locked():
		return "Cannot enter during raid"
	var resolved_prompt: String = prompt_text
	if target_level_id == "dungeon" and NpcManager != null and NpcManager.has_available_explorer_intel():
		resolved_prompt += NpcManager.get_explorer_prompt_suffix()
	return resolved_prompt


func interact(player) -> void:
	if target_level_id == "dungeon" and _is_dungeon_locked():
		if player != null and player.has_method("show_status_message"):
			player.show_status_message("Cannot enter during raid", Color(1.0, 0.35, 0.35, 1.0), 1.5)
		return
	if player == null:
		return
	if target_level_id == "dungeon":
		player.portal_requested.emit("tavern_floor", 1)
		return
	player.portal_requested.emit(target_level_id, 1)


func secondary_interact(player) -> void:
	if target_level_id != "dungeon" or NpcManager == null:
		return
	var explorer_intel: Dictionary = NpcManager.claim_explorer_intel(player)
	if explorer_intel.is_empty():
		return
	if player != null and player.has_method("show_status_message"):
		var intel_message: String = str(explorer_intel.get("message", ""))
		var intel_color: Color = Color(0.75, 0.95, 1.0, 1.0)
		if str(explorer_intel.get("type", "")) == "buff":
			intel_color = Color(0.75, 1.0, 0.75, 1.0)
		player.show_status_message(intel_message, intel_color, 3.2)


func _is_dungeon_locked() -> bool:
	var level: Node = get_parent()
	return level != null and level.has_method("is_raid_active") and level.is_raid_active()
