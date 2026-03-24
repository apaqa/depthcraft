extends StaticBody2D
class_name WorkbenchFacility


func get_interaction_prompt() -> String:
	return "[E] Craft"


func interact(player) -> void:
	if player != null and player.has_method("request_crafting_menu"):
		player.request_crafting_menu(self)


func serialize_data() -> Dictionary:
	return {}


func load_from_data(_data: Dictionary) -> void:
	pass
