extends Node

signal modifiers_changed

const MODIFIER_DEFS: Dictionary = {
	"famine": {
		"id": "famine",
		"name": "modifier_famine_name",
		"description": "modifier_famine_desc",
		"reward": "modifier_famine_reward",
		"effect": "disable_cooking",
		"reward_effect": "drop_bonus",
		"reward_value": 0.2,
	},
	"fragile": {
		"id": "fragile",
		"name": "modifier_fragile_name",
		"description": "modifier_fragile_desc",
		"reward": "modifier_fragile_reward",
		"effect": "hp_reduction",
		"effect_value": 0.3,
		"reward_effect": "exp_bonus",
		"reward_value": 0.3,
	},
	"elite_swarm": {
		"id": "elite_swarm",
		"name": "modifier_elite_swarm_name",
		"description": "modifier_elite_swarm_desc",
		"reward": "modifier_elite_swarm_reward",
		"effect": "elite_double",
		"reward_effect": "blessing_rarity",
		"reward_value": 0.15,
	},
	"no_merchant": {
		"id": "no_merchant",
		"name": "modifier_no_merchant_name",
		"description": "modifier_no_merchant_desc",
		"reward": "modifier_no_merchant_reward",
		"effect": "disable_merchant",
		"reward_effect": "gold_double",
		"reward_value": 2.0,
	},
	"cursed_land": {
		"id": "cursed_land",
		"name": "modifier_cursed_land_name",
		"description": "modifier_cursed_land_desc",
		"reward": "modifier_cursed_land_reward",
		"effect": "forced_curse",
		"reward_effect": "extra_blessing",
		"reward_value": 1.0,
	},
}

var active_modifiers: Array[String] = []
var current_cycle: int = 1


func toggle_modifier(mod_id: String) -> void:
	if not MODIFIER_DEFS.has(mod_id):
		return
	if active_modifiers.has(mod_id):
		active_modifiers.erase(mod_id)
	else:
		active_modifiers.append(mod_id)
	modifiers_changed.emit()


func is_modifier_active(mod_id: String) -> bool:
	return active_modifiers.has(mod_id)


func get_total_drop_bonus() -> float:
	var bonus: float = 0.0
	if active_modifiers.has("famine"):
		bonus += float((MODIFIER_DEFS["famine"] as Dictionary).get("reward_value", 0.0))
	if active_modifiers.has("no_merchant"):
		bonus += 1.0
	return bonus


func get_total_hp_modifier() -> float:
	if active_modifiers.has("fragile"):
		return -float((MODIFIER_DEFS["fragile"] as Dictionary).get("effect_value", 0.3))
	return 0.0


func is_cooking_disabled() -> bool:
	return active_modifiers.has("famine")


func is_merchant_disabled() -> bool:
	return active_modifiers.has("no_merchant")


func get_elite_spawn_multiplier() -> float:
	if active_modifiers.has("elite_swarm"):
		return 2.0
	return 1.0


func get_blessing_rarity_bonus() -> float:
	if active_modifiers.has("elite_swarm"):
		return float((MODIFIER_DEFS["elite_swarm"] as Dictionary).get("reward_value", 0.0))
	return 0.0


func get_extra_blessing_choices() -> int:
	if active_modifiers.has("cursed_land"):
		return 1
	return 0


func advance_cycle() -> void:
	current_cycle += 1
	modifiers_changed.emit()


func serialize_state() -> Dictionary:
	return {
		"active_modifiers": active_modifiers.duplicate(),
		"current_cycle": current_cycle,
	}


func load_state(data: Dictionary) -> void:
	active_modifiers.clear()
	for mod_id_variant: Variant in (data.get("active_modifiers", []) as Array):
		var mod_id: String = str(mod_id_variant)
		if MODIFIER_DEFS.has(mod_id):
			active_modifiers.append(mod_id)
	current_cycle = int(data.get("current_cycle", 1))
	modifiers_changed.emit()
