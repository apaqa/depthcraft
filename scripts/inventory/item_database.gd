extends Node

const ITEM_NAME_KEYS = {
	"wood": "item_wood_name",
	"stone": "item_stone_name",
	"iron_ore": "item_iron_ore_name",
	"fiber": "item_fiber_name",
	"seed": "item_seed_name",
	"wheat": "item_wheat_name",
	"talent_shard": "item_talent_shard_name",
	"copper": "item_copper_name",
	"silver": "item_silver_name",
	"gold": "item_gold_name",
	"wood_sword": "item_wood_sword_name",
	"wood_shield": "item_wood_shield_name",
	"stone_pickaxe": "item_stone_pickaxe_name",
	"leather_cap": "item_leather_cap_name",
	"leather_vest": "item_leather_vest_name",
	"iron_sword": "item_iron_sword_name",
	"bandage": "item_bandage_name",
	"torch": "item_torch_name",
	"bread": "item_bread_name",
	"stew": "item_stew_name",
}

const ITEM_DESC_KEYS = {
	"wood": "item_wood_desc",
	"stone": "item_stone_desc",
	"iron_ore": "item_iron_ore_desc",
	"fiber": "item_fiber_desc",
	"seed": "item_seed_desc",
	"wheat": "item_wheat_desc",
	"talent_shard": "item_talent_shard_desc",
	"copper": "item_copper_desc",
	"silver": "item_silver_desc",
	"gold": "item_gold_desc",
	"wood_sword": "item_wood_sword_desc",
	"wood_shield": "item_wood_shield_desc",
	"stone_pickaxe": "item_stone_pickaxe_desc",
	"leather_cap": "item_leather_cap_desc",
	"leather_vest": "item_leather_vest_desc",
	"iron_sword": "item_iron_sword_desc",
	"bandage": "item_bandage_desc",
	"torch": "item_torch_desc",
	"bread": "item_bread_desc",
	"stew": "item_stew_desc",
}

const ITEMS = {
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
	"copper": {
		"id": "copper",
		"name": "Copper",
		"max_stack": 9999,
		"type": "resource",
		"description": "Basic currency — 10 copper = 1 silver",
		"icon": preload("res://assets/icons/kyrise/coin_01b.png"),
	},
	"silver": {
		"id": "silver",
		"name": "Silver",
		"max_stack": 9999,
		"type": "resource",
		"description": "Mid-tier currency — 10 silver = 1 gold",
		"icon": preload("res://assets/icons/kyrise/coin_01c.png"),
	},
	"gold": {
		"id": "gold",
		"name": "Gold",
		"max_stack": 9999,
		"type": "resource",
		"description": "High-tier currency dropped by bosses",
		"icon": preload("res://assets/icons/kyrise/coin_01d.png"),
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
	"dagger": {
		"id": "dagger",
		"name": "Dagger",
		"max_stack": 1,
		"type": "equipment",
		"description": "A swift, light blade favored by rogues.",
		"slot": "weapon",
		"stats": {"attack": 7, "crit_chance": 0.05},
		"durability": 60,
		"max_durability": 60,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/sword_01b.png"),
	},
	"greatsword": {
		"id": "greatsword",
		"name": "Greatsword",
		"max_stack": 1,
		"type": "equipment",
		"description": "A massive two-handed blade dealing heavy blows.",
		"slot": "weapon",
		"stats": {"attack": 18},
		"durability": 100,
		"max_durability": 100,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/sword_03a.png"),
	},
	"wand": {
		"id": "wand",
		"name": "Wand",
		"max_stack": 1,
		"type": "equipment",
		"description": "A slender channeling rod for arcane spells.",
		"slot": "weapon",
		"stats": {"attack": 5, "spell_power": 8},
		"durability": 50,
		"max_durability": 50,
		"repair_material": "wood",
		"icon": preload("res://assets/icons/kyrise/staff_01a.png"),
	},
	"iron_staff": {
		"id": "iron_staff",
		"name": "Iron Staff",
		"max_stack": 1,
		"type": "equipment",
		"description": "A reinforced iron staff for battle mages.",
		"slot": "weapon",
		"stats": {"attack": 8, "spell_power": 12},
		"durability": 90,
		"max_durability": 90,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/staff_02ab.png"),
	},
	"shortbow": {
		"id": "shortbow",
		"name": "Shortbow",
		"max_stack": 1,
		"type": "equipment",
		"description": "A nimble bow with quick draw speed.",
		"slot": "weapon",
		"stats": {"attack": 9, "speed_multiplier": 0.03},
		"durability": 65,
		"max_durability": 65,
		"repair_material": "wood",
		"icon": preload("res://assets/icons/kyrise/bow_01a.png"),
	},
	"crossbow": {
		"id": "crossbow",
		"name": "Crossbow",
		"max_stack": 1,
		"type": "equipment",
		"description": "A mechanically-drawn bow with superior stopping power.",
		"slot": "weapon",
		"stats": {"attack": 14, "armor_penetration": 3},
		"durability": 85,
		"max_durability": 85,
		"repair_material": "wood",
		"icon": preload("res://assets/icons/kyrise/bow_02a.png"),
	},
	"iron_shield": {
		"id": "iron_shield",
		"name": "Iron Shield",
		"max_stack": 1,
		"type": "equipment",
		"description": "A solid iron shield providing reliable protection.",
		"slot": "offhand",
		"stats": {"defense": 8, "max_hp": 10},
		"durability": 90,
		"max_durability": 90,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/shield_02a.png"),
	},
	"tower_shield": {
		"id": "tower_shield",
		"name": "Tower Shield",
		"max_stack": 1,
		"type": "equipment",
		"description": "An enormous shield that doubles as a wall.",
		"slot": "offhand",
		"stats": {"defense": 14, "max_hp": 20, "speed_multiplier": -0.05},
		"durability": 120,
		"max_durability": 120,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/shield_03a.png"),
	},
	"iron_helmet": {
		"id": "iron_helmet",
		"name": "Iron Helmet",
		"max_stack": 1,
		"type": "equipment",
		"description": "A sturdy iron helm for frontline fighters.",
		"slot": "helmet",
		"stats": {"defense": 6, "max_hp": 10},
		"durability": 70,
		"max_durability": 70,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/helmet_02a.png"),
	},
	"plate_armor": {
		"id": "plate_armor",
		"name": "Plate Armor",
		"max_stack": 1,
		"type": "equipment",
		"description": "Heavy full-body plate for maximum protection.",
		"slot": "chest_armor",
		"stats": {"defense": 14, "max_hp": 25},
		"durability": 120,
		"max_durability": 120,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/armor_01b.png"),
	},
	"chain_mail": {
		"id": "chain_mail",
		"name": "Chain Mail",
		"max_stack": 1,
		"type": "equipment",
		"description": "Interlocked iron rings balancing mobility and defense.",
		"slot": "chest_armor",
		"stats": {"defense": 8, "max_hp": 15},
		"durability": 80,
		"max_durability": 80,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/armor_01c.png"),
	},
	"leather_boots": {
		"id": "leather_boots",
		"name": "Leather Boots",
		"max_stack": 1,
		"type": "equipment",
		"description": "Supple boots that keep your feet moving fast.",
		"slot": "boots",
		"stats": {"defense": 1, "speed_multiplier": 0.07},
		"durability": 40,
		"max_durability": 40,
		"repair_material": "fiber",
		"icon": preload("res://assets/icons/kyrise/boots_01a.png"),
	},
	"iron_boots": {
		"id": "iron_boots",
		"name": "Iron Boots",
		"max_stack": 1,
		"type": "equipment",
		"description": "Heavy iron boots with solid ankle protection.",
		"slot": "boots",
		"stats": {"defense": 5, "speed_multiplier": -0.02},
		"durability": 80,
		"max_durability": 80,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/boots_01b.png"),
	},
	"leather_gloves": {
		"id": "leather_gloves",
		"name": "Leather Gloves",
		"max_stack": 1,
		"type": "equipment",
		"description": "Flexible gloves granting a modest combat edge.",
		"slot": "accessory",
		"stats": {"attack": 2, "defense": 1},
		"durability": 35,
		"max_durability": 35,
		"repair_material": "fiber",
		"icon": preload("res://assets/icons/kyrise/gloves_01a.png"),
	},
	"silver_ring": {
		"id": "silver_ring",
		"name": "Silver Ring",
		"max_stack": 1,
		"type": "equipment",
		"description": "A polished ring that sharpens the wearer's reflexes.",
		"slot": "accessory",
		"stats": {"crit_chance": 0.04, "max_hp": 8},
		"durability": 50,
		"max_durability": 50,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/ring_02a.png"),
	},
	"amulet": {
		"id": "amulet",
		"name": "Amulet",
		"max_stack": 1,
		"type": "equipment",
		"description": "An ancient amulet radiating protective energy.",
		"slot": "accessory",
		"stats": {"max_hp": 30, "defense": 3},
		"durability": 60,
		"max_durability": 60,
		"repair_material": "iron_ore",
		"icon": preload("res://assets/icons/kyrise/necklace_01a.png"),
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
	"herb_tea": {
		"id": "herb_tea",
		"name": "Herb Tea",
		"max_stack": 10,
		"type": "consumable",
		"description": "A calming drink that restores a large amount of health",
		"effect": {"heal": 70},
		"icon": preload("res://assets/icons/kyrise/cup_01a.png"),
	},
}


static func get_item(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		return {}
	var item: Dictionary = ITEMS[item_id].duplicate(true)
	var name_key: String = str(ITEM_NAME_KEYS.get(item_id, ""))
	if name_key != "":
		item["name"] = LocaleManager.L(name_key)
	var description_key: String = str(ITEM_DESC_KEYS.get(item_id, ""))
	if description_key != "":
		item["description"] = LocaleManager.L(description_key)
	return item


static func get_display_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))


static func get_stack_display_name(stack: Dictionary) -> String:
	if stack.is_empty():
		return ""
	var item_id: String = str(stack.get("id", ""))
	if item_id == "":
		return str(stack.get("name", ""))
	return get_display_name(item_id)


static func get_item_icon(item_id: String) -> Texture2D:
	var item: Dictionary = get_item(item_id)
	return get_stack_icon(item)


static func get_stack_icon(stack: Dictionary) -> Texture2D:
	if stack.is_empty():
		return null
	var direct_icon: Variant = stack.get("icon", null)
	if direct_icon is Texture2D:
		return direct_icon
	var item_id: String = str(stack.get("id", ""))
	if item_id != "" and ITEMS.has(item_id):
		var item_icon: Variant = ITEMS[item_id].get("icon", null)
		if item_icon is Texture2D:
			return item_icon
	var item_type: String = str(stack.get("type", ""))
	if item_type == "" and item_id != "" and ITEMS.has(item_id):
		item_type = str(ITEMS[item_id].get("type", ""))
	if item_type == "equipment":
		var slot_name: String = str(stack.get("slot", ""))
		if slot_name == "" and item_id != "" and ITEMS.has(item_id):
			slot_name = str(ITEMS[item_id].get("slot", ""))
		var rarity: String = str(stack.get("rarity", ""))
		if rarity == "" and item_id != "" and ITEMS.has(item_id):
			rarity = str(ITEMS[item_id].get("rarity", "Common"))
		return get_equipment_icon(slot_name, rarity)
	return null


static func get_equipment_icon(slot_name: String, rarity: String = "Common") -> Texture2D:
	var normalized_rarity: String = rarity.strip_edges().to_lower()
	match slot_name:
		"weapon":
			match normalized_rarity:
				"rare", "epic":
					return preload("res://assets/icons/kyrise/sword_02a.png")
				"legendary":
					return preload("res://assets/icons/kyrise/sword_03a.png")
				_:
					return preload("res://assets/icons/kyrise/sword_01a.png")
		"helmet":
			match normalized_rarity:
				"uncommon":
					return preload("res://assets/icons/kyrise/helmet_01b.png")
				"rare":
					return preload("res://assets/icons/kyrise/helmet_01c.png")
				"epic":
					return preload("res://assets/icons/kyrise/helmet_01d.png")
				"legendary":
					return preload("res://assets/icons/kyrise/helmet_01e.png")
				_:
					return preload("res://assets/icons/kyrise/helmet_01a.png")
		"chest_armor":
			return preload("res://assets/icons/kyrise/armor_01a.png")
		"offhand":
			return preload("res://assets/icons/kyrise/shield_01a.png")
		"boots":
			return preload("res://assets/icons/kyrise/boots_01a.png")
		"accessory":
			return preload("res://assets/icons/kyrise/ring_01a.png")
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
		"copper":
			return Color(0.80, 0.50, 0.20, 1.0)
		"silver":
			return Color(0.75, 0.75, 0.80, 1.0)
		"gold":
			return Color(1.0, 0.82, 0.20, 1.0)
	if item_type == "":
		item_type = str(get_item(item_id).get("type", "resource"))
	match item_type:
		"equipment":
			return Color(0.3, 0.55, 0.95, 1.0)
		"consumable":
			return Color(0.32, 0.78, 0.42, 1.0)
		_:
			return Color(0.62, 0.42, 0.22, 1.0)


static func format_currency(copper_total: int) -> String:
	var g: int = copper_total / 100
	var s: int = (copper_total % 100) / 10
	var c: int = copper_total % 10
	var parts: Array[String] = []
	if g > 0:
		parts.append("%d%s" % [g, LocaleManager.L("currency_gold")])
	if s > 0:
		parts.append("%d%s" % [s, LocaleManager.L("currency_silver")])
	if c > 0:
		parts.append("%d%s" % [c, LocaleManager.L("currency_copper")])
	if parts.is_empty():
		return "0%s" % LocaleManager.L("currency_copper")
	return " ".join(parts)


static func get_equipment_rarity_color(rarity: String = "Common") -> Color:
	var normalized: String = rarity.strip_edges().to_lower()
	match normalized:
		"uncommon":
			return Color(0.0, 0.8, 0.0, 1.0)
		"rare":
			return Color(0.0, 0.4, 1.0, 1.0)
		"epic":
			return Color(0.6, 0.0, 0.8, 1.0)
		"legendary":
			return Color(1.0, 0.5, 0.0, 1.0)
		_:
			return Color(0.8, 0.8, 0.8, 1.0)


static func get_stack_color(stack: Dictionary) -> Color:
	var max_durability: int = int(stack.get("max_durability", stack.get("durability_max", 0)))
	var durability: int = int(stack.get("durability", stack.get("durability_current", max_durability)))
	if max_durability > 0 and durability <= 0:
		return Color(1.0, 0.3, 0.3, 1.0)
	var item_type: String = str(stack.get("type", ""))
	if item_type == "":
		var item_id: String = str(stack.get("id", ""))
		if item_id != "" and ITEMS.has(item_id):
			item_type = str(ITEMS[item_id].get("type", ""))
	if item_type == "equipment":
		var rarity: String = str(stack.get("rarity", "Common"))
		return get_equipment_rarity_color(rarity)
	return get_item_color(str(stack.get("id", "")), str(stack.get("type", "")))
