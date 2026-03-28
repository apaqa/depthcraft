extends Node
class_name Inventory

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal inventory_changed

@export var max_slots: int = 20
var items: Array[Dictionary] = []

var _dirty: bool = false
var _refresh_timer: float = 0.0


func _process(delta: float) -> void:
	if _dirty:
		_refresh_timer += delta
		if _refresh_timer >= 0.1:
			_dirty = false
			_refresh_timer = 0.0
			inventory_changed.emit()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_refresh_timer = 0.0


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
	_mark_dirty()
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
	_mark_dirty()
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
	var payment := get_exact_currency_payment(amount)
	if payment.is_empty():
		return false
	for coin_type in ["gold", "silver", "copper"]:
		var coin_count := int(payment.get(coin_type, 0))
		if coin_count > 0 and not remove_item(coin_type, coin_count):
			return false
	return true


func get_exact_currency_payment(amount: int) -> Dictionary:
	var total := get_total_copper()
	if total < amount:
		return {}
	return _get_exact_currency_payment(amount)


func refund_currency(payment: Dictionary) -> void:
	for coin_type in ["gold", "silver", "copper"]:
		var coin_count := int(payment.get(coin_type, 0))
		if coin_count > 0:
			add_item(coin_type, coin_count)


func add_items_batch(batch: Dictionary) -> void:
	var did_add: bool = false
	for item_id_var: Variant in batch.keys():
		var item_id: String = str(item_id_var)
		var quantity: int = int(batch[item_id_var])
		if quantity <= 0:
			continue
		var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
		if item_data.is_empty():
			continue
		var remaining: int = quantity
		for stack: Dictionary in items:
			if stack["id"] != item_id:
				continue
			if int(stack.get("max_stack", 1)) <= 1:
				continue
			var free_space: int = int(stack["max_stack"]) - int(stack["quantity"])
			if free_space <= 0:
				continue
			var added: int = mini(remaining, free_space)
			stack["quantity"] += added
			remaining -= added
			if remaining <= 0:
				break
		while remaining > 0:
			if items.size() >= max_slots:
				break
			var stack_size: int = mini(remaining, int(item_data.get("max_stack", 1)))
			var new_stack: Dictionary = item_data.duplicate(true)
			new_stack["quantity"] = stack_size
			items.append(new_stack)
			remaining -= stack_size
		did_add = true
	if did_add:
		_mark_dirty()


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
	_mark_dirty()
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


func _get_exact_currency_payment(amount: int) -> Dictionary:
	var remaining := amount
	var payment := {
		"gold": 0,
		"silver": 0,
		"copper": 0,
	}
	var gold_needed = min(get_item_count("gold"), remaining / 100)
	payment["gold"] = gold_needed
	remaining -= gold_needed * 100

	var silver_needed = min(get_item_count("silver"), remaining / 10)
	payment["silver"] = silver_needed
	remaining -= silver_needed * 10

	var copper_needed = min(get_item_count("copper"), remaining)
	payment["copper"] = copper_needed
	remaining -= copper_needed

	return payment if remaining == 0 else {}
