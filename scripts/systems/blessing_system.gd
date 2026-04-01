extends Node

signal blessings_changed
signal blessing_theme_selected(theme: String)

const THEMES: Array[String] = ["fire", "ice", "poison", "crit", "lifesteal"]

const THEME_COLORS: Dictionary = {
	"fire": Color(1.0, 0.3, 0.1, 1.0),
	"ice": Color(0.3, 0.7, 1.0, 1.0),
	"poison": Color(0.2, 0.85, 0.2, 1.0),
	"crit": Color(1.0, 0.75, 0.1, 1.0),
	"lifesteal": Color(0.8, 0.1, 0.3, 1.0),
}

const THEME_NAME_KEYS: Dictionary = {
	"fire": "blessing_theme_fire",
	"ice": "blessing_theme_ice",
	"poison": "blessing_theme_poison",
	"crit": "blessing_theme_crit",
	"lifesteal": "blessing_theme_lifesteal",
}

const THEME_DESC_KEYS: Dictionary = {
	"fire": "blessing_theme_fire_desc",
	"ice": "blessing_theme_ice_desc",
	"poison": "blessing_theme_poison_desc",
	"crit": "blessing_theme_crit_desc",
	"lifesteal": "blessing_theme_lifesteal_desc",
}

const SLOT_NAME_KEYS: Dictionary = {
	"primary": "blessing_slot_primary",
	"secondary": "blessing_slot_secondary",
	"skill": "blessing_slot_skill",
}

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
	"poison_sub_stacks": {
		"id": "poison_sub_stacks", "theme": "poison", "tier": "sub",
		"name": "blessing_poison_sub_stacks_name",
		"description": "blessing_poison_sub_stacks_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.3, 0.9, 0.35, 1.0),
		"effect": "poison_max_stacks", "value": 1.0,
	},
	"poison_sub_slow": {
		"id": "poison_sub_slow", "theme": "poison", "tier": "sub",
		"name": "blessing_poison_sub_slow_name",
		"description": "blessing_poison_sub_slow_desc",
		"category": "blessing_cat_sub",
		"color": Color(0.15, 0.8, 0.25, 1.0),
		"effect": "poison_slow", "value": 0.15,
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

# Maps theme to its main blessing id
const THEME_MAIN_BLESSING: Dictionary = {
	"fire": "fire_main",
	"ice": "ice_main",
	"poison": "poison_main",
	"crit": "crit_main",
	"lifesteal": "lifesteal_main",
}

# Slot-based main blessings: each slot holds a theme string or ""
var main_blessing_slots: Dictionary = {
	"primary": "",
	"secondary": "",
	"skill": "",
}

var active_sub_blessings: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# --- Slot queries ---

func has_empty_main_slot() -> bool:
	for slot_id: String in main_blessing_slots.keys():
		if str(main_blessing_slots[slot_id]) == "":
			return true
	return false


func get_empty_slots() -> Array[String]:
	var empty: Array[String] = []
	for slot_id: String in main_blessing_slots.keys():
		if str(main_blessing_slots[slot_id]) == "":
			empty.append(slot_id)
	return empty


func is_theme_assigned(theme: String) -> bool:
	for slot_id: String in main_blessing_slots.keys():
		if str(main_blessing_slots[slot_id]) == theme:
			return true
	return false


func get_assigned_themes() -> Array[String]:
	var themes: Array[String] = []
	for slot_id: String in main_blessing_slots.keys():
		var t: String = str(main_blessing_slots[slot_id])
		if t != "" and not themes.has(t):
			themes.append(t)
	return themes


func all_slots_filled() -> bool:
	return get_empty_slots().is_empty()


# --- Assignment ---

func assign_main_slot(slot_id: String, theme: String) -> void:
	if main_blessing_slots.has(slot_id):
		main_blessing_slots[slot_id] = theme
	blessings_changed.emit()


func add_sub_blessing(blessing_id: String) -> bool:
	if not BLESSING_DEFS.has(blessing_id):
		return false
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


# Backwards-compatible add_blessing for old code paths
func add_blessing(blessing_id: String) -> bool:
	if not BLESSING_DEFS.has(blessing_id):
		return false
	var def: Dictionary = BLESSING_DEFS[blessing_id] as Dictionary
	if str(def.get("tier", "sub")) == "main":
		# Find first empty slot and assign theme
		var theme: String = str(def.get("theme", ""))
		var empty_slots: Array[String] = get_empty_slots()
		if empty_slots.is_empty():
			return false
		assign_main_slot(empty_slots[0], theme)
		return true
	return add_sub_blessing(blessing_id)


# --- Choice generation ---

func generate_theme_choices() -> Array[Dictionary]:
	var pool: Array[String] = THEMES.duplicate()
	# Shuffle
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var temp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	var choices: Array[Dictionary] = []
	for theme: String in pool:
		if choices.size() >= 2:
			break
		choices.append({
			"id": theme,
			"name": THEME_NAME_KEYS.get(theme, theme),
			"description": THEME_DESC_KEYS.get(theme, ""),
			"category": "blessing_cat_theme",
			"color": THEME_COLORS.get(theme, Color.WHITE) as Color,
			"tier": "main",
		})
	return choices


func generate_slot_choices(theme: String) -> Array[Dictionary]:
	var empty_slots: Array[String] = get_empty_slots()
	var theme_color: Color = THEME_COLORS.get(theme, Color.WHITE) as Color
	var theme_name: String = str(THEME_NAME_KEYS.get(theme, theme))
	var choices: Array[Dictionary] = []
	for slot_id: String in empty_slots:
		choices.append({
			"id": slot_id,
			"name": SLOT_NAME_KEYS.get(slot_id, slot_id),
			"description": theme_name,
			"category": "blessing_cat_slot",
			"color": theme_color,
			"tier": "main",
		})
	return choices


func generate_sub_choices() -> Array[Dictionary]:
	var assigned: Array[String] = get_assigned_themes()
	# Collect sub-blessings matching assigned themes + generic
	var pool: Array[String] = []
	for bid: String in BLESSING_DEFS.keys():
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("tier", "")) != "sub":
			continue
		var theme: String = str(def.get("theme", "generic"))
		if assigned.has(theme) or theme == "generic" or theme == "speed":
			pool.append(bid)
	# Shuffle and pick 3
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
		def["current_stacks"] = get_blessing_stacks(bid)
		choices.append(def)
	return choices


func generate_sub_choices_for_theme(theme: String) -> Array[Dictionary]:
	var pool: Array[String] = []
	for bid: String in BLESSING_DEFS.keys():
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("tier", "")) != "sub":
			continue
		var t: String = str(def.get("theme", ""))
		if t == theme or t == "generic" or t == "speed":
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
		def["current_stacks"] = get_blessing_stacks(bid)
		choices.append(def)
	return choices


# Kept for compatibility — old generate_three_choices calls
func generate_three_choices() -> Array[Dictionary]:
	if has_empty_main_slot():
		return generate_theme_choices()
	return generate_sub_choices()


# --- Effect queries ---

func get_blessing_stacks(blessing_id: String) -> int:
	for entry: Dictionary in active_sub_blessings:
		if str(entry.get("id", "")) == blessing_id:
			return int(entry.get("stacks", 1))
	return 0


func get_effective_value(blessing_id: String, stacks: int) -> float:
	if not BLESSING_DEFS.has(blessing_id):
		return 0.0
	var base_value: float = float((BLESSING_DEFS[blessing_id] as Dictionary).get("value", 0.0))
	return base_value * maxf(0.25, 1.0 - 0.18 * float(stacks - 1))


func has_effect(effect_name: String) -> bool:
	return get_total_effect_value(effect_name) > 0.0


func get_total_effect_value(effect_name: String) -> float:
	var total: float = 0.0
	# Main blessings from slots
	for slot_id: String in main_blessing_slots.keys():
		var theme: String = str(main_blessing_slots[slot_id])
		if theme == "":
			continue
		var main_bid: String = str(THEME_MAIN_BLESSING.get(theme, ""))
		if main_bid == "" or not BLESSING_DEFS.has(main_bid):
			continue
		var def: Dictionary = BLESSING_DEFS[main_bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			total += get_effective_value(main_bid, 1)
	# Sub blessings
	for entry: Dictionary in active_sub_blessings:
		var bid: String = str(entry.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		var def: Dictionary = BLESSING_DEFS[bid] as Dictionary
		if str(def.get("effect", "")) == effect_name:
			total += get_effective_value(bid, int(entry.get("stacks", 1)))
	return total


func get_theme_score(theme: String) -> float:
	var score: float = 0.0
	for slot_id: String in main_blessing_slots.keys():
		if str(main_blessing_slots[slot_id]) == theme:
			score += 10.0
	for entry: Dictionary in active_sub_blessings:
		var bid: String = str(entry.get("id", ""))
		if not BLESSING_DEFS.has(bid):
			continue
		if str((BLESSING_DEFS[bid] as Dictionary).get("theme", "")) == theme:
			score += 3.0 * float(entry.get("stacks", 1))
	return score


func clear_all() -> void:
	main_blessing_slots = {"primary": "", "secondary": "", "skill": ""}
	active_sub_blessings.clear()
	blessings_changed.emit()
