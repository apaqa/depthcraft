extends StaticBody2D
class_name StorageChestFacility

signal chest_changed

@onready var inventory = $Inventory


func _ready() -> void:
	inventory.max_slots = 30
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)


func get_interaction_prompt() -> String:
	return "[E] 倉庫"


func interact(player) -> void:
	if player != null and player.has_method("request_storage_menu"):
		player.request_storage_menu(self)


func requires_home_core() -> bool:
	return true


func serialize_data() -> Dictionary:
	return {
		"inventory_items": inventory.get_state(),
	}


func load_from_data(data: Dictionary) -> void:
	inventory.max_slots = 30
	inventory.load_state(data.get("inventory_items", []))


func _on_inventory_changed() -> void:
	chest_changed.emit()
