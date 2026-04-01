extends Node

signal blessings_changed
signal blessing_theme_selected(theme: String)

const ALL_THEMES: Array[String] = [
	"fire", "ice", "poison", "crit", "lifesteal",
	"dodge", "counter", "skill_boost", "wealth", "summon",
]

const THEME_WEIGHTS: Dictionary = {
	"fire": 10.56, "ice": 10.56, "poison": 10.56, "crit": 10.56,
	"lifesteal": 10.56, "dodge": 10.56, "counter": 10.56,
	"skill_boost": 5.0, "wealth": 10.56, "summon": 10.56,
}

const THEME_COLORS: Dictionary = {
	"fire": Color(1.0, 0.3, 0.1, 1.0),
	"ice": Color(0.3, 0.7, 1.0, 1.0),
	"poison": Color(0.2, 0.85, 0.2, 1.0),
	"crit": Color(1.0, 0.75, 0.1, 1.0),
	"lifesteal": Color(0.8, 0.1, 0.3, 1.0),
	"dodge": Color(0.3, 0.8, 0.75, 1.0),
	"counter": Color(0.7, 0.2, 0.7, 1.0),
	"skill_boost": Color(0.4, 0.5, 1.0, 1.0),
	"wealth": Color(1.0, 0.85, 0.2, 1.0),
	"summon": Color(0.5, 0.2, 0.8, 1.0),
}

const THEME_NAME_KEYS: Dictionary = {
	"fire": "blessing_theme_fire",
	"ice": "blessing_theme_ice",
	"poison": "blessing_theme_poison",
	"crit": "blessing_theme_crit",
	"lifesteal": "blessing_theme_lifesteal",
	"dodge": "blessing_theme_dodge",
	"counter": "blessing_theme_counter",
	"skill_boost": "blessing_theme_skill_boost",
	"wealth": "blessing_theme_wealth",
	"summon": "blessing_theme_summon",
}

const THEME_DESC_KEYS: Dictionary = {
	"fire": "blessing_theme_fire_desc",
	"ice": "blessing_theme_ice_desc",
	"poison": "blessing_theme_poison_desc",
	"crit": "blessing_theme_crit_desc",
	"lifesteal": "blessing_theme_lifesteal_desc",
	"dodge": "blessing_theme_dodge_desc",
	"counter": "blessing_theme_counter_desc",
	"skill_boost": "blessing_theme_skill_boost_desc",
	"wealth": "blessing_theme_wealth_desc",
	"summon": "blessing_theme_summon_desc",
}

const SLOT_NAME_KEYS: Dictionary = {
	"primary": "blessing_slot_primary",
	"secondary": "blessing_slot_secondary",
	"skill": "blessing_slot_skill",
}

const BLESSING_DEFS: Dictionary = {
	# --- Main blessings (one per theme) ---
	"fire_main": {"id": "fire_main", "theme": "fire", "tier": "main", "name": "blessing_fire_main_name", "description": "blessing_fire_main_desc", "category": "blessing_cat_main", "color": Color(1.0, 0.3, 0.1, 1.0), "effect": "burn_on_hit", "value": 0.15},
	"ice_main": {"id": "ice_main", "theme": "ice", "tier": "main", "name": "blessing_ice_main_name", "description": "blessing_ice_main_desc", "category": "blessing_cat_main", "color": Color(0.3, 0.7, 1.0, 1.0), "effect": "chill_on_hit", "value": 3.0},
	"poison_main": {"id": "poison_main", "theme": "poison", "tier": "main", "name": "blessing_poison_main_name", "description": "blessing_poison_main_desc", "category": "blessing_cat_main", "color": Color(0.2, 0.85, 0.2, 1.0), "effect": "poison_on_hit", "value": 5.0},
	"crit_main": {"id": "crit_main", "theme": "crit", "tier": "main", "name": "blessing_crit_main_name", "description": "blessing_crit_main_desc", "category": "blessing_cat_main", "color": Color(1.0, 0.75, 0.1, 1.0), "effect": "crit_shockwave", "value": 0.3},
	"lifesteal_main": {"id": "lifesteal_main", "theme": "lifesteal", "tier": "main", "name": "blessing_lifesteal_main_name", "description": "blessing_lifesteal_main_desc", "category": "blessing_cat_main", "color": Color(0.8, 0.1, 0.3, 1.0), "effect": "lifesteal", "value": 0.05},
	"dodge_main": {"id": "dodge_main", "theme": "dodge", "tier": "main", "name": "blessing_dodge_main_name", "description": "blessing_dodge_main_desc", "category": "blessing_cat_main", "color": Color(0.3, 0.8, 0.75, 1.0), "effect": "dodge_bonus", "value": 0.08},
	"counter_main": {"id": "counter_main", "theme": "counter", "tier": "main", "name": "blessing_counter_main_name", "description": "blessing_counter_main_desc", "category": "blessing_cat_main", "color": Color(0.7, 0.2, 0.7, 1.0), "effect": "counter_on_hit", "value": 0.25},
	"skill_boost_main": {"id": "skill_boost_main", "theme": "skill_boost", "tier": "main", "name": "blessing_skill_boost_main_name", "description": "blessing_skill_boost_main_desc", "category": "blessing_cat_main", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_double_charge", "value": 1.0},
	"wealth_main": {"id": "wealth_main", "theme": "wealth", "tier": "main", "name": "blessing_wealth_main_name", "description": "blessing_wealth_main_desc", "category": "blessing_cat_main", "color": Color(1.0, 0.85, 0.2, 1.0), "effect": "gold_bonus", "value": 0.25},
	"summon_main": {"id": "summon_main", "theme": "summon", "tier": "main", "name": "blessing_summon_main_name", "description": "blessing_summon_main_desc", "category": "blessing_cat_main", "color": Color(0.5, 0.2, 0.8, 1.0), "effect": "summon_on_kill", "value": 0.15},
	# --- Sub blessings: fire ---
	"fire_sub_damage": {"id": "fire_sub_damage", "theme": "fire", "tier": "sub", "name": "blessing_fire_sub_damage_name", "description": "blessing_fire_sub_damage_desc", "category": "blessing_cat_sub", "color": Color(1.0, 0.55, 0.15, 1.0), "effect": "burn_damage_bonus", "value": 0.12},
	"fire_sub_spread": {"id": "fire_sub_spread", "theme": "fire", "tier": "sub", "name": "blessing_fire_sub_spread_name", "description": "blessing_fire_sub_spread_desc", "category": "blessing_cat_sub", "color": Color(1.0, 0.45, 0.05, 1.0), "effect": "burn_spread", "value": 1.0},
	# --- Sub blessings: ice ---
	"ice_sub_duration": {"id": "ice_sub_duration", "theme": "ice", "tier": "sub", "name": "blessing_ice_sub_duration_name", "description": "blessing_ice_sub_duration_desc", "category": "blessing_cat_sub", "color": Color(0.5, 0.85, 1.0, 1.0), "effect": "freeze_duration_bonus", "value": 1.0},
	"ice_sub_shatter": {"id": "ice_sub_shatter", "theme": "ice", "tier": "sub", "name": "blessing_ice_sub_shatter_name", "description": "blessing_ice_sub_shatter_desc", "category": "blessing_cat_sub", "color": Color(0.65, 0.9, 1.0, 1.0), "effect": "frozen_bonus_damage", "value": 0.2},
	# --- Sub blessings: crit ---
	"crit_sub_rate": {"id": "crit_sub_rate", "theme": "crit", "tier": "sub", "name": "blessing_crit_sub_rate_name", "description": "blessing_crit_sub_rate_desc", "category": "blessing_cat_sub", "color": Color(1.0, 0.9, 0.35, 1.0), "effect": "crit_rate_bonus", "value": 0.05},
	"crit_sub_multi": {"id": "crit_sub_multi", "theme": "crit", "tier": "sub", "name": "blessing_crit_sub_multi_name", "description": "blessing_crit_sub_multi_desc", "category": "blessing_cat_sub", "color": Color(1.0, 0.8, 0.2, 1.0), "effect": "crit_damage_bonus", "value": 0.2},
	# --- Sub blessings: lifesteal ---
	"lifesteal_sub_low_hp": {"id": "lifesteal_sub_low_hp", "theme": "lifesteal", "tier": "sub", "name": "blessing_lifesteal_sub_low_hp_name", "description": "blessing_lifesteal_sub_low_hp_desc", "category": "blessing_cat_sub", "color": Color(0.9, 0.25, 0.45, 1.0), "effect": "lifesteal_low_hp", "value": 0.3},
	"lifesteal_sub_kill": {"id": "lifesteal_sub_kill", "theme": "lifesteal", "tier": "sub", "name": "blessing_lifesteal_sub_kill_name", "description": "blessing_lifesteal_sub_kill_desc", "category": "blessing_cat_sub", "color": Color(0.75, 0.15, 0.3, 1.0), "effect": "heal_on_kill", "value": 0.05},
	# --- Sub blessings: poison ---
	"poison_sub_stacks": {"id": "poison_sub_stacks", "theme": "poison", "tier": "sub", "name": "blessing_poison_sub_stacks_name", "description": "blessing_poison_sub_stacks_desc", "category": "blessing_cat_sub", "color": Color(0.3, 0.9, 0.35, 1.0), "effect": "poison_max_stacks", "value": 1.0},
	"poison_sub_slow": {"id": "poison_sub_slow", "theme": "poison", "tier": "sub", "name": "blessing_poison_sub_slow_name", "description": "blessing_poison_sub_slow_desc", "category": "blessing_cat_sub", "color": Color(0.15, 0.8, 0.25, 1.0), "effect": "poison_slow", "value": 0.15},
	# --- Sub blessings: generic (no slot restriction) ---
	"generic_atk": {"id": "generic_atk", "theme": "generic", "tier": "sub", "name": "blessing_generic_atk_name", "description": "blessing_generic_atk_desc", "category": "blessing_cat_sub", "color": Color(0.95, 0.5, 0.3, 1.0), "effect": "atk_percent", "value": 0.08},
	"generic_def": {"id": "generic_def", "theme": "generic", "tier": "sub", "name": "blessing_generic_def_name", "description": "blessing_generic_def_desc", "category": "blessing_cat_sub", "color": Color(0.45, 0.65, 0.95, 1.0), "effect": "def_percent", "value": 0.08},
	"generic_hp": {"id": "generic_hp", "theme": "generic", "tier": "sub", "name": "blessing_generic_hp_name", "description": "blessing_generic_hp_desc", "category": "blessing_cat_sub", "color": Color(0.3, 0.85, 0.4, 1.0), "effect": "hp_percent", "value": 0.10},
	"generic_speed": {"id": "generic_speed", "theme": "speed", "tier": "sub", "name": "blessing_generic_speed_name", "description": "blessing_generic_speed_desc", "category": "blessing_cat_sub", "color": Color(0.38, 0.72, 1.0, 1.0), "effect": "speed_percent", "value": 0.12},
	# --- Sub blessings: skill_boost (negative attack trade-offs) ---
	"skill_sub_a": {"id": "skill_sub_a", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_a_name", "description": "blessing_skill_sub_a_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_cd_reduction", "value": 0.05, "penalty_type": "atk_mult", "penalty_value": 0.10},
	"skill_sub_b": {"id": "skill_sub_b", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_b_name", "description": "blessing_skill_sub_b_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_damage_bonus", "value": 0.08, "penalty_type": "speed_mult", "penalty_value": 0.15},
	"skill_sub_c": {"id": "skill_sub_c", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_c_name", "description": "blessing_skill_sub_c_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_range_bonus", "value": 0.15, "penalty_type": "range_mult", "penalty_value": 0.20},
	"skill_sub_d": {"id": "skill_sub_d", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_d_name", "description": "blessing_skill_sub_d_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_extra_charge", "value": 1.0, "penalty_type": "miss_chance", "penalty_value": 0.333},
	"skill_sub_e": {"id": "skill_sub_e", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_e_name", "description": "blessing_skill_sub_e_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_crit_bonus", "value": 0.10, "penalty_type": "self_damage_pct", "penalty_value": 0.01},
	"skill_sub_f": {"id": "skill_sub_f", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_f_name", "description": "blessing_skill_sub_f_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_heal_on_hit", "value": 0.03, "penalty_type": "disable_lifesteal", "penalty_value": 1.0},
	"skill_sub_g": {"id": "skill_sub_g", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_g_name", "description": "blessing_skill_sub_g_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_damage_transfer", "value": 0.15, "penalty_type": "atk_transfer_pct", "penalty_value": 0.15},
	"skill_sub_h": {"id": "skill_sub_h", "theme": "skill_boost", "tier": "sub", "name": "blessing_skill_sub_h_name", "description": "blessing_skill_sub_h_desc", "category": "blessing_cat_sub", "color": Color(0.4, 0.5, 1.0, 1.0), "effect": "skill_invincibility", "value": 2.0, "penalty_type": "self_stun_chance", "penalty_value": 0.10},
}

const THEME_MAIN_BLESSING: Dictionary = {
	"fire": "fire_main", "ice": "ice_main", "poison": "poison_main",
	"crit": "crit_main", "lifesteal": "lifesteal_main", "dodge": "dodge_main",
	"counter": "counter_main", "skill_boost": "skill_boost_main",
	"wealth": "wealth_main", "summon": "summon_main",
}

# Three-slot structure: each slot has a theme and per-slot sub blessings
var blessing_slots: Dictionary = {
	"primary": {"theme": "", "sub_blessings": []},
	"secondary": {"theme": "", "sub_blessings": []},
	"skill": {"theme": "", "sub_blessings": []},
}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# --- Slot queries ---

func get_slot_theme(slot_name: String) -> String:
	if not blessing_slots.has(slot_name):
		return ""
	return str((blessing_slots[slot_name] as Dictionary).get("theme", ""))


func get_slot_sub_blessings(slot_name: String) -> Array:
	if not blessing_slots.has(slot_name):
		return []
	return (blessing_slots[slot_name] as Dictionary).get("sub_blessings", []) as Array


func has_empty_main_slot() -> bool:
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) == "":
			return true
	return false


func get_empty_slots() -> Array[String]:
	var result: Array[String] = []
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) == "":
			result.append(slot_name)
	return result


func get_occupied_slots() -> Array[String]:
	var result: Array[String] = []
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) != "":
			result.append(slot_name)
	return result


func get_assigned_themes() -> Array[String]:
	var result: Array[String] = []
	for slot_name: String in blessing_slots.keys():
		var t: String = get_slot_theme(slot_name)
		if t != "" and not result.has(t):
			result.append(t)
	return result


func is_theme_assigned(theme: String) -> bool:
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) == theme:
			return true
	return false


func get_slot_for_theme(theme: String) -> String:
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) == theme:
			return slot_name
	return ""


func all_slots_filled() -> bool:
	return get_empty_slots().is_empty()


# --- Assignment ---

func assign_main_slot(slot_id: String, theme: String) -> void:
	if not blessing_slots.has(slot_id):
		return
	(blessing_slots[slot_id] as Dictionary)["theme"] = theme
	var filled: int = get_occupied_slots().size()
	var am: Node = get_node_or_null("/root/AchievementManager")
	if am != null and am.has_method("record_blessing_state"):
		am.record_blessing_state(filled)
	blessings_changed.emit()


func add_sub_blessing_to_slot(slot_name: String, blessing_id: String) -> bool:
	if not blessing_slots.has(slot_name):
		return false
	if not BLESSING_DEFS.has(blessing_id):
		return false
	var slot_data: Dictionary = blessing_slots[slot_name] as Dictionary
	var subs: Array = slot_data.get("sub_blessings", []) as Array
	var effectiveness: float = _get_effectiveness(subs.size())
	var found: bool = false
	for entry: Dictionary in subs:
		if str(entry.get("id", "")) == blessing_id:
			entry["stacks"] = int(entry.get("stacks", 1)) + 1
			entry["effectiveness"] = _get_effectiveness(subs.size())
			found = true
			break
	if not found:
		subs.append({"id": blessing_id, "stacks": 1, "effectiveness": effectiveness})
	slot_data["sub_blessings"] = subs
	blessing_slots[slot_name] = slot_data
	blessings_changed.emit()
	return true


# Legacy compat — add sub to first occupied slot with matching theme
func add_sub_blessing(blessing_id: String) -> bool:
	if not BLESSING_DEFS.has(blessing_id):
		return false
	var def: Dictionary = BLESSING_DEFS[blessing_id] as Dictionary
	var theme: String = str(def.get("theme", "generic"))
	# Find a slot with this theme, or first occupied slot for generic
	var target_slot: String = ""
	if theme == "generic" or theme == "speed":
		var occupied: Array[String] = get_occupied_slots()
		if not occupied.is_empty():
			target_slot = occupied[0]
	else:
		target_slot = get_slot_for_theme(theme)
	if target_slot == "":
		var occupied: Array[String] = get_occupied_slots()
		if not occupied.is_empty():
			target_slot = occupied[0]
	if target_slot == "":
		return false
	return add_sub_blessing_to_slot(target_slot, blessing_id)


# Backwards-compatible add_blessing for old code paths
func add_blessing(blessing_id: String) -> bool:
	if not BLESSING_DEFS.has(blessing_id):
		return false
	var def: Dictionary = BLESSING_DEFS[blessing_id] as Dictionary
	if str(def.get("tier", "sub")) == "main":
		var theme: String = str(def.get("theme", ""))
		var empty_slots: Array[String] = get_empty_slots()
		if empty_slots.is_empty():
			return false
		assign_main_slot(empty_slots[0], theme)
		return true
	return add_sub_blessing(blessing_id)


func _get_effectiveness(current_count: int) -> float:
	if current_count < 3:
		return 1.0
	elif current_count < 6:
		return 0.5
	else:
		return 0.25


# --- Choice generation ---

func generate_theme_choices() -> Array[Dictionary]:
	var picked: Array[String] = _pick_random_themes(2)
	var choices: Array[Dictionary] = []
	for theme: String in picked:
		choices.append({
			"id": theme,
			"theme": theme,
			"name": THEME_NAME_KEYS.get(theme, theme),
			"description": THEME_DESC_KEYS.get(theme, ""),
			"category": "blessing_cat_theme",
			"color": THEME_COLORS.get(theme, Color.WHITE) as Color,
			"tier": "main",
		})
	return choices


func _pick_random_themes(count: int) -> Array[String]:
	var pool: Array[String] = []
	var weights: Array[float] = []
	if get_empty_slots().size() == 0:
		# All slots full — only pick from assigned themes
		var active: Array[String] = get_assigned_themes()
		for t: String in active:
			pool.append(t)
			weights.append(float(THEME_WEIGHTS.get(t, 10.0)))
	else:
		for t: String in ALL_THEMES:
			pool.append(t)
			weights.append(float(THEME_WEIGHTS.get(t, 10.0)))
	var result: Array[String] = []
	for _n: int in range(count):
		if pool.is_empty():
			break
		var total: float = 0.0
		for w: float in weights:
			total += w
		if total <= 0.0:
			break
		var roll: float = randf() * total
		var cumulative: float = 0.0
		for i: int in range(pool.size()):
			cumulative += weights[i]
			if roll <= cumulative:
				result.append(pool[i])
				pool.remove_at(i)
				weights.remove_at(i)
				break
	return result


func generate_slot_choices(theme: String) -> Array[Dictionary]:
	var empty_slots: Array[String] = get_empty_slots()
	var theme_color: Color = THEME_COLORS.get(theme, Color.WHITE) as Color
	var theme_name: String = str(THEME_NAME_KEYS.get(theme, theme))
	var choices: Array[Dictionary] = []
	for slot_id: String in empty_slots:
		choices.append({
			"id": slot_id,
			"theme": theme,
			"name": SLOT_NAME_KEYS.get(slot_id, slot_id),
			"description": theme_name,
			"category": "blessing_cat_slot",
			"color": theme_color,
			"tier": "main",
		})
	return choices


func generate_sub_choices_for_slot(slot_name: String) -> Array[Dictionary]:
	var theme: String = get_slot_theme(slot_name)
	if theme == "":
		return []
	var pool: Array[String] = []
	for bid: String in BLESSING_DEFS.keys():
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("tier", "")) != "sub":
			continue
		var t: String = str(def.get("theme", ""))
		if t == theme or t == "generic" or t == "speed":
			pool.append(bid)
	# Shuffle
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var temp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	var choices: Array[Dictionary] = []
	for bid: String in pool:
		if choices.size() >= 3:
			break
		var def: Dictionary = (BLESSING_DEFS[bid] as Dictionary).duplicate(true)
		def["current_stacks"] = _get_sub_stacks_in_slot(slot_name, bid)
		choices.append(def)
	return choices


func generate_sub_choices() -> Array[Dictionary]:
	var assigned: Array[String] = get_assigned_themes()
	var pool: Array[String] = []
	for bid: String in BLESSING_DEFS.keys():
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("tier", "")) != "sub":
			continue
		var t: String = str(def.get("theme", "generic"))
		if assigned.has(t) or t == "generic" or t == "speed":
			pool.append(bid)
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var temp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	var choices: Array[Dictionary] = []
	for bid: String in pool:
		if choices.size() >= 3:
			break
		var def: Dictionary = (BLESSING_DEFS[bid] as Dictionary).duplicate(true)
		choices.append(def)
	return choices


func generate_sub_choices_for_theme(theme: String) -> Array[Dictionary]:
	var slot: String = get_slot_for_theme(theme)
	if slot != "":
		return generate_sub_choices_for_slot(slot)
	return generate_sub_choices()


func generate_three_choices() -> Array[Dictionary]:
	if has_empty_main_slot():
		return generate_theme_choices()
	return generate_sub_choices()


# --- Effect queries ---

func _get_sub_stacks_in_slot(slot_name: String, blessing_id: String) -> int:
	var subs: Array = get_slot_sub_blessings(slot_name)
	for entry: Dictionary in subs:
		if str(entry.get("id", "")) == blessing_id:
			return int(entry.get("stacks", 1))
	return 0


func get_blessing_stacks(blessing_id: String) -> int:
	var total: int = 0
	for slot_name: String in blessing_slots.keys():
		total += _get_sub_stacks_in_slot(slot_name, blessing_id)
	return total


func get_effective_value(blessing_id: String, stacks: int) -> float:
	if not BLESSING_DEFS.has(blessing_id):
		return 0.0
	var base_value: float = float((BLESSING_DEFS[blessing_id] as Dictionary).get("value", 0.0))
	return base_value * maxf(0.25, 1.0 - 0.18 * float(stacks - 1))


func has_effect(effect_name: String) -> bool:
	return get_total_effect_value(effect_name) > 0.0


func get_total_effect_value(effect_name: String) -> float:
	var total: float = 0.0
	for slot_name: String in blessing_slots.keys():
		var theme: String = get_slot_theme(slot_name)
		if theme == "":
			continue
		# Main blessing effect
		var main_bid: String = str(THEME_MAIN_BLESSING.get(theme, ""))
		if main_bid != "" and BLESSING_DEFS.has(main_bid):
			var def: Dictionary = BLESSING_DEFS[main_bid] as Dictionary
			if str(def.get("effect", "")) == effect_name:
				total += get_effective_value(main_bid, 1)
		# Sub blessing effects
		for entry: Dictionary in get_slot_sub_blessings(slot_name):
			var bid: String = str(entry.get("id", ""))
			if not BLESSING_DEFS.has(bid):
				continue
			var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
			if str(def.get("effect", "")) == effect_name:
				var eff: float = float(entry.get("effectiveness", 1.0))
				total += get_effective_value(bid, int(entry.get("stacks", 1))) * eff
	return total


func get_slot_effect_value(slot_name: String, effect_name: String) -> float:
	if not blessing_slots.has(slot_name):
		return 0.0
	var total: float = 0.0
	var theme: String = get_slot_theme(slot_name)
	if theme == "":
		return 0.0
	var main_bid: String = str(THEME_MAIN_BLESSING.get(theme, ""))
	if main_bid != "" and BLESSING_DEFS.has(main_bid):
		var def: Dictionary = BLESSING_DEFS[main_bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			total += get_effective_value(main_bid, 1)
	for entry: Dictionary in get_slot_sub_blessings(slot_name):
		var bid: String = str(entry.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			var eff: float = float(entry.get("effectiveness", 1.0))
			total += get_effective_value(bid, int(entry.get("stacks", 1))) * eff
	return total


func get_skill_sub_penalties(slot_name: String = "") -> Dictionary:
	var penalties: Dictionary = {}
	# If slot_name given, only check that slot; otherwise check all slots with skill_boost
	var slots_to_check: Array[String] = []
	if slot_name != "":
		if get_slot_theme(slot_name) == "skill_boost":
			slots_to_check.append(slot_name)
	else:
		for sn: String in blessing_slots.keys():
			if get_slot_theme(sn) == "skill_boost":
				slots_to_check.append(sn)
	if slots_to_check.is_empty():
		return penalties
	var subs: Array = []
	for sn: String in slots_to_check:
		for entry: Dictionary in get_slot_sub_blessings(sn):
			subs.append(entry)
	for sub: Dictionary in subs:
		var eff: float = float(sub.get("effectiveness", 1.0))
		var bid: String = str(sub.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		var penalty_type: String = str(def.get("penalty_type", ""))
		var penalty_value: float = float(def.get("penalty_value", 0.0))
		if penalty_type == "" or penalty_value <= 0.0:
			continue
		match penalty_type:
			"atk_mult":
				penalties["atk_mult"] = float(penalties.get("atk_mult", 1.0)) * (1.0 - penalty_value * eff)
			"speed_mult":
				penalties["speed_mult"] = float(penalties.get("speed_mult", 1.0)) * (1.0 - penalty_value * eff)
			"range_mult":
				penalties["range_mult"] = float(penalties.get("range_mult", 1.0)) * (1.0 - penalty_value * eff)
			"miss_chance":
				penalties["miss_chance"] = float(penalties.get("miss_chance", 0.0)) + penalty_value * eff
			"self_damage_pct":
				penalties["self_damage_pct"] = float(penalties.get("self_damage_pct", 0.0)) + penalty_value * eff
			"disable_lifesteal":
				penalties["disable_lifesteal"] = true
			"atk_transfer_pct":
				penalties["atk_transfer_pct"] = float(penalties.get("atk_transfer_pct", 0.0)) + penalty_value * eff
			"self_stun_chance":
				penalties["self_stun_chance"] = float(penalties.get("self_stun_chance", 0.0)) + penalty_value * eff
	return penalties


func get_theme_score(theme: String) -> float:
	var score: float = 0.0
	for slot_name: String in blessing_slots.keys():
		if get_slot_theme(slot_name) == theme:
			score += 10.0
		for entry: Dictionary in get_slot_sub_blessings(slot_name):
			var bid: String = str(entry.get("id", ""))
			if not BLESSING_DEFS.has(bid):
				continue
			if str((BLESSING_DEFS[bid] as Dictionary).get("theme", "")) == theme:
				score += 3.0 * float(entry.get("stacks", 1))
	return score


func clear_all() -> void:
	blessing_slots = {
		"primary": {"theme": "", "sub_blessings": []},
		"secondary": {"theme": "", "sub_blessings": []},
		"skill": {"theme": "", "sub_blessings": []},
	}
	blessings_changed.emit()
