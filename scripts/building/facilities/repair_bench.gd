extends StaticBody2D
class_name RepairBenchFacility


func get_interaction_prompt() -> String:
	return "[E] Repair"


func interact(player) -> void:
	if player != null and player.has_method("request_repair_menu"):
		player.request_repair_menu(self)


func serialize_data() -> Dictionary:
	return {}


func load_from_data(_data: Dictionary) -> void:
	pass
