extends Node

signal blessings_changed

const BLESSING_DEFS: Dictionary = {
	"fire_main": {
		"id": "fire_main", "theme": "fire", "tier": "main",
		"name": "blessing_fire_main_name",
		"description": "blessing_fire_main_desc",
		"category": "blessing_cat_main",
		"color": Color(1.0, 0.3, 0.1, 1.0),
		"effect": "burn_on_hit", "value": 0.15,
	},
	"ice_main": {
		"id": "ice_main", "theme": "ice", "tier": "main",
		"name": "blessing_ice_main_name",
		"description": "blessing_ice_main_desc",
		"category": "blessing_cat_main",
		"color": Color(0.3, 0.7, 1.0, 1.0),
		"effect": "chill_on_hit", "value": 3.0,
	},
	"poison_main": {
		"id": "poison_main", "theme": "poison", "tier": "main",
		"name": "blessing_poison_main_name",
		"description": "blessing_poison_main_desc",
		"category": "blessing_cat_main",
		"color": Color(0.2, 0.85, 0.2, 1.0),
		"effect": "poison_on_hit", "value": 5.0,
	},
	"crit_main": {
		"id": "crit_main", "theme": "crit", "tier": "main",
		"name": "blessing_crit_main_name",
		"description": "blessing_crit_main_desc",
		"category": "blessing_cat_main",
		"color": Color(1.0, 0.75, 0.1, 1.0),
		"effect": "crit_shockwave", "value": 0.3,
	},
	"lifesteal_main": {
		"id": "lifesteal_main", "theme": "lifesteal", "tier": "main",
		"name": "blessing_lifesteal_main_name",
		"description": "blessing_lifesteal_main_desc",
		"category": "blessing_cat_main",
		"color": Color(0.8, 0.1, 0.3, 1.0),
		"effect": "lifesteal", "value": 0.05,
	},
	"fire_sub_damage": {
		"id": "fire_sub_damage", "theme": "fire", "tier": "sub",
		"name": "blessing_fire_sub_damage_name",
		"description": "blessing_fire_sub_damage_desc",
		"category": "blessing_cat_sub",
		"color": Color(1.0, 0.55, 0.15, 1.0),
		"effect": "burn_damage_bonus", "value": 0.12,
	},
	"fire_sub_spread": {
		"id": "fire_sub_spread", "theme": "fire", "tier": "sub",
		"name": "blessing_fire_sub_spread_name",
		"description": "blessing_fire_sub_spread_desc",
		"category": "blessing_cat_sub",
		"color": Color(1.0, 0.45, 0.05, 1.0),
		"effect": "burn_spread", "value": 1.0,
	},
	"ice_sub_duration": {
		"id": "ice_sub_duration", "theme": "ice", "tier": "sub",
		"name": "blessing_ice_sub_duration_name",
		"description": "blessing_ice_sub_duration_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.5, 0.85, 1.0, 1.0),
		"effect": "freeze_duration_bonus", "value": 1.0,
	},
	"ice_sub_shatter": {
		"id": "ice_sub_shatter", "theme": "ice", "tier": "sub",
		"name": "blessing_ice_sub_shatter_name",
		"description": "blessing_ice_sub_shatter_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.65, 0.9, 1.0, 1.0),
		"effect": "frozen_bonus_damage", "value": 0.2,
	},
	"crit_sub_rate": {
		"id": "crit_sub_rate", "theme": "crit", "tier": "sub",
		"name": "blessing_crit_sub_rate_name",
		"description": "blessing_crit_sub_rate_desc",
		"category": "blessing_cat_sub",
		"color": Color(1.0, 0.9, 0.35, 1.0),
		"effect": "crit_rate_bonus", "value": 0.05,
	},
	"crit_sub_multi": {
		"id": "crit_sub_multi", "theme": "crit", "tier": "sub",
		"name": "blessing_crit_sub_multi_name",
		"description": "blessing_crit_sub_multi_desc",
		"category": "blessing_cat_sub",
		"color": Color(1.0, 0.8, 0.2, 1.0),
		"effect": "crit_damage_bonus", "value": 0.2,
	},
	"lifesteal_sub_low_hp": {
		"id": "lifesteal_sub_low_hp", "theme": "lifesteal", "tier": "sub",
		"name": "blessing_lifesteal_sub_low_hp_name",
		"description": "blessing_lifesteal_sub_low_hp_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.9, 0.25, 0.45, 1.0),
		"effect": "lifesteal_low_hp", "value": 0.3,
	},
	"lifesteal_sub_kill": {
		"id": "lifesteal_sub_kill", "theme": "lifesteal", "tier": "sub",
		"name": "blessing_lifesteal_sub_kill_name",
		"description": "blessing_lifesteal_sub_kill_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.75, 0.15, 0.3, 1.0),
		"effect": "heal_on_kill", "value": 0.05,
	},
	"generic_atk": {
		"id": "generic_atk", "theme": "generic", "tier": "sub",
		"name": "blessing_generic_atk_name",
		"description": "blessing_generic_atk_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.95, 0.5, 0.3, 1.0),
		"effect": "atk_percent", "value": 0.08,
	},
	"generic_def": {
		"id": "generic_def", "theme": "generic", "tier": "sub",
		"name": "blessing_generic_def_name",
		"description": "blessing_generic_def_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.45, 0.65, 0.95, 1.0),
		"effect": "def_percent", "value": 0.08,
	},
	"generic_hp": {
		"id": "generic_hp", "theme": "generic", "tier": "sub",
		"name": "blessing_generic_hp_name",
		"description": "blessing_generic_hp_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.3, 0.85, 0.4, 1.0),
		"effect": "hp_percent", "value": 0.10,
	},
	"generic_speed": {
		"id": "generic_speed", "theme": "speed", "tier": "sub",
		"name": "blessing_generic_speed_name",
		"description": "blessing_generic_speed_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.38, 0.72, 1.0, 1.0),
		"effect": "speed_percent", "value": 0.12,
	},
}

var active_main_blessings: Array[String] = []
var active_sub_blessings: Array[Dictionary] = []
var max_main_blessings: int = 2
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func add_blessing(blessing_id: String) -> bool:
	if not BLESSING_DEFS.has(blessing_id):
		return false
	var def: Dictionary = BLESSING_DEFS[blessing_id] as Dictionary
	var tier: String = str(def.get("tier", "sub"))
	if tier == "main":
		if active_main_blessings.has(blessing_id):
			return false
		if active_main_blessings.size() >= max_main_blessings:
			return false
		active_main_blessings.append(blessing_id)
	else:
		var found: bool = false
		for entry: Dictionary in active_sub_blessings:
			if str(entry.get("id", "")) == blessing_id:
				entry["stacks"] = int(entry.get("stacks", 1)) + 1
				found = true
				break
		if not found:
			active_sub_blessings.append({"id": blessing_id, "stacks": 1})
	blessings_changed.emit()
	return true


func get_blessing_stacks(blessing_id: String) -> int:
	if active_main_blessings.has(blessing_id):
		return 1
	for entry: Dictionary in active_sub_blessings:
		if str(entry.get("id", "")) == blessing_id:
			return int(entry.get("stacks", 1))
	return 0


func get_theme_score(theme: String) -> float:
	var score: float = 0.0
	for bid: String in active_main_blessings:
		if not BLESSING_DEFS.has(bid):
			continue
		if str((BLESSING_DEFS[bid] as Dictionary).get("theme", "")) == theme:
			score += 10.0
	for entry: Dictionary in active_sub_blessings:
		var bid: String = str(entry.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		if str((BLESSING_DEFS[bid] as Dictionary).get("theme", "")) == theme:
			score += 3.0 * float(entry.get("stacks", 1))
	return score


func get_effective_value(blessing_id: String, stacks: int) -> float:
	if not BLESSING_DEFS.has(blessing_id):
		return 0.0
	var base_value: float = float((BLESSING_DEFS[blessing_id] as Dictionary).get("value", 0.0))
	return base_value * maxf(0.25, 1.0 - 0.18 * float(stacks - 1))


func has_effect(effect_name: String) -> bool:
	return get_total_effect_value(effect_name) > 0.0


func get_total_effect_value(effect_name: String) -> float:
	var total: float = 0.0
	for bid: String in active_main_blessings:
		if not BLESSING_DEFS.has(bid):
			continue
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			total += get_effective_value(bid, 1)
	for entry: Dictionary in active_sub_blessings:
		var bid: String = str(entry.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			total += get_effective_value(bid, int(entry.get("stacks", 1)))
	return total


func clear_all() -> void:
	active_main_blessings.clear()
	active_sub_blessings.clear()
	blessings_changed.emit()


func generate_three_choices() -> Array[Dictionary]:
	var candidates: Array[String] = []
	var all_ids: Array[String] = []
	for k: String in BLESSING_DEFS.keys():
		all_ids.append(k)

	# Compute theme scores for weighting
	var theme_scores: Dictionary = {}
	for bid: String in all_ids:
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		var theme: String = str(def.get("theme", "generic"))
		if not theme_scores.has(theme):
			theme_scores[theme] = get_theme_score(theme)

	# Build weighted pool
	var weighted_pool: Array[String] = []
	for bid: String in all_ids:
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		var tier: String = str(def.get("tier", "sub"))
		var theme: String = str(def.get("theme", "generic"))
		var weight: int = 1
		if tier == "main" and active_main_blessings.size() < max_main_blessings:
			weight = 3
		var score: float = float(theme_scores.get(theme, 0.0))
		if score > 0.0:
			weight += 2
		for _i: int in range(weight):
			weighted_pool.append(bid)

	# Shuffle and pick 3 unique
	for i: int in range(weighted_pool.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var temp: String = weighted_pool[i]
		weighted_pool[i] = weighted_pool[j]
		weighted_pool[j] = temp

	var chosen_ids: Array[String] = []
	for bid: String in weighted_pool:
		if not chosen_ids.has(bid):
			chosen_ids.append(bid)
		if chosen_ids.size() >= 3:
			break

	# Fill remaining from all_ids if needed
	if chosen_ids.size() < 3:
		for bid: String in all_ids:
			if not chosen_ids.has(bid):
				chosen_ids.append(bid)
			if chosen_ids.size() >= 3:
				break

	# Ensure at least 1 main blessing candidate if slots available
	var has_main: bool = false
	for bid: String in chosen_ids:
		if str((BLESSING_DEFS[bid] as Dictionary).get("tier", "sub")) == "main":
			has_main = true
			break
	if not has_main and active_main_blessings.size() < max_main_blessings:
		var main_ids: Array[String] = []
		for bid: String in all_ids:
			if str((BLESSING_DEFS[bid] as Dictionary).get("tier", "sub")) == "main":
				main_ids.append(bid)
		if not main_ids.is_empty():
			var pick: String = main_ids[_rng.randi() % main_ids.size()]
			chosen_ids[chosen_ids.size() - 1] = pick

	var results: Array[Dictionary] = []
	for bid: String in chosen_ids:
		var def: Dictionary = (BLESSING_DEFS[bid] as Dictionary).duplicate(true)
		var stacks: int = get_blessing_stacks(bid)
		def["current_stacks"] = stacks
		results.append(def)
	return results
