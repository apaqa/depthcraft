extends Node
class_name EquipmentSystem

signal equipment_changed

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const SLOT_ORDER := ["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand", "tool"]
const DISPLAY_STATS := ["attack", "defense", "max_hp", "speed"]

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
	AudioManager.play_sfx("equip")
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
	return _build_total_bonus_map(_equipped)


func get_preview_bonus_map(item_data: Dictionary, slot_name: String = "") -> Dictionary:
	var resolved_slot := slot_name if slot_name != "" else str(item_data.get("slot", ""))
	var preview_equipped := _equipped.duplicate(true)
	if resolved_slot != "" and preview_equipped.has(resolved_slot):
		preview_equipped[resolved_slot] = item_data.duplicate(true)
	return _build_total_bonus_map(preview_equipped)


const FORGE_MAX_BY_RARITY: Dictionary = {
	"Common": 3,
	"Uncommon": 5,
	"Rare": 7,
	"Epic": 10,
	"Legendary": 15,
}


func get_item_display_name(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var base_name: String = ITEM_DATABASE.get_stack_display_name(item)
	var forge_lvl: int = int(item.get("forge_level", 0))
	var broken: bool = _is_item_broken(item)
	var display: String = LocaleManager.L("broken_item_fmt") % base_name if broken else base_name
	if forge_lvl > 0:
		display = display + " +%d" % forge_lvl
	return display


func get_forge_max_level(item: Dictionary) -> int:
	var rarity: String = str(item.get("rarity", "Common"))
	return int(FORGE_MAX_BY_RARITY.get(rarity, 3))


func forge_item(slot_name: String, player_inventory) -> bool:
	var item: Dictionary = get_equipped(slot_name)
	if item.is_empty():
		return false
	var forge_lvl: int = int(item.get("forge_level", 0))
	var max_lvl: int = get_forge_max_level(item)
	if forge_lvl >= max_lvl:
		return false
	# Calculate cost
	var item_level: int = maxi(int(item.get("required_level", 1)), 1)
	var forge_times: int = forge_lvl + 1
	var copper_cost: int = 10 * item_level * forge_times
	var iron_cost: int = forge_times
	if player_inventory == null:
		return false
	if not player_inventory.pay_copper(copper_cost):
		return false
	if not player_inventory.remove_item("iron_ore", iron_cost):
		# Refund copper
		player_inventory.add_item("copper", copper_cost)
		return false
	# Apply forge level
	item["forge_level"] = forge_lvl + 1
	# Boost main stats by 5% per forge level
	var stats: Dictionary = item.get("stats", {})
	for stat_name: String in stats.keys():
		var base_val: float = float(stats[stat_name])
		if stat_name == "attack" or stat_name == "defense":
			stats[stat_name] = base_val * 1.05
		else:
			stats[stat_name] = base_val * 1.03
	item["stats"] = stats
	_equipped[slot_name] = item
	equipment_changed.emit()
	return true


func get_forge_cost(slot_name: String) -> Dictionary:
	var item: Dictionary = get_equipped(slot_name)
	if item.is_empty():
		return {}
	var forge_lvl: int = int(item.get("forge_level", 0))
	var item_level: int = maxi(int(item.get("required_level", 1)), 1)
	var forge_times: int = forge_lvl + 1
	return {
		"copper": 10 * item_level * forge_times,
		"iron_ore": forge_times,
		"current_forge_level": forge_lvl,
		"max_forge_level": get_forge_max_level(item),
	}


func get_item_display_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color.WHITE
	if _is_item_broken(item):
		return Color(1.0, 0.3, 0.3, 1.0)
	return ITEM_DATABASE.get_stack_color(item)


func get_effective_item_stats(item: Dictionary) -> Dictionary:
	var effective_stats: Dictionary = {}
	var stats: Dictionary = item.get("stats", {})
	var multiplier := 0.5 if _is_item_broken(item) else 1.0
	for stat_name in stats.keys():
		effective_stats[stat_name] = float(stats.get(stat_name, 0.0)) * multiplier
	return effective_stats


func get_comparison_lines(current_summary: Dictionary, preview_summary: Dictionary) -> PackedStringArray:
	var labels := {
		"attack": "ATK",
		"defense": "DEF",
		"max_hp": "HP",
		"speed": "SPD",
	}
	var lines: PackedStringArray = []
	for stat_name in DISPLAY_STATS:
		var before_value := float(current_summary.get(stat_name, 0.0))
		var after_value := float(preview_summary.get(stat_name, 0.0))
		var delta := after_value - before_value
		var before_text := str(int(round(before_value)))
		var after_text := str(int(round(after_value)))
		var delta_text := "%+d" % int(round(delta))
		lines.append("%s: %s -> %s (%s)" % [str(labels.get(stat_name, stat_name)), before_text, after_text, delta_text])
	return lines


func get_repair_material(slot_name: String, item: Dictionary = {}) -> String:
	var target_item: Dictionary = item if not item.is_empty() else _equipped.get(slot_name, {})
	if target_item.is_empty():
		return ""
	var resolved_slot := slot_name if slot_name != "" else str(target_item.get("slot", ""))
	match resolved_slot:
		"weapon", "tool":
			return "iron_ore"
		"helmet", "chest_armor", "boots", "offhand", "accessory":
			return "fiber"
		_:
			return str(target_item.get("repair_material", "fiber"))


func consume_attack_durability() -> void:
	_reduce_durability(["weapon"], 1, false)


func consume_damage_durability() -> void:
	_reduce_durability(["helmet", "chest_armor", "boots", "offhand", "accessory"], 1, true)


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
	return _is_item_broken(item)


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
	var material := get_repair_material(slot_name, item)
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


func _build_total_bonus_map(equipped_map: Dictionary) -> Dictionary:
	var totals := {}
	for slot_name in SLOT_ORDER:
		var item: Dictionary = equipped_map.get(slot_name, {})
		for stat_name in (item.get("stats", {}) as Dictionary).keys():
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + _get_item_stat_bonus(item, stat_name)
	return totals


func _reduce_durability(slot_names: Array[String], amount: int, random_pick: bool = false) -> void:
	var eligible_slots: Array[String] = []
	for slot_name in slot_names:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty() or not item.has("durability"):
			continue
		eligible_slots.append(slot_name)
	if eligible_slots.is_empty():
		return
	var target_slot := eligible_slots[randi_range(0, eligible_slots.size() - 1)] if random_pick else eligible_slots[0]
	var target_item: Dictionary = _equipped.get(target_slot, {})
	target_item["durability"] = max(int(target_item.get("durability", 0)) - amount, 0)
	_equipped[target_slot] = target_item
	equipment_changed.emit()


func _is_item_broken(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var max_durability := int(item.get("max_durability", item.get("durability_max", 0)))
	var durability := int(item.get("durability", item.get("durability_current", max_durability)))
	return max_durability > 0 and durability <= 0


func _get_item_stat_bonus(item: Dictionary, stat_name: String) -> float:
	if item.is_empty():
		return 0.0
	var stats: Dictionary = item.get("stats", {})
	if not stats.has(stat_name):
		return 0.0
	var bonus := float(stats[stat_name])
	if _is_item_broken(item):
		bonus *= 0.5
	return bonus


func get_display_stat_summary(base_summary: Dictionary) -> Dictionary:
	return {
		"attack": int(round(float(base_summary.get("attack", 0.0)))),
		"defense": int(round(float(base_summary.get("defense", 0.0)))),
		"max_hp": int(round(float(base_summary.get("max_hp", 0.0)))),
		"speed": int(round(float(base_summary.get("speed", 0.0)))),
	}

