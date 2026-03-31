extends "res://scripts/building/building_base.gd"
class_name TavernFacility

func get_interaction_prompt() -> String:
	return LocaleManager.L("prompt_tavern")


func interact(player: Node) -> void:
	if player == null:
		return
	if player.has_method("show_status_message"):
		player.show_status_message(
			LocaleManager.L("tavern_moved_underground"),
			Color(0.85, 0.75, 0.45, 1.0), 3.0
		)


func requires_home_core() -> bool:
	return true
