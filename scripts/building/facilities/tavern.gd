extends "res://scripts/building/building_base.gd"
class_name TavernFacility

const INTERACTION_PROMPT: String = "[E] 酒館"


func get_interaction_prompt() -> String:
	return INTERACTION_PROMPT


func interact(player: Node) -> void:
	if player == null:
		return
	if player.has_method("request_tavern_menu"):
		player.request_tavern_menu(self)


func requires_home_core() -> bool:
	return true
