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
}


static func get_item(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		return {}

	return ITEMS[item_id].duplicate()
