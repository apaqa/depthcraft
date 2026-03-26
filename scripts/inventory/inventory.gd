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

	return add_stack_data(item_data, quantity)


func add_stack(stack_data: Dictionary) -> bool:
	if stack_data.is_empty():
		return false
	return add_stack_data(stack_data, int(stack_data.get("quantity", 1)))


func add_stack_data(stack_template: Dictionary, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true

	var working_items: Array[Dictionary] = _duplicate_items(items)
	var remaining := quantity

	for stack in working_items:
		if stack["id"] != stack_template["id"]:
			continue
		if int(stack.get("max_stack", 1)) <= 1:
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

		var stack_quantity: int = min(remaining, int(stack_template["max_stack"]))
		var new_stack: Dictionary = stack_template.duplicate(true)
		new_stack["quantity"] = stack_quantity
		working_items.append(new_stack)
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


func get_total_copper() -> int:
	return get_item_count("copper") + get_item_count("silver") * 10 + get_item_count("gold") * 100


func pay_copper(amount: int) -> bool:
	var total := get_total_copper()
	if total < amount:
		return false
	var remainder := total - amount
	var copper_held := get_item_count("copper")
	var silver_held := get_item_count("silver")
	var gold_held := get_item_count("gold")
	if copper_held > 0:
		remove_item("copper", copper_held)
	if silver_held > 0:
		remove_item("silver", silver_held)
	if gold_held > 0:
		remove_item("gold", gold_held)
	var gold_back := remainder / 100
	var silver_back := (remainder % 100) / 10
	var copper_back := remainder % 10
	if gold_back > 0:
		add_item("gold", gold_back)
	if silver_back > 0:
		add_item("silver", silver_back)
	if copper_back > 0:
		add_item("copper", copper_back)
	return true


func get_free_slots() -> int:
	return max(max_slots - items.size(), 0)


func is_full() -> bool:
	return get_free_slots() == 0


func move_stack_to(target_inventory: Inventory, stack_index: int) -> bool:
	if target_inventory == null:
		return false
	if stack_index < 0 or stack_index >= items.size():
		return false

	var stack: Dictionary = items[stack_index].duplicate(true)
	if not target_inventory.add_stack(stack):
		return false

	items.remove_at(stack_index)
	inventory_changed.emit()
	return true


func get_state() -> Array[Dictionary]:
	return _duplicate_items(items)


func load_state(saved_items: Array) -> void:
	items.clear()
	for stack_variant in saved_items:
		if typeof(stack_variant) != TYPE_DICTIONARY:
			continue
		items.append((stack_variant as Dictionary).duplicate(true))
	inventory_changed.emit()


func _duplicate_items(source_items: Array[Dictionary]) -> Array[Dictionary]:
	var copied_items: Array[Dictionary] = []
	for stack in source_items:
		copied_items.append(stack.duplicate())
	return copied_items

