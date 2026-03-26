extends Node

const ITEMS := {
	"wood": {
		"id": "wood",
		"name": "Wood",
		"max_stack": 99,
		"type": "resource",
		"description": "Basic building material",
		"icon": preload("res://assets/icons/kyrise/wood_01a.png"),
	},
	"stone": {
		"id": "stone",
		"name": "Stone",
		"max_stack": 99,
		"type": "resource",
		"description": "Hard building material",
		"icon": preload("res://assets/icons/kyrise/stoneblock_01a.png"),
	},
	"iron_ore": {
		"id": "iron_ore",
		"name": "Iron Ore",
		"max_stack": 99,
		"type": "resource",
		"description": "Raw metal ore",
		"icon": preload("res://assets/icons/kyrise/ingot_01a.png"),
	},
	"fiber": {
		"id": "fiber",
		"name": "Fiber",
		"max_stack": 99,
		"type": "resource",
		"description": "Plant fiber for crafting",
		"icon": preload("res://assets/icons/kyrise/cotton_01a.png"),
	},
	"seed": {
		"id": "seed",
		"name": "Seed",
		"max_stack": 99,
		"type": "resource",
		"description": "A small seed used for farming",
		"icon": preload("res://assets/icons/kyrise/flower_01a.png"),
	},
	"wheat": {
		"id": "wheat",
		"name": "Wheat",
		"max_stack": 99,
		"type": "resource",
		"description": "A harvested crop used for cooking",
		"icon": preload("res://assets/icons/kyrise/leaf_01a.png"),
	},
	"talent_shard": {
		"id": "talent_shard",
		"name": "Talent Shard",
		"max_stack": 99,
		"type": "resource",
		"description": "Used at the Talent Altar",
		"icon": preload("res://assets/icons/kyrise/shard_01a.png"),
	},
	"gold": {
		"id": "gold",
		"name": "Gold",
		"max_stack": 9999,
		"type": "resource",
		"description": "Currency for trading with merchants",
		"icon": preload("res://assets/icons/kyrise/coin_01a.png"),
	},
	"wood_sword": {
		"id": "wood_sword",
		"name": "Wood Sword",
		"max_stack": 1,
		"type": "equipment",
		"description": "A basic wooden blade",
		"slot": "weapon",
		"stats": {"attack": 5},
		"durability": 50,
		"max_durability": 50,
		"repair_material": "wood",
		"icon": preload("res://assets/icons/kyrise/sword_01a.png"),
	},
	"wood_shield": {
		"id": "wood_shield",
		"name": "Wood Shield",
		"max_stack": 1,
		"type": "equipment",
		"description": "A simple shield made from bound planks",
		"slot": "offhand",
		"stats": {"defense": 3},
		"durability": 40,
		"max_durability": 40,
		"repair_material": "wood",
		"icon": preload("res://assets/icons/kyrise/shield_01a.png"),
	},
	"stone_pickaxe": {
		"id": "stone_pickaxe",
		"name": "Stone Pickaxe",
		"max_stack": 1,
		"type": "equipment",
		"description": "Useful for rough mining and gathering",
		"slot": "tool",
		"stats": {"gather_speed": 1.5},
		"durability": 60,
		"max_durability": 60,
		"repair_material": "stone",
		"icon": preload("res://assets/icons/kyrise/ingot_01b.png"),
	},
	"leather_cap": {
		"id": "leather_cap",
		"name": "Leather Cap",
		"max_stack": 1,
		"type": "equipment",
		"description": "Light head protection made from woven fiber.",
		"slot": "helmet",
		"stats": {"defense": 2},
		"durability": 30,
		"max_durability": 30,
		"repair_material": "fiber",
		"icon": preload("res://assets/icons/kyrise/helmet_01a.png"),
	},
	"leather_vest": {
		"id": "leather_vest",
		"name": "Leather Vest",
		"max_stack": 1,
		"type": "equipment",
		"description": "A flexible vest for dungeon runs.",
		"slot": "chest_armor",
		"stats": {"defense": 4, "max_hp": 10},
		"durability": 40,
		"max_durability": 40,
		"repair_material": "fiber",
		"icon": preload("res://assets/icons/kyrise/armor_01a.png"),
	},
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"max_stack": 1,
		"type": "equipment",
		"description": "A sturdier sword for deeper dungeon floors.",
		"slot": "weapon",
		"stats": {"attack": 10},
		"durability": 80,
		"max_durability": 80,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/sword_02a.png"),
	},
	"bandage": {
		"id": "bandage",
		"name": "Bandage",
		"max_stack": 10,
		"type": "consumable",
		"description": "Wraps wounds and restores health",
		"effect": {"heal": 20},
		"icon": preload("res://assets/icons/kyrise/scroll_01a.png"),
	},
	"torch": {
		"id": "torch",
		"name": "Torch",
		"max_stack": 5,
		"type": "consumable",
		"description": "A simple light source for dark spaces",
		"effect": {"light": true},
		"icon": preload("res://assets/icons/kyrise/candle_01a.png"),
	},
	"bread": {
		"id": "bread",
		"name": "Bread",
		"max_stack": 10,
		"type": "consumable",
		"description": "Freshly baked bread that restores health",
		"effect": {"heal": 30},
		"icon": preload("res://assets/icons/kyrise/cookie_01a.png"),
	},
	"stew": {
		"id": "stew",
		"name": "Stew",
		"max_stack": 10,
		"type": "consumable",
		"description": "A hearty stew that restores a large chunk of health",
		"effect": {"heal": 50},
		"icon": preload("res://assets/icons/kyrise/cup_01a.png"),
	},
}


static func get_item(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		return {}

	return ITEMS[item_id].duplicate(true)


static func get_item_icon(item_id: String) -> Texture2D:
	var item: Dictionary = get_item(item_id)
	return get_stack_icon(item)


static func get_stack_icon(stack: Dictionary) -> Texture2D:
	if stack.is_empty():
		return null
	var icon = stack.get("icon", null)
	return icon if icon is Texture2D else null


static func get_default_equipment_icon(slot_name: String) -> Texture2D:
	match slot_name:
		"weapon":
			return preload("res://assets/icons/kyrise/sword_01a.png")
		"helmet":
			return preload("res://assets/icons/kyrise/helmet_01a.png")
		"chest_armor", "offhand":
			return preload("res://assets/icons/kyrise/armor_01a.png")
		"boots":
			return preload("res://assets/icons/kyrise/boots_01a.png")
		"accessory":
			return preload("res://assets/icons/ring_01a.png")
		"tool":
			return preload("res://assets/icons/kyrise/ingot_01b.png")
		_:
			return null


static func get_item_color(item_id: String, item_type: String = "") -> Color:
	match item_id:
		"wood":
			return Color(0.6, 0.4, 0.2, 1.0)
		"stone":
			return Color(0.5, 0.5, 0.5, 1.0)
		"iron_ore":
			return Color(0.7, 0.7, 0.8, 1.0)
		"fiber":
			return Color(0.3, 0.7, 0.3, 1.0)
		"talent_shard":
			return Color(0.6, 0.3, 0.9, 1.0)
		"seed":
			return Color(0.8, 0.7, 0.2, 1.0)
		"wheat":
			return Color(0.9, 0.8, 0.3, 1.0)
	if item_type == "":
		item_type = str(get_item(item_id).get("type", "resource"))
	match item_type:
		"equipment":
			return Color(0.3, 0.55, 0.95, 1.0)
		"consumable":
			return Color(0.32, 0.78, 0.42, 1.0)
		_:
			return Color(0.62, 0.42, 0.22, 1.0)


static func get_stack_color(stack: Dictionary) -> Color:
	var max_durability := int(stack.get("max_durability", stack.get("durability_max", 0)))
	var durability := int(stack.get("durability", stack.get("durability_current", max_durability)))
	if max_durability > 0 and durability <= 0:
		return Color(1.0, 0.3, 0.3, 1.0)
	if str(stack.get("source", "")) == "dungeon":
		var rarity := str(stack.get("rarity", "Common"))
		match rarity:
			"Uncommon":
				return Color(0.45, 0.95, 0.45, 1.0)
			"Rare":
				return Color(0.42, 0.68, 1.0, 1.0)
			"Epic":
				return Color(0.82, 0.45, 1.0, 1.0)
			_:
				return Color.WHITE
	return get_item_color(str(stack.get("id", "")), str(stack.get("type", "")))

