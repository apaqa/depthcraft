extends RefCounted
class_name BossData

const BOSS_TABLE: Dictionary = {
	5: {
		"name_key": "boss_skeleton_king",
		"hp_mult": 1.0,
		"atk_mult": 1.0,
		"speed": 35.0,
		"color": Color(0.85, 0.85, 0.75, 1.0),
		"abilities": ["melee_slam"],
		"aoe_cooldown": 5.0,
		"aoe_radius": 56.0,
	},
	10: {
		"name_key": "boss_slime_mother",
		"hp_mult": 1.4,
		"atk_mult": 0.8,
		"speed": 28.0,
		"color": Color(0.35, 0.85, 0.35, 1.0),
		"abilities": ["melee_slam", "split_on_half"],
		"aoe_cooldown": 6.0,
		"aoe_radius": 64.0,
	},
	15: {
		"name_key": "boss_shadow_mage",
		"hp_mult": 1.2,
		"atk_mult": 1.4,
		"speed": 45.0,
		"color": Color(0.55, 0.25, 0.85, 1.0),
		"abilities": ["teleport", "projectile_burst"],
		"aoe_cooldown": 7.0,
		"aoe_radius": 48.0,
	},
	20: {
		"name_key": "boss_lava_golem",
		"hp_mult": 1.8,
		"atk_mult": 1.3,
		"speed": 24.0,
		"color": Color(1.0, 0.45, 0.12, 1.0),
		"abilities": ["melee_slam", "ground_slam"],
		"aoe_cooldown": 8.0,
		"aoe_radius": 72.0,
	},
	25: {
		"name_key": "boss_abyss_warden",
		"hp_mult": 2.2,
		"atk_mult": 1.6,
		"speed": 42.0,
		"color": Color(0.15, 0.25, 0.55, 1.0),
		"abilities": ["dash_attack", "summon_minions"],
		"aoe_cooldown": 6.0,
		"aoe_radius": 60.0,
	},
	30: {
		"name_key": "boss_lord_of_abyss",
		"hp_mult": 3.0,
		"atk_mult": 2.0,
		"speed": 48.0,
		"color": Color(0.85, 0.12, 0.12, 1.0),
		"abilities": ["melee_slam", "teleport", "dash_attack", "ground_slam"],
		"aoe_cooldown": 4.0,
		"aoe_radius": 80.0,
	},
}


static func get_boss_data(floor_number: int) -> Dictionary:
	# Find the appropriate boss for this floor
	var boss_floor: int = int(floor_number / 5) * 5
	if boss_floor <= 0:
		boss_floor = 5
	if boss_floor > 30:
		boss_floor = 30
	if BOSS_TABLE.has(boss_floor):
		return (BOSS_TABLE[boss_floor] as Dictionary).duplicate(true)
	return (BOSS_TABLE[5] as Dictionary).duplicate(true)
