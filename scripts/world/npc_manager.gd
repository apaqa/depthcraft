extends Node

signal roster_changed(recruited_count: int)

const ROLE_FARMER: String = "farmer"
const ROLE_GUARD: String = "guard"
const ROLE_MERCHANT_ASSISTANT: String = "merchant_assistant"
const ROLE_BLACKSMITH: String = "blacksmith"
const ROLE_EXPLORER: String = "explorer"

const DEFAULT_DAY: int = 1
const FARMER_WHEAT_MIN: int = 1
const FARMER_WHEAT_MAX: int = 3
const GUARD_DAMAGE_PER_VOLLEY: int = 6
const GUARD_DAMAGE_REDUCTION_PER_NPC: int = 1
const GUARD_ATTACK_INTERVAL: float = 1.5
const MERCHANT_DISCOUNT_MULTIPLIER: float = 0.9
const BLACKSMITH_DISCOUNT_MULTIPLIER: float = 0.5
const ROLE_BASE_STATS: Dictionary = {
	ROLE_FARMER: {
		"vitality": 20,
		"support": 3,
		"skill": 4,
	},
	ROLE_GUARD: {
		"attack": GUARD_DAMAGE_PER_VOLLEY,
		"defense": GUARD_DAMAGE_REDUCTION_PER_NPC,
		"vitality": 28,
	},
	ROLE_MERCHANT_ASSISTANT: {
		"support": 4,
		"trade": 5,
		"vitality": 20,
	},
	ROLE_BLACKSMITH: {
		"craft": 6,
		"defense": 2,
		"vitality": 24,
	},
	ROLE_EXPLORER: {
		"agility": 6,
		"support": 3,
		"vitality": 22,
	},
}

const ROLE_ORDER: PackedStringArray = [
	ROLE_FARMER,
	ROLE_GUARD,
	ROLE_MERCHANT_ASSISTANT,
	ROLE_BLACKSMITH,
	ROLE_EXPLORER,
]

const ROLE_DATA: Dictionary = {
	ROLE_FARMER: {
		"name_zh": "農夫",
		"name_en": "Farmer",
		"portraits": [
			"res://assets/npc_dwarf.png",
			"res://assets/npc_barbarian.png",
		],
	},
	ROLE_GUARD: {
		"name_zh": "守衛",
		"name_en": "Guard",
		"portraits": [
			"res://assets/npc_knight_blue.png",
			"res://assets/npc_knight_green.png",
		],
	},
	ROLE_MERCHANT_ASSISTANT: {
		"name_zh": "商人助手",
		"name_en": "Merchant Assistant",
		"portraits": [
			"res://assets/npc_merchant.png",
			"res://assets/npc_merchant_2.png",
		],
	},
	ROLE_BLACKSMITH: {
		"name_zh": "鐵匠",
		"name_en": "Blacksmith",
		"portraits": [
			"res://assets/npc_paladin.png",
			"res://assets/npc_knight_yellow.png",
		],
	},
	ROLE_EXPLORER: {
		"name_zh": "探險家",
		"name_en": "Explorer",
		"portraits": [
			"res://assets/npc_elf.png",
			"res://assets/npc_trickster.png",
		],
	},
}

const NAME_POOL_ZH: PackedStringArray = [
	"阿洛",
	"米菈",
	"拓恩",
	"賽娜",
	"魯卡",
	"伊芙",
	"柏恩",
	"維拉",
	"羅恩",
	"萊雅",
]

const NAME_POOL_EN: PackedStringArray = [
	"Alden",
	"Mira",
	"Toren",
	"Selene",
	"Bram",
	"Lyra",
	"Corin",
	"Nessa",
	"Rook",
	"Vale",
]

const EXPLORER_BUFFS: PackedStringArray = [
	"atk_up_1",
	"speed_up",
	"regen",
	"armor",
]

const EXPLORER_BUFF_NAME_KEYS: Dictionary = {
	"atk_up_1": "buff_atk_up_1_name",
	"speed_up": "buff_speed_up_name",
	"regen": "buff_regen_name",
	"armor": "buff_armor_name",
}

const EXPLORER_HINTS_ZH: PackedStringArray = [
	"今天北側岔路比較安全，想穩扎穩打就靠右走。",
	"第一層常有補給箱，別急著衝太深。",
	"如果看到狹窄走廊，先拉怪再進去比較穩。",
	"今天的怪物步調偏快，保留位移技能會更安全。",
]

const EXPLORER_HINTS_EN: PackedStringArray = [
	"The northern split looks safer today. Take the right path if you want a steady run.",
	"Supply chests are common on the first floor today. Do not rush too deep.",
	"Narrow corridors are risky. Pull enemies out before committing.",
	"Monsters feel faster today. Save one movement skill for emergencies.",
]

var recruited_npcs: Array[Dictionary] = []
var current_day: int = DEFAULT_DAY
var _last_processed_day: int = DEFAULT_DAY
var _last_claimed_explorer_day: int = 0


func recruit_npc(npc_data: Dictionary) -> void:
	var recruited_data: Dictionary = npc_data.duplicate(true)
	var npc_id: String = str(recruited_data.get("id", ""))
	if npc_id == "":
		npc_id = "npc_%d_%d" % [current_day, recruited_npcs.size()]
		recruited_data["id"] = npc_id
	for existing_npc: Dictionary in recruited_npcs:
		if str(existing_npc.get("id", "")) == npc_id:
			return
	_ensure_npc_stats(recruited_data)
	recruited_data["recruited"] = true
	recruited_data["recruited_day"] = current_day
	recruited_npcs.append(recruited_data)
	_emit_roster_changed()


func get_npcs_by_role(role: String) -> Array[Dictionary]:
	var filtered_npcs: Array[Dictionary] = []
	for npc_data: Dictionary in recruited_npcs:
		if str(npc_data.get("role", "")) == role:
			filtered_npcs.append(npc_data.duplicate(true))
	return filtered_npcs


func get_role_count(role: String) -> int:
	return get_npcs_by_role(role).size()


func get_recruited_count() -> int:
	return recruited_npcs.size()


func has_role(role: String) -> bool:
	return get_role_count(role) > 0


func get_all_roles() -> Array[String]:
	var roles: Array[String] = []
	for role_id: String in ROLE_ORDER:
		roles.append(role_id)
	return roles


func get_role_display_name(role: String) -> String:
	var role_definition: Dictionary = ROLE_DATA.get(role, {}) as Dictionary
	if _is_zh_locale():
		return str(role_definition.get("name_zh", role))
	return str(role_definition.get("name_en", role))


func get_dialog_text(npc_data: Dictionary) -> String:
	var npc_name: String = str(npc_data.get("name", "旅人"))
	var role_name: String = get_role_display_name(str(npc_data.get("role", "")))
	if _is_zh_locale():
		return "你好旅行者，我是 %s，我擅長 %s。要我加入你的據點嗎？" % [npc_name, role_name]
	return "Hello traveler, I'm %s, and I specialize as a %s. Want me to join your base?" % [npc_name, role_name]


func create_random_wanderer(seed_value: int, index: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("wanderer:%d:%d" % [seed_value, index]))
	var role: String = ROLE_ORDER[rng.randi_range(0, ROLE_ORDER.size() - 1)]
	var npc_name: String = _pick_random_name(rng, index)
	var portrait_path: String = _pick_portrait_path(role, rng)
	var recruit_world_level: int = WorldLevel.get_world_level() if WorldLevel != null else 1
	return {
		"id": "wanderer_%d_%d" % [seed_value, index],
		"name": npc_name,
		"role": role,
		"portrait_path": portrait_path,
		"stats": _build_scaled_npc_stats(role, recruit_world_level),
		"world_level_at_recruit": recruit_world_level,
	}


func get_settlement_offset(index: int) -> Vector2:
	var slot_offsets: Array[Vector2] = [
		Vector2(-40.0, 28.0),
		Vector2(-16.0, 36.0),
		Vector2(12.0, 30.0),
		Vector2(38.0, 22.0),
		Vector2(-52.0, 52.0),
		Vector2(-8.0, 56.0),
		Vector2(28.0, 52.0),
		Vector2(56.0, 42.0),
	]
	if index >= 0 and index < slot_offsets.size():
		return slot_offsets[index]
	var ring_index: int = max(index - slot_offsets.size(), 0)
	var angle: float = TAU * float(ring_index % 8) / 8.0
	var radius: float = 68.0 + float(ring_index / 8) * 16.0
	return Vector2.RIGHT.rotated(angle) * radius + Vector2(0.0, 30.0)


func get_merchant_price_multiplier() -> float:
	if get_role_count(ROLE_MERCHANT_ASSISTANT) <= 0:
		return 1.0
	return MERCHANT_DISCOUNT_MULTIPLIER


func get_merchant_stock_bonus() -> int:
	var assistant_count: int = get_role_count(ROLE_MERCHANT_ASSISTANT)
	var support_total: int = _get_role_stat_total(ROLE_MERCHANT_ASSISTANT, "support", 4)
	return maxi(assistant_count, int(round(float(support_total) / 4.0)))


func get_repair_cost_multiplier() -> float:
	if get_role_count(ROLE_BLACKSMITH) <= 0:
		return 1.0
	return BLACKSMITH_DISCOUNT_MULTIPLIER


func get_guard_damage_per_volley() -> int:
	return _get_role_stat_total(ROLE_GUARD, "attack", GUARD_DAMAGE_PER_VOLLEY)


func get_guard_damage_reduction() -> int:
	return _get_role_stat_total(ROLE_GUARD, "defense", GUARD_DAMAGE_REDUCTION_PER_NPC)


func get_guard_attack_interval() -> float:
	return GUARD_ATTACK_INTERVAL


func process_new_day(day: int, player: Node) -> Array[String]:
	var messages: Array[String] = []
	if day <= _last_processed_day:
		current_day = max(day, DEFAULT_DAY)
		return messages
	current_day = max(day, DEFAULT_DAY)

	var total_wheat_harvested: int = 0
	var farmer_count: int = get_role_count(ROLE_FARMER)
	if farmer_count > 0 and player != null:
		for processed_day: int in range(_last_processed_day + 1, current_day + 1):
			total_wheat_harvested += _roll_farmer_wheat(processed_day, farmer_count)
		if total_wheat_harvested > 0 and "inventory" in player and player.inventory != null:
			if player.inventory.add_item("wheat", total_wheat_harvested):
				messages.append(_get_farmer_message(total_wheat_harvested))

	_last_processed_day = current_day
	return messages


func set_current_day(day: int) -> void:
	current_day = max(day, DEFAULT_DAY)
	if _last_processed_day < DEFAULT_DAY:
		_last_processed_day = DEFAULT_DAY


func has_available_explorer_intel(day: int = -1) -> bool:
	var target_day: int = current_day if day <= 0 else day
	return get_role_count(ROLE_EXPLORER) > 0 and _last_claimed_explorer_day < target_day


func claim_explorer_intel(player: Node, day: int = -1) -> Dictionary:
	var target_day: int = current_day if day <= 0 else day
	if get_role_count(ROLE_EXPLORER) <= 0:
		return {}
	if _last_claimed_explorer_day >= target_day:
		return {
			"type": "empty",
			"message": get_explorer_unavailable_message(),
		}
	var intel: Dictionary = get_explorer_intel(target_day)
	if intel.is_empty():
		return {}
	if str(intel.get("type", "")) == "buff" and player != null and player.has_method("apply_buff"):
		player.apply_buff(str(intel.get("buff_id", "")))
	_last_claimed_explorer_day = target_day
	return intel


func get_explorer_intel(day: int = -1) -> Dictionary:
	var target_day: int = current_day if day <= 0 else day
	if get_role_count(ROLE_EXPLORER) <= 0:
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("explorer:%d:%d" % [target_day, get_role_count(ROLE_EXPLORER)]))
	var roll_buff: bool = rng.randf() < 0.5
	if roll_buff:
		var buff_id: String = EXPLORER_BUFFS[rng.randi_range(0, EXPLORER_BUFFS.size() - 1)]
		var buff_name_key: String = str(EXPLORER_BUFF_NAME_KEYS.get(buff_id, ""))
		var buff_name: String = buff_name_key if buff_name_key == "" else LocaleManager.L(buff_name_key)
		if _is_zh_locale():
			return {
				"type": "buff",
				"buff_id": buff_id,
				"message": "探險家情報：今天的入口路線很順，出發前先拿上「%s」。" % buff_name,
			}
		return {
			"type": "buff",
			"buff_id": buff_id,
			"message": "Scout intel: the route looks favorable today. Take \"%s\" before you descend." % buff_name,
		}
	var hints: PackedStringArray = EXPLORER_HINTS_ZH if _is_zh_locale() else EXPLORER_HINTS_EN
	return {
		"type": "hint",
		"message": hints[rng.randi_range(0, hints.size() - 1)],
	}


func get_explorer_prompt_suffix() -> String:
	if get_role_count(ROLE_EXPLORER) <= 0:
		return ""
	if _is_zh_locale():
		return "  [F] 取情報"
	return "  [F] Scout Intel"


func get_explorer_unavailable_message() -> String:
	if _is_zh_locale():
		return "今天的探險情報已經領過了。"
	return "Today's scout intel has already been claimed."


func serialize_state() -> Dictionary:
	var roster_payload: Array[Dictionary] = []
	for npc_data: Dictionary in recruited_npcs:
		roster_payload.append(npc_data.duplicate(true))
	return {
		"recruited_npcs": roster_payload,
		"current_day": current_day,
		"last_processed_day": _last_processed_day,
		"last_claimed_explorer_day": _last_claimed_explorer_day,
	}


func restore_state(data: Dictionary) -> void:
	recruited_npcs.clear()
	var saved_roster: Variant = data.get("recruited_npcs", data.get("recruited", []))
	if saved_roster is Array:
		for npc_variant: Variant in saved_roster:
			if npc_variant is Dictionary:
				var restored_npc: Dictionary = (npc_variant as Dictionary).duplicate(true)
				_ensure_npc_stats(restored_npc)
				recruited_npcs.append(restored_npc)
	current_day = max(int(data.get("current_day", current_day)), DEFAULT_DAY)
	_last_processed_day = max(int(data.get("last_processed_day", current_day)), DEFAULT_DAY)
	_last_claimed_explorer_day = max(int(data.get("last_claimed_explorer_day", 0)), 0)
	_emit_roster_changed()


func clear_state() -> void:
	recruited_npcs.clear()
	current_day = DEFAULT_DAY
	_last_processed_day = DEFAULT_DAY
	_last_claimed_explorer_day = 0
	_emit_roster_changed()


func _emit_roster_changed() -> void:
	roster_changed.emit(recruited_npcs.size())


func _roll_farmer_wheat(day: int, farmer_count: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("farmer:%d:%d" % [day, farmer_count]))
	var total_wheat: int = 0
	for _index: int in range(farmer_count):
		total_wheat += rng.randi_range(FARMER_WHEAT_MIN, FARMER_WHEAT_MAX)
	return total_wheat


func _get_farmer_message(wheat_amount: int) -> String:
	if _is_zh_locale():
		return "農夫替你收成了 %d 小麥。" % wheat_amount
	return "Your farmers harvested %d wheat for the day." % wheat_amount


func _pick_random_name(rng: RandomNumberGenerator, index: int) -> String:
	var name_pool: PackedStringArray = NAME_POOL_ZH if _is_zh_locale() else NAME_POOL_EN
	var base_name: String = name_pool[rng.randi_range(0, name_pool.size() - 1)]
	return "%s%d" % [base_name, index + 1]


func _pick_portrait_path(role: String, rng: RandomNumberGenerator) -> String:
	var role_definition: Dictionary = ROLE_DATA.get(role, {}) as Dictionary
	var portrait_paths: Array[String] = []
	var raw_portraits: Variant = role_definition.get("portraits", [])
	if raw_portraits is Array:
		for portrait_variant: Variant in raw_portraits:
			portrait_paths.append(str(portrait_variant))
	if portrait_paths.is_empty():
		return "res://assets/npc_merchant.png"
	return portrait_paths[rng.randi_range(0, portrait_paths.size() - 1)]


func _build_scaled_npc_stats(role: String, recruit_world_level: int = 0) -> Dictionary:
	var role_stats: Dictionary = ROLE_BASE_STATS.get(role, {}) as Dictionary
	var resolved_world_level: int = recruit_world_level
	if resolved_world_level <= 0:
		resolved_world_level = WorldLevel.get_world_level() if WorldLevel != null else 1
	var multiplier: float = 1.0 + float(resolved_world_level) * 0.04
	var scaled_stats: Dictionary = {}
	for stat_name_variant: Variant in role_stats.keys():
		var stat_name: String = str(stat_name_variant)
		var base_value: int = int(role_stats.get(stat_name_variant, 0))
		scaled_stats[stat_name] = maxi(int(round(float(base_value) * multiplier)), 1)
	return scaled_stats


func _ensure_npc_stats(npc_data: Dictionary) -> void:
	var existing_stats_variant: Variant = npc_data.get("stats", {})
	if existing_stats_variant is Dictionary and not (existing_stats_variant as Dictionary).is_empty():
		if not npc_data.has("world_level_at_recruit"):
			npc_data["world_level_at_recruit"] = WorldLevel.get_world_level() if WorldLevel != null else 1
		return
	var recruit_world_level: int = int(npc_data.get("world_level_at_recruit", 0))
	if recruit_world_level <= 0:
		recruit_world_level = WorldLevel.get_world_level() if WorldLevel != null else 1
	npc_data["stats"] = _build_scaled_npc_stats(str(npc_data.get("role", "")), recruit_world_level)
	npc_data["world_level_at_recruit"] = recruit_world_level


func _get_role_stat_total(role: String, stat_name: String, fallback_per_npc: int) -> int:
	var total_value: int = 0
	for npc_data: Dictionary in recruited_npcs:
		if str(npc_data.get("role", "")) != role:
			continue
		_ensure_npc_stats(npc_data)
		var stats: Dictionary = npc_data.get("stats", {}) as Dictionary
		total_value += int(stats.get(stat_name, fallback_per_npc))
	return total_value


func _is_zh_locale() -> bool:
	return str(LocaleManager.get_locale()).begins_with("zh")
