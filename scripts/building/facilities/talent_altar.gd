extends StaticBody2D
class_name TalentAltarFacility


func get_interaction_prompt() -> String:
	return "[E] 天賦樹"


func interact(player) -> void:
	if player != null and player.has_method("request_talent_menu"):
		player.request_talent_menu(self)


func requires_home_core() -> bool:
	return true


func serialize_data() -> Dictionary:
	return {}


func load_from_data(_data: Dictionary) -> void:
	pass
