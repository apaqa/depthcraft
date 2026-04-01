extends Node
class_name EquipmentSystem

signal equipment_changed

const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")
const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")
const SLOT_ORDER: Array[String] = ["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand", "tool"]
const DISPLAY_STATS: Array[String] = ["attack", "defense", "max_hp", "speed"]
const SET_ORDER: Array[String] = ["necromancer_set", "lava_set", "abyss_set", "shadow_set", "dragon_set"]
const FORGE_MAX_BY_RARITY: Dictionary = {
	"Common": 3,
	"Uncommon": 5,
	"Rare": 7,
	"Epic": 10,
	"Legendary": 15,
}

var _equipped: Dictionary = {}
var _cached_bonus_map: Dictionary = {}
var _active_set_entries: Array[Dictionary] = []
var _active_set_counts: Dictionary = {}


func _ready() -> void:
	for slot_name: String in SLOT_ORDER:
		_equipped[slot_name] = {}
	_check_set_bonus()


func get_slot_order() -> PackedStringArray:
	return PackedStringArray(SLOT_ORDER)


func get_equipped(slot_name: String) -> Dictionary:
	return (_equipped.get(slot_name, {}) as Dictionary).duplicate(true)


func get_all_equipped() -> Dictionary:
	var payload: Dictionary = {}
	for slot_name: String in SLOT_ORDER:
		payload[slot_name] = get_equipped(slot_name)
	return payload


func get_active_set_entries() -> Array[Dictionary]:
	var payload: Array[Dictionary] = []
	for entry: Dictionary in _active_set_entries:
		payload.append(entry.duplicate(true))
	return payload


func get_active_set_counts() -> Dictionary:
	return _active_set_counts.duplicate(true)


func has_active_set_effect(effect_id: String) -> bool:
	return float(_cached_bonus_map.get(effect_id, 0.0)) > 0.0


func get_active_set_effect_value(effect_id: String) -> float:
	return float(_cached_bonus_map.get(effect_id, 0.0))


func equip_from_inventory(inventory, stack_index: int) -> bool:
	if inventory == null or stack_index < 0 or stack_index >= inventory.items.size():
		return false
	var stack: Dictionary = inventory.items[stack_index].duplicate(true)
	if str(stack.get("type", "")) != "equipment":
		return false
	var slot_name: String = str(stack.get("slot", ""))
	if slot_name == "":
		return false
	if not inventory.remove_item(str(stack.get("id", "")), 1):
		return false
	var previous: Dictionary = equip(stack, slot_name)
	if not previous.is_empty():
		inventory.add_stack(previous)
	return true


func equip(item_data: Dictionary, slot_name: String = "") -> Dictionary:
	var resolved_slot: String = slot_name if slot_name != "" else str(item_data.get("slot", ""))
	if not _equipped.has(resolved_slot):
		return {}
	var previous: Dictionary = get_equipped(resolved_slot)
	var equipped_item: Dictionary = item_data.duplicate(true)
	equipped_item["quantity"] = 1
	_equipped[resolved_slot] = equipped_item
	AudioManager.play_sfx("equip")
	_notify_equipment_changed()
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
	_notify_equipment_changed()
	return item


func get_total_equipment_bonus(stat_name: String) -> float:
	return float(_cached_bonus_map.get(stat_name, 0.0))


func get_total_bonus_map() -> Dictionary:
	return _cached_bonus_map.duplicate(true)


func get_preview_bonus_map(item_data: Dictionary, slot_name: String = "") -> Dictionary:
	var resolved_slot: String = slot_name if slot_name != "" else str(item_data.get("slot", ""))
	var preview_equipped: Dictionary = _equipped.duplicate(true)
	if resolved_slot != "" and preview_equipped.has(resolved_slot):
		preview_equipped[resolved_slot] = item_data.duplicate(true)
	var payload: Dictionary = _build_total_bonus_payload(preview_equipped)
	return (payload.get("bonuses", {}) as Dictionary).duplicate(true)


func get_item_display_name(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var base_name: String = ITEM_DATABASE.get_stack_display_name(item)
	var forge_level: int = int(item.get("forge_level", 0))
	var broken: bool = _is_item_broken(item)
	var display_name: String = LocaleManager.L("broken_item_fmt") % base_name if broken else base_name
	if forge_level > 0:
		display_name += " +%d" % forge_level
	return display_name


func get_forge_max_level(item: Dictionary) -> int:
	var rarity: String = str(item.get("rarity", "Common"))
	return int(FORGE_MAX_BY_RARITY.get(rarity, 3))


func forge_item(slot_name: String, player_inventory) -> Dictionary:
	var item: Dictionary = get_equipped(slot_name)
	if item.is_empty():
		return {}
	var forge_level: int = int(item.get("forge_level", 0))
	var max_level: int = int(item.get("max_forge", get_forge_max_level(item)))
	if forge_level >= max_level:
		return {}
	var cost: Dictionary = get_forge_cost(slot_name)
	if cost.is_empty():
		return {}
	var stone_cost: int = int(cost.get("stone", 0))
	var iron_cost: int = int(cost.get("iron_ore", 0))
	if player_inventory == null:
		return {}
	if not player_inventory.has_item("stone", stone_cost):
		return {}
	if not player_inventory.has_item("iron_ore", iron_cost):
		return {}
	player_inventory.remove_item("stone", stone_cost)
	player_inventory.remove_item("iron_ore", iron_cost)
	item["forge_level"] = forge_level + 1
	# Boost main stat by 3-5%
	var main_boost_pct: float = float(randi_range(3, 5)) * 0.01
	var main_stat_val: int = int(item.get("main_stat_value", 0))
	if main_stat_val > 0:
		var boost: int = maxi(int(round(float(main_stat_val) * main_boost_pct)), 1)
		item["main_stat_value"] = main_stat_val + boost
	# Boost random sub stat by 3-5%
	var boosted_sub: String = ""
	var sub_stats: Array = item.get("sub_stats", []) as Array
	if not sub_stats.is_empty():
		var sub_index: int = randi() % sub_stats.size()
		var sub_entry: Dictionary = sub_stats[sub_index] as Dictionary
		var sub_boost: float = float(randi_range(3, 5)) * 0.1
		sub_entry["value"] = float(sub_entry.get("value", 0.0)) + sub_boost
		sub_stats[sub_index] = sub_entry
		item["sub_stats"] = sub_stats
		boosted_sub = str(sub_entry.get("type", ""))
	# Rebuild merged stats
	_rebuild_item_stats(item)
	_equipped[slot_name] = item
	_notify_equipment_changed()
	var achievement_manager: Node = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("record_forge"):
		achievement_manager.record_forge()
	return {"success": true, "boosted_sub": boosted_sub}


func _rebuild_item_stats(item: Dictionary) -> void:
	# Recalculate stats from base + affixes + main stat + sub stats
	var slot: String = str(item.get("slot", "weapon"))
	var rarity: String = str(item.get("rarity", "Common"))
	var floor_found: int = int(item.get("floor_found", 1))
	var quality_mult: float = float(DUNGEON_LOOT.QUALITY_MULTIPLIERS.get(rarity, 1.0))
	var base_power: int = int(round((3 + floor_found * 2) * quality_mult))
	item["stats"] = DUNGEON_LOOT._generate_base_stats(slot, base_power)
	DUNGEON_LOOT._apply_affixes_to_stats(item)
	DUNGEON_LOOT._apply_main_and_sub_to_stats(item)


func get_forge_cost(slot_name: String) -> Dictionary:
	var item: Dictionary = get_equipped(slot_name)
	if item.is_empty():
		return {}
	var forge_level: int = int(item.get("forge_level", 0))
	var stone_cost: int = (forge_level + 1) * 2
	var iron_cost: int = maxi(forge_level, 1)
	return {
		"stone": stone_cost,
		"iron_ore": iron_cost,
		"current_forge_level": forge_level,
		"max_forge_level": int(item.get("max_forge", get_forge_max_level(item))),
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
	var multiplier: float = 0.5 if _is_item_broken(item) else 1.0
	for stat_name: String in stats.keys():
		effective_stats[stat_name] = float(stats.get(stat_name, 0.0)) * multiplier
	return effective_stats


func get_comparison_lines(current_summary: Dictionary, preview_summary: Dictionary) -> PackedStringArray:
	var labels: Dictionary = {
		"attack": "ATK",
		"defense": "DEF",
		"max_hp": "HP",
		"speed": "SPD",
	}
	var lines: PackedStringArray = []
	for stat_name: String in DISPLAY_STATS:
		var before_value: float = float(current_summary.get(stat_name, 0.0))
		var after_value: float = float(preview_summary.get(stat_name, 0.0))
		var delta: float = after_value - before_value
		var before_text: String = str(int(round(before_value)))
		var after_text: String = str(int(round(after_value)))
		var delta_text: String = "%+d" % int(round(delta))
		lines.append("%s: %s -> %s (%s)" % [str(labels.get(stat_name, stat_name)), before_text, after_text, delta_text])
	return lines


func get_repair_material(slot_name: String, item: Dictionary = {}) -> String:
	var target_item: Dictionary = item if not item.is_empty() else (_equipped.get(slot_name, {}) as Dictionary)
	if target_item.is_empty():
		return ""
	var resolved_slot: String = slot_name if slot_name != "" else str(target_item.get("slot", ""))
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
	for slot_name: String in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty():
			continue
		var max_durability: int = int(item.get("max_durability", 0))
		if max_durability <= 0:
			continue
		item["durability"] = max(int(item.get("durability", max_durability)) - int(ceil(max_durability * 0.2)), 0)
		_equipped[slot_name] = item
	_notify_equipment_changed()


func is_broken(slot_name: String) -> bool:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return false
	return _is_item_broken(item)


func get_repairable_slots() -> Array[String]:
	var repairable: Array[String] = []
	for slot_name: String in SLOT_ORDER:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty():
			continue
		var durability: int = int(item.get("durability", 0))
		var max_durability: int = int(item.get("max_durability", 0))
		if max_durability > 0 and durability < max_durability:
			repairable.append(slot_name)
	return repairable


func get_repair_cost(slot_name: String) -> Dictionary:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return {}
	var max_durability: int = int(item.get("max_durability", 0))
	var durability: int = int(item.get("durability", max_durability))
	var lost: int = max(max_durability - durability, 0)
	if lost <= 0:
		return {}
	var material: String = get_repair_material(slot_name, item)
	return {material: max(int(ceil(float(lost) / 10.0)), 1)}


func repair_slot(slot_name: String, inventory) -> bool:
	var item: Dictionary = _equipped.get(slot_name, {})
	if item.is_empty():
		return false
	var cost: Dictionary = get_repair_cost(slot_name)
	if cost.is_empty():
		return false
	for resource_id_variant: Variant in cost.keys():
		var resource_id: String = str(resource_id_variant)
		if inventory.get_item_count(resource_id) < int(cost[resource_id]):
			return false
	for resource_id_variant: Variant in cost.keys():
		var resource_id: String = str(resource_id_variant)
		inventory.remove_item(resource_id, int(cost[resource_id]))
	item["durability"] = int(item.get("max_durability", 0))
	_equipped[slot_name] = item
	_notify_equipment_changed()
	return true


func get_total_repairable_item_count(inventory = null) -> int:
	var repairable_count: int = 0
	for slot_name: String in SLOT_ORDER:
		var equipped_item: Dictionary = _equipped.get(slot_name, {})
		if _is_item_repairable(equipped_item):
			repairable_count += 1
	if inventory != null and "items" in inventory:
		for stack_variant: Variant in inventory.items:
			if typeof(stack_variant) != TYPE_DICTIONARY:
				continue
			var stack_data: Dictionary = stack_variant as Dictionary
			if str(stack_data.get("type", "")) != "equipment":
				continue
			if _is_item_repairable(stack_data):
				repairable_count += 1
	return repairable_count


func repair_all_equipment(inventory = null) -> int:
	var repaired_count: int = 0
	for slot_name: String in SLOT_ORDER:
		var equipped_item: Dictionary = _equipped.get(slot_name, {})
		if not _repair_item_dictionary(equipped_item):
			continue
		_equipped[slot_name] = equipped_item
		repaired_count += 1
	if inventory != null and "items" in inventory:
		for index: int in range(inventory.items.size()):
			var stack_variant: Variant = inventory.items[index]
			if typeof(stack_variant) != TYPE_DICTIONARY:
				continue
			var stack_data: Dictionary = stack_variant as Dictionary
			if str(stack_data.get("type", "")) != "equipment":
				continue
			if not _repair_item_dictionary(stack_data):
				continue
			inventory.items[index] = stack_data
			repaired_count += 1
	if repaired_count > 0:
		_notify_equipment_changed()
		if inventory != null and inventory.has_method("mark_dirty"):
			inventory.mark_dirty()
	return repaired_count


func serialize_state() -> Dictionary:
	return {"equipped": get_all_equipped()}


func load_state(data: Dictionary) -> void:
	for slot_name: String in SLOT_ORDER:
		_equipped[slot_name] = {}
	var equipped_data: Dictionary = data.get("equipped", {})
	for slot_name_variant: Variant in equipped_data.keys():
		var slot_name: String = str(slot_name_variant)
		if _equipped.has(slot_name):
			_equipped[slot_name] = (equipped_data[slot_name] as Dictionary).duplicate(true)
	_notify_equipment_changed()


func get_display_stat_summary(base_summary: Dictionary) -> Dictionary:
	return {
		"attack": int(round(float(base_summary.get("attack", 0.0)))),
		"defense": int(round(float(base_summary.get("defense", 0.0)))),
		"max_hp": int(round(float(base_summary.get("max_hp", 0.0)))),
		"speed": int(round(float(base_summary.get("speed", 0.0)))),
	}


func _notify_equipment_changed() -> void:
	_check_set_bonus()
	equipment_changed.emit()


func _is_item_repairable(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var max_durability: int = int(item.get("max_durability", item.get("durability_max", 0)))
	var durability: int = int(item.get("durability", item.get("durability_current", max_durability)))
	return max_durability > 0 and durability < max_durability


func _repair_item_dictionary(item: Dictionary) -> bool:
	if not _is_item_repairable(item):
		return false
	var max_durability: int = int(item.get("max_durability", item.get("durability_max", 0)))
	item["durability"] = max_durability
	if item.has("durability_current"):
		item["durability_current"] = max_durability
	if item.has("durability_max"):
		item["durability_max"] = max_durability
	return true


func _check_set_bonus() -> void:
	var payload: Dictionary = _build_total_bonus_payload(_equipped)
	_cached_bonus_map = (payload.get("bonuses", {}) as Dictionary).duplicate(true)
	_active_set_entries.clear()
	for entry: Dictionary in payload.get("entries", []):
		_active_set_entries.append(entry.duplicate(true))
	_active_set_counts = (payload.get("counts", {}) as Dictionary).duplicate(true)


func _build_total_bonus_payload(equipped_map: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var set_counts: Dictionary = {}
	for slot_name: String in SLOT_ORDER:
		var item: Dictionary = equipped_map.get(slot_name, {})
		for stat_name: String in (item.get("stats", {}) as Dictionary).keys():
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + _get_item_stat_bonus(item, stat_name)
		var set_id: String = str(item.get("set_id", ""))
		if set_id != "":
			set_counts[set_id] = int(set_counts.get(set_id, 0)) + 1
	var active_entries: Array[Dictionary] = []
	for set_id: String in SET_ORDER:
		if not set_counts.has(set_id):
			continue
		_apply_set_bonus(totals, active_entries, set_id, int(set_counts[set_id]))
	return {
		"bonuses": totals,
		"entries": active_entries,
		"counts": set_counts,
	}


func _apply_set_bonus(totals: Dictionary, active_entries: Array[Dictionary], set_id: String, piece_count: int) -> void:
	if piece_count < 2:
		return
	var definition: Dictionary = ITEM_DATABASE.get_set_definition(set_id)
	if definition.is_empty():
		return
	var active_effects: Array[String] = []
	var bonus_texts: Dictionary = definition.get("bonuses", {})
	match set_id:
		"necromancer_set":
			_add_bonus(totals, "attack_percent", 0.15)
			active_effects.append("2件: %s" % str(bonus_texts.get(2, "")))
			if piece_count >= 3:
				_add_bonus(totals, "necromancer_summon_on_kill", 1.0)
				active_effects.append("3件: %s" % str(bonus_texts.get(3, "")))
		"lava_set":
			_add_bonus(totals, "defense_percent", 0.20)
			active_effects.append("2件: %s" % str(bonus_texts.get(2, "")))
			if piece_count >= 3:
				_add_bonus(totals, "lava_burst_on_hit", 1.0)
				active_effects.append("3件: %s" % str(bonus_texts.get(3, "")))
		"abyss_set":
			_add_bonus(totals, "crit_chance", 0.10)
			active_effects.append("2件: %s" % str(bonus_texts.get(2, "")))
			if piece_count >= 3:
				_add_bonus(totals, "abyss_crit_heal", 1.0)
				active_effects.append("3件: %s" % str(bonus_texts.get(3, "")))
		"shadow_set":
			_add_bonus(totals, "attack_cooldown_reduction", 0.15)
			active_effects.append("2件: %s" % str(bonus_texts.get(2, "")))
			if piece_count >= 3:
				_add_bonus(totals, "shadow_combo_crit", 1.0)
				active_effects.append("3件: %s" % str(bonus_texts.get(3, "")))
		"dragon_set":
			_add_bonus(totals, "max_hp_percent", 0.25)
			active_effects.append("2件: %s" % str(bonus_texts.get(2, "")))
			if piece_count >= 3:
				_add_bonus(totals, "dragon_emergency_guard", 1.0)
				active_effects.append("3件: %s" % str(bonus_texts.get(3, "")))
	if active_effects.is_empty():
		return
	active_entries.append({
		"set_id": set_id,
		"set_name": str(definition.get("name", set_id)),
		"piece_count": piece_count,
		"active_effects": active_effects,
	})


func _add_bonus(totals: Dictionary, key: String, value: float) -> void:
	totals[key] = float(totals.get(key, 0.0)) + value


func _reduce_durability(slot_names: Array[String], amount: int, random_pick: bool = false) -> void:
	var eligible_slots: Array[String] = []
	for slot_name: String in slot_names:
		var item: Dictionary = _equipped.get(slot_name, {})
		if item.is_empty() or not item.has("durability"):
			continue
		eligible_slots.append(slot_name)
	if eligible_slots.is_empty():
		return
	var target_slot: String = eligible_slots[randi_range(0, eligible_slots.size() - 1)] if random_pick else eligible_slots[0]
	var target_item: Dictionary = _equipped.get(target_slot, {})
	target_item["durability"] = max(int(target_item.get("durability", 0)) - amount, 0)
	_equipped[target_slot] = target_item
	_notify_equipment_changed()


func _is_item_broken(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var max_durability: int = int(item.get("max_durability", item.get("durability_max", 0)))
	var durability: int = int(item.get("durability", item.get("durability_current", max_durability)))
	return max_durability > 0 and durability <= 0


func _get_item_stat_bonus(item: Dictionary, stat_name: String) -> float:
	if item.is_empty():
		return 0.0
	var stats: Dictionary = item.get("stats", {})
	if not stats.has(stat_name):
		return 0.0
	var bonus: float = float(stats[stat_name])
	if _is_item_broken(item):
		bonus *= 0.5
	return bonus
