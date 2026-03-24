extends Node

const ITEMS := {
	"wood": {
		"id": "wood",
		"name": "Wood",
		"max_stack": 99,
		"type": "resource",
		"description": "Basic building material",
		"icon": preload("res://assets/crate.png"),
	},
	"stone": {
		"id": "stone",
		"name": "Stone",
		"max_stack": 99,
		"type": "resource",
		"description": "Hard building material",
		"icon": preload("res://assets/monster_elemental_earth_small.png"),
	},
	"iron_ore": {
		"id": "iron_ore",
		"name": "Iron Ore",
		"max_stack": 99,
		"type": "resource",
		"description": "Raw metal ore",
		"icon": preload("res://assets/monster_elemental_gold_short.png"),
	},
	"fiber": {
		"id": "fiber",
		"name": "Fiber",
		"max_stack": 99,
		"type": "resource",
		"description": "Plant fiber for crafting",
		"icon": preload("res://assets/monster_elemental_plant_small.png"),
	},
	"wood_sword": {
		"id": "wood_sword",
		"name": "Wood Sword",
		"max_stack": 1,
		"type": "equipment",
		"description": "A basic wooden blade",
		"slot": "weapon",
		"stats": {"attack": 5},
		"durability": 100,
		"max_durability": 100,
		"icon": preload("res://assets/weapon_sword_wooden.png"),
	},
	"wood_shield": {
		"id": "wood_shield",
		"name": "Wood Shield",
		"max_stack": 1,
		"type": "equipment",
		"description": "A simple shield made from bound planks",
		"slot": "offhand",
		"stats": {"defense": 3},
		"durability": 120,
		"max_durability": 120,
		"icon": preload("res://assets/box.png"),
	},
	"stone_pickaxe": {
		"id": "stone_pickaxe",
		"name": "Stone Pickaxe",
		"max_stack": 1,
		"type": "equipment",
		"description": "Useful for rough mining and gathering",
		"slot": "tool",
		"stats": {"gather_speed": 1.5},
		"durability": 140,
		"max_durability": 140,
		"icon": preload("res://assets/weapon_hammer.png"),
	},
	"bandage": {
		"id": "bandage",
		"name": "Bandage",
		"max_stack": 10,
		"type": "consumable",
		"description": "Wraps wounds and restores health",
		"effect": {"heal": 20},
		"icon": preload("res://assets/flask_green.png"),
	},
	"torch": {
		"id": "torch",
		"name": "Torch",
		"max_stack": 5,
		"type": "consumable",
		"description": "A simple light source for dark spaces",
		"effect": {"light": true},
		"icon": preload("res://assets/torch_1.png"),
	},
}


static func get_item(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		return {}

	return ITEMS[item_id].duplicate(true)
