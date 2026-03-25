extends StaticBody2D
class_name CookingBenchFacility


func get_interaction_prompt() -> String:
	return "[E] 烹飪"


func interact(player) -> void:
	if player != null and player.has_method("request_crafting_menu"):
		player.request_crafting_menu(self)


func get_recipe_ids() -> PackedStringArray:
	return PackedStringArray(["bread", "stew"])


func get_menu_title() -> String:
	return "烹飪"


func requires_home_core() -> bool:
	return true


func serialize_data() -> Dictionary:
	return {}


func load_from_data(_data: Dictionary) -> void:
	pass
