extends Node
class_name EquipmentSystem

signal equipment_changed

const SLOT_ORDER := ["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand", "tool"]

var _equipped := {}


func _ready() -> void:
	for slot_name in SLOT_ORDER:
		_equipped[slot_name] = {}


func get_slot_order() -> PackedStringArray:
	return PackedStringArray(SLOT_ORDER)


func get_equipped(slot_name: String) -> Dictionary:
	return (_equipped.get(slot_name, {}) as Dictionary).duplicate(true)


func get_all_equipped() -> Dictionary:
	var payload := {}
	for slot_name in SLOT_ORDER:
		payload[slot_name] = get_equipped(slot_name)
	return payload


func equip_from_inventory(inventory, stack_index: int) -> bool:
	if inventory == null or stack_index < 0 or stack_index >= inventory.items.size():
		return false
	var stack: Dictionary = inventory.items[stack_index].duplicate(true)
	if str(stack.get("type", "")) != "equipment":
		return false
	var slot_name := str(stack.get("slot", ""))
	if slot_name == "":
		return false
	if not inventory.remove_item(str(stack.get("id", "")), 1):
		return false
	var previous := equip(stack, slot_name)
	if not previous.is_empty():
		inventory.add_stack(previous)
	return true


func equip(item_data: Dictionary, slot_name: String = "") -> Dictionary:
	var resolved_slot := slot_name if slot_name != "" else str(item_data.get("slot", ""))
	if not _equipped.has(resolved_slot):
		return {}
	var previous: Dictionary = get_equipped(resolved_slot)
	var equipped_item := item_data.duplicate(true)
	equipped_item["quantity"] = 1
	_equipped[resolved_slot] = equipped_item
	equipment_changed.emit()
	return previous


func unequip(slot_name: String, inventory = null) -> Dictionary:
	if not _equipped.has(slot_name):
		return {}
	var item: Dictionary = get_equipped(slot_name)
	if item.is_empty():
		return {}
	if inventory != null and not inventory.add_stack(item):
		return {}
	_equipped[slot_name] = {}
	equipment_changed.emit()
	return item


func get_total_equipment_bonus(stat_name: String) -> float:
	var total := 0.0
	for slot_name in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		total += _get_item_stat_bonus(item, stat_name)
	return total


func get_total_bonus_map() -> Dictionary:
	var totals := {}
	for slot_name in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		for stat_name in (item.get("stats", {}) as Dictionary).keys():
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + _get_item_stat_bonus(item, stat_name)
	return totals


func consume_attack_durability() -> void:
	_reduce_durability(["weapon"], 1)


func consume_damage_durability() -> void:
	_reduce_durability(["helmet", "chest_armor", "boots", "offhand", "accessory"], 1)


func apply_death_penalty() -> void:
	for slot_name in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty():
			continue
		var max_durability := int(item.get("max_durability", 0))
		if max_durability <= 0:
			continue
		item["durability"] = max(int(item.get("durability", max_durability)) - int(ceil(max_durability * 0.2)), 0)
		_equipped[slot_name] = item
	equipment_changed.emit()


func is_broken(slot_name: String) -> bool:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return false
	return int(item.get("durability", 1)) <= 0


func get_repairable_slots() -> Array[String]:
	var repairable: Array[String] = []
	for slot_name in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty():
			continue
		var durability := int(item.get("durability", 0))
		var max_durability := int(item.get("max_durability", 0))
		if max_durability > 0 and durability < max_durability:
			repairable.append(slot_name)
	return repairable


func get_repair_cost(slot_name: String) -> Dictionary:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return {}
	var max_durability := int(item.get("max_durability", 0))
	var durability := int(item.get("durability", max_durability))
	var lost: int = max(max_durability - durability, 0)
	if lost <= 0:
		return {}
	var material := str(item.get("repair_material", "wood"))
	return {material: max(int(ceil(float(lost) / 10.0)), 1)}


func repair_slot(slot_name: String, inventory) -> bool:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return false
	var cost := get_repair_cost(slot_name)
	if cost.is_empty():
		return false
	for resource_id in cost.keys():
		if inventory.get_item_count(resource_id) < int(cost[resource_id]):
			return false
	for resource_id in cost.keys():
		inventory.remove_item(resource_id, int(cost[resource_id]))
	item["durability"] = int(item.get("max_durability", 0))
	_equipped[slot_name] = item
	equipment_changed.emit()
	return true


func serialize_state() -> Dictionary:
	return {"equipped": get_all_equipped()}


func load_state(data: Dictionary) -> void:
	for slot_name in SLOT_ORDER:
		_equipped[slot_name] = {}
	var equipped_data: Dictionary = data.get("equipped", {})
	for slot_name in equipped_data.keys():
		if _equipped.has(slot_name):
			_equipped[slot_name] = (equipped_data[slot_name] as Dictionary).duplicate(true)
	equipment_changed.emit()


func _reduce_durability(slot_names: Array[String], amount: int) -> void:
	var changed := false
	for slot_name in slot_names:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty():
			continue
		if not item.has("durability"):
			continue
		item["durability"] = max(int(item.get("durability", 0)) - amount, 0)
		_equipped[slot_name] = item
		changed = true
		break
	if changed:
		equipment_changed.emit()


func _get_item_stat_bonus(item: Dictionary, stat_name: String) -> float:
	if item.is_empty():
		return 0.0
	var stats: Dictionary = item.get("stats", {})
	if not stats.has(stat_name):
		return 0.0
	var bonus := float(stats[stat_name])
	var max_durability := int(item.get("max_durability", 0))
	if max_durability > 0 and int(item.get("durability", max_durability)) <= 0:
		bonus *= 0.5
	return bonus
