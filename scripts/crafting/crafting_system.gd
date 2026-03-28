extends Node
class_name CraftingSystem

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")

const RECIPES = {
	"wood_sword": {
		"id": "wood_sword",
		"name": "Wood Sword",
		"category": "Weapons",
		"result_item_id": "wood_sword",
		"result_type": "equipment",
		"cost": {"wood": 5},
		"stats": {"attack": 5},
		"slot": "weapon",
	},
	"wood_shield": {
		"id": "wood_shield",
		"name": "Wood Shield",
		"category": "Armor",
		"result_item_id": "wood_shield",
		"result_type": "equipment",
		"cost": {"wood": 4, "fiber": 2},
		"stats": {"defense": 3},
		"slot": "offhand",
	},
	"stone_pickaxe": {
		"id": "stone_pickaxe",
		"name": "Stone Pickaxe",
		"category": "Tools",
		"result_item_id": "stone_pickaxe",
		"result_type": "equipment",
		"cost": {"stone": 3, "wood": 2},
		"stats": {"gather_speed": 1.5},
		"slot": "tool",
	},
	"bandage": {
		"id": "bandage",
		"name": "Bandage",
		"category": "Consumables",
		"result_item_id": "bandage",
		"result_type": "consumable",
		"cost": {"fiber": 3},
		"effect": {"heal": 20},
		"max_stack": 10,
	},
	"torch": {
		"id": "torch",
		"name": "Torch",
		"category": "Consumables",
		"result_item_id": "torch",
		"result_type": "consumable",
		"cost": {"wood": 1, "fiber": 1},
		"effect": {"light": true},
		"max_stack": 5,
	},
	"bread": {
		"id": "bread",
		"name": "Bread",
		"category": "Cooking",
		"result_item_id": "bread",
		"result_type": "consumable",
		"cost": {"wheat": 3},
		"effect": {"heal": 30},
		"max_stack": 10,
		"station": "cooking",
	},
	"stew": {
		"id": "stew",
		"name": "Stew",
		"category": "Cooking",
		"result_item_id": "stew",
		"result_type": "consumable",
		"cost": {"wheat": 2, "fiber": 1},
		"effect": {"heal": 50},
		"max_stack": 10,
		"station": "cooking",
	},
	"herb_tea": {
		"id": "herb_tea",
		"name": "Herb Tea",
		"category": "Cooking",
		"result_item_id": "herb_tea",
		"result_type": "consumable",
		"cost": {"wheat": 1, "fiber": 2},
		"effect": {"heal": 70},
		"max_stack": 10,
		"station": "cooking",
	},
	"grilled_fish": {
		"id": "grilled_fish",
		"name": "Grilled Fish",
		"category": "Cooking",
		"result_item_id": "grilled_fish",
		"result_type": "consumable",
		"cost": {"raw_fish": 1, "salt": 1},
		"effect": {"heal": 20, "meal_buff": {"damage_multiplier": 0.10}},
		"max_stack": 5,
		"station": "cooking",
	},
	"meat_stew": {
		"id": "meat_stew",
		"name": "Meat Stew",
		"category": "Cooking",
		"result_item_id": "meat_stew",
		"result_type": "consumable",
		"cost": {"raw_meat": 1, "wheat": 1, "salt": 1},
		"effect": {"heal": 25, "meal_buff": {"armor_reduction": 0.10}},
		"max_stack": 5,
		"station": "cooking",
	},
	"fruit_salad": {
		"id": "fruit_salad",
		"name": "Fruit Salad",
		"category": "Cooking",
		"result_item_id": "fruit_salad",
		"result_type": "consumable",
		"cost": {"fruit": 2},
		"effect": {"heal": 15, "meal_buff": {"move_speed_multiplier": 0.15}},
		"max_stack": 5,
		"station": "cooking",
	},
	"spiced_bread": {
		"id": "spiced_bread",
		"name": "Spiced Bread",
		"category": "Cooking",
		"result_item_id": "spiced_bread",
		"result_type": "consumable",
		"cost": {"wheat": 2, "salt": 1},
		"effect": {"heal": 40, "meal_buff": {"bonus_max_hp": 15}},
		"max_stack": 5,
		"station": "cooking",
	},
	"fish_soup": {
		"id": "fish_soup",
		"name": "Fish Soup",
		"category": "Cooking",
		"result_item_id": "fish_soup",
		"result_type": "consumable",
		"cost": {"raw_fish": 1, "wheat": 1},
		"effect": {"heal": 60, "meal_buff": {"buff_regen_amount": 2}},
		"max_stack": 5,
		"station": "cooking",
	},
	"warrior_meal": {
		"id": "warrior_meal",
		"name": "Warrior's Meal",
		"category": "Cooking",
		"result_item_id": "warrior_meal",
		"result_type": "consumable",
		"cost": {"raw_meat": 1, "raw_fish": 1, "salt": 1},
		"effect": {"heal": 30, "meal_buff": {"damage_multiplier": 0.10, "armor_reduction": 0.08}},
		"max_stack": 3,
		"station": "cooking",
	},
	"energy_brew": {
		"id": "energy_brew",
		"name": "Energy Brew",
		"category": "Cooking",
		"result_item_id": "energy_brew",
		"result_type": "consumable",
		"cost": {"fruit": 1, "fiber": 1},
		"effect": {"heal": 10, "meal_buff": {"attack_cooldown_multiplier": -0.15}},
		"max_stack": 5,
		"station": "cooking",
	},
	"leather_cap": {
		"id": "leather_cap",
		"name": "Leather Cap",
		"category": "Armor",
		"result_item_id": "leather_cap",
		"result_type": "equipment",
		"cost": {"fiber": 3},
		"stats": {"defense": 2},
		"slot": "helmet",
	},
	"leather_vest": {
		"id": "leather_vest",
		"name": "Leather Vest",
		"category": "Armor",
		"result_item_id": "leather_vest",
		"result_type": "equipment",
		"cost": {"fiber": 5, "wood": 2},
		"stats": {"defense": 4},
		"slot": "chest_armor",
	},
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"category": "Weapons",
		"result_item_id": "iron_sword",
		"result_type": "equipment",
		"cost": {"iron_ore": 5, "wood": 2},
		"stats": {"attack": 10},
		"slot": "weapon",
	},
	"iron_shield": {
		"id": "iron_shield",
		"name": "Iron Shield",
		"category": "Armor",
		"result_item_id": "iron_shield",
		"result_type": "equipment",
		"cost": {"iron_ore": 5, "wood": 2},
		"stats": {"defense": 8, "max_hp": 10},
		"slot": "offhand",
	},
}


static func get_available_recipes() -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	for recipe_id in RECIPES.keys():
		recipes.append(get_recipe(recipe_id))
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return recipes


static func get_available_recipes_for_ids(recipe_ids: PackedStringArray) -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	for recipe_id in recipe_ids:
		var recipe: Dictionary = get_recipe(recipe_id)
		if not recipe.is_empty():
			recipes.append(recipe)
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return recipes


static func get_recipe(recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	var recipe: Dictionary = RECIPES[recipe_id].duplicate(true)
	var result_item_id: String = str(recipe.get("result_item_id", ""))
	if result_item_id != "":
		recipe["name"] = ITEM_DATABASE.get_display_name(result_item_id)
	return recipe


static func get_recipe_cost(recipe_id: String, cost_multiplier: float = 1.0) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return {}
	var adjusted_cost: Dictionary = {}
	for resource_id in recipe.get("cost", {}).keys():
		var base_cost: int = int(recipe["cost"][resource_id])
		adjusted_cost[resource_id] = max(int(ceil(float(base_cost) * cost_multiplier)), 1)
	return adjusted_cost


static func can_craft(recipe_id: String, inventory, cost_multiplier: float = 1.0) -> bool:
	if inventory == null:
		return false

	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return false

	for resource_id in get_recipe_cost(recipe_id, cost_multiplier).keys():
		if inventory.get_item_count(resource_id) < int(get_recipe_cost(recipe_id, cost_multiplier)[resource_id]):
			return false
	return true


static func craft(recipe_id: String, inventory, cost_multiplier: float = 1.0) -> bool:
	if not can_craft(recipe_id, inventory, cost_multiplier):
		return false

	var recipe: Dictionary = get_recipe(recipe_id)
	for resource_id in get_recipe_cost(recipe_id, cost_multiplier).keys():
		inventory.remove_item(resource_id, int(get_recipe_cost(recipe_id, cost_multiplier)[resource_id]))

	var crafted: bool = inventory.add_item(str(recipe["result_item_id"]), 1)
	if crafted:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			var achievement_manager: Node = tree.root.get_node_or_null("/root/AchievementManager")
			if achievement_manager != null:
				achievement_manager.record_recipe_crafted(recipe)
	return crafted

