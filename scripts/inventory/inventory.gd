extends Node
class_name Inventory

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal inventory_changed

@export var max_slots: int = 20
var items: Array[Dictionary] = []


func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true

	var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
	if item_data.is_empty():
		return false

	var working_items: Array[Dictionary] = _duplicate_items(items)
	var remaining := quantity

	for stack in working_items:
		if stack["id"] != item_id:
			continue

		var free_space: int = int(stack["max_stack"]) - int(stack["quantity"])
		if free_space <= 0:
			continue

		var added: int = min(remaining, free_space)
		stack["quantity"] += added
		remaining -= added
		if remaining == 0:
			break

	while remaining > 0:
		if working_items.size() >= max_slots:
			return false

		var stack_quantity: int = min(remaining, int(item_data["max_stack"]))
		working_items.append({
			"id": item_data["id"],
			"name": item_data["name"],
			"quantity": stack_quantity,
			"max_stack": item_data["max_stack"],
			"type": item_data["type"],
			"icon": item_data["icon"],
		})
		remaining -= stack_quantity

	items = working_items
	inventory_changed.emit()
	return true


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true

	if get_item_count(item_id) < quantity:
		return false

	var remaining := quantity
	var working_items: Array[Dictionary] = _duplicate_items(items)

	for index in range(working_items.size() - 1, -1, -1):
		var stack := working_items[index]
		if stack["id"] != item_id:
			continue

		var removed: int = min(remaining, int(stack["quantity"]))
		stack["quantity"] -= removed
		remaining -= removed

		if stack["quantity"] <= 0:
			working_items.remove_at(index)

		if remaining == 0:
			break

	items = working_items
	inventory_changed.emit()
	return true


func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


func get_item_count(item_id: String) -> int:
	var count := 0
	for stack in items:
		if stack["id"] == item_id:
			count += stack["quantity"]
	return count


func get_free_slots() -> int:
	return max(max_slots - items.size(), 0)


func is_full() -> bool:
	return get_free_slots() == 0


func _duplicate_items(source_items: Array[Dictionary]) -> Array[Dictionary]:
	var copied_items: Array[Dictionary] = []
	for stack in source_items:
		copied_items.append(stack.duplicate())
	return copied_items
