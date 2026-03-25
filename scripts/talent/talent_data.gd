extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "Offense",
	"defense": "Defense",
	"support": "Support",
}

const TALENTS := {
	"O1": {
		"id": "O1",
		"name": "Sharp Edge",
		"branch": "offense",
		"cost": 3,
		"prerequisite": "",
		"description": "Attack +5",
		"effects": {"attack": 5},
	},
	"O2": {
		"id": "O2",
		"name": "Power Strike",
		"branch": "offense",
		"cost": 5,
		"prerequisite": "O1",
		"description": "Attack +10",
		"effects": {"attack": 10},
	},
	"O3": {
		"id": "O3",
		"name": "Critical Eye",
		"branch": "offense",
		"cost": 8,
		"prerequisite": "O2",
		"description": "Critical chance +10%",
		"effects": {"crit_chance": 0.1},
	},
	"O4": {
		"id": "O4",
		"name": "Berserker",
		"branch": "offense",
		"cost": 12,
		"prerequisite": "O3",
		"description": "Attack +20, Defense -5",
		"effects": {"attack": 20, "defense": -5},
	},
	"O5": {
		"id": "O5",
		"name": "Executioner",
		"branch": "offense",
		"cost": 15,
		"prerequisite": "O4",
		"description": "+50% damage to enemies below 30% HP",
		"effects": {"execute_bonus": 0.5},
	},
	"D1": {
		"id": "D1",
		"name": "Tough Skin",
		"branch": "defense",
		"cost": 3,
		"prerequisite": "",
		"description": "Max HP +20",
		"effects": {"max_hp": 20},
	},
	"D2": {
		"id": "D2",
		"name": "Iron Body",
		"branch": "defense",
		"cost": 5,
		"prerequisite": "D1",
		"description": "Defense +5",
		"effects": {"defense": 5},
	},
	"D3": {
		"id": "D3",
		"name": "Shield Wall",
		"branch": "defense",
		"cost": 8,
		"prerequisite": "D2",
		"description": "Block 15% damage",
		"effects": {"block_chance": 0.15},
	},
	"D4": {
		"id": "D4",
		"name": "Regeneration",
		"branch": "defense",
		"cost": 12,
		"prerequisite": "D3",
		"description": "Regenerate 1 HP every 5 seconds",
		"effects": {"regen_amount": 1, "regen_interval": 5.0},
	},
	"D5": {
		"id": "D5",
		"name": "Undying Will",
		"branch": "defense",
		"cost": 15,
		"prerequisite": "D4",
		"description": "Survive one fatal hit per dungeon run",
		"effects": {"undying_will": 1},
	},
	"S1": {
		"id": "S1",
		"name": "Quick Step",
		"branch": "support",
		"cost": 3,
		"prerequisite": "",
		"description": "Move speed +10%",
		"effects": {"speed_multiplier": 0.1},
	},
	"S2": {
		"id": "S2",
		"name": "Gatherer",
		"branch": "support",
		"cost": 5,
		"prerequisite": "S1",
		"description": "+1 resource from gathering",
		"effects": {"gather_bonus": 1},
	},
	"S3": {
		"id": "S3",
		"name": "Lucky Find",
		"branch": "support",
		"cost": 8,
		"prerequisite": "S2",
		"description": "Loot drop chance +15%",
		"effects": {"loot_bonus": 0.15},
	},
	"S4": {
		"id": "S4",
		"name": "Efficient Craft",
		"branch": "support",
		"cost": 12,
		"prerequisite": "S3",
		"description": "Crafting costs -25%",
		"effects": {"craft_cost_multiplier": -0.25},
	},
	"S5": {
		"id": "S5",
		"name": "Explorer",
		"branch": "support",
		"cost": 15,
		"prerequisite": "S4",
		"description": "Minimap reveals the full floor",
		"effects": {"full_minimap": 1},
	},
	"S6": {
		"id": "S6",
		"name": "Loot Magnet",
		"branch": "support",
		"cost": 8,
		"prerequisite": "S5",
		"description": "Loot pickup range +50px",
		"effects": {"loot_pickup_range": 50.0},
	},
}


static func get_all_talents() -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent_id in TALENTS.keys():
		talents.append(get_talent(talent_id))
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return talents


static func get_talent(talent_id: String) -> Dictionary:
	if not TALENTS.has(talent_id):
		return {}
	return TALENTS[talent_id].duplicate(true)


static func get_branch_ids() -> PackedStringArray:
	return PackedStringArray(BRANCH_ORDER)


static func get_branch_label(branch_id: String) -> String:
	return str(BRANCH_LABELS.get(branch_id, branch_id.capitalize()))


static func get_branch_talents(branch_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) == branch_id:
			talents.append(talent)
	return talents


static func can_unlock(unlocked_talents: Array[String], talent_shards: int, talent_id: String) -> bool:
	var talent := get_talent(talent_id)
	if talent.is_empty():
		return false
	if unlocked_talents.has(talent_id):
		return false
	if talent_shards < int(talent.get("cost", 0)):
		return false
	var prerequisite := str(talent.get("prerequisite", ""))
	return prerequisite == "" or unlocked_talents.has(prerequisite)
