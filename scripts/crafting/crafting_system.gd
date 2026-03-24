extends Node
class_name CraftingSystem

const RECIPES := {
	"wood_sword": {
		"id": "wood_sword",
		"name": "Wood Sword",
		"result_item_id": "wood_sword",
		"result_type": "equipment",
		"cost": {"wood": 5},
		"stats": {"attack": 5},
		"slot": "weapon",
	},
	"wood_shield": {
		"id": "wood_shield",
		"name": "Wood Shield",
		"result_item_id": "wood_shield",
		"result_type": "equipment",
		"cost": {"wood": 4, "fiber": 2},
		"stats": {"defense": 3},
		"slot": "offhand",
	},
	"stone_pickaxe": {
		"id": "stone_pickaxe",
		"name": "Stone Pickaxe",
		"result_item_id": "stone_pickaxe",
		"result_type": "equipment",
		"cost": {"stone": 3, "wood": 2},
		"stats": {"gather_speed": 1.5},
		"slot": "tool",
	},
	"bandage": {
		"id": "bandage",
		"name": "Bandage",
		"result_item_id": "bandage",
		"result_type": "consumable",
		"cost": {"fiber": 3},
		"effect": {"heal": 20},
		"max_stack": 10,
	},
	"torch": {
		"id": "torch",
		"name": "Torch",
		"result_item_id": "torch",
		"result_type": "consumable",
		"cost": {"wood": 1, "fiber": 1},
		"effect": {"light": true},
		"max_stack": 5,
	},
}


static func get_available_recipes() -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	for recipe_id in RECIPES.keys():
		recipes.append(get_recipe(recipe_id))
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return recipes


static func get_recipe(recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	return RECIPES[recipe_id].duplicate(true)


static func can_craft(recipe_id: String, inventory) -> bool:
	if inventory == null:
		return false

	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return false

	for resource_id in recipe.get("cost", {}).keys():
		if inventory.get_item_count(resource_id) < int(recipe["cost"][resource_id]):
			return false
	return true


static func craft(recipe_id: String, inventory) -> bool:
	if not can_craft(recipe_id, inventory):
		return false

	var recipe := get_recipe(recipe_id)
	for resource_id in recipe["cost"].keys():
		inventory.remove_item(resource_id, int(recipe["cost"][resource_id]))

	return inventory.add_item(str(recipe["result_item_id"]), 1)
