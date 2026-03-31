extends "res://scripts/building/building_base.gd"
class_name TavernFacility

const INTERACTION_PROMPT: String = "[E] 酒館"


func get_interaction_prompt() -> String:
	return INTERACTION_PROMPT


func interact(player: Node) -> void:
	if player == null:
		return
	if player.has_method("show_status_message"):
		player.show_status_message(
			"酒館已搬到地下！請前往地牢入口。",
			Color(0.85, 0.75, 0.45, 1.0), 3.0
		)


func requires_home_core() -> bool:
	return true
