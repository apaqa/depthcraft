extends SceneTree

const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")
const INVENTORY_SCRIPT := preload("res://scripts/inventory/inventory.gd")
const STORAGE_CHEST_SCENE := preload("res://scenes/building/facilities/storage_chest.tscn")
const GRASS_SCENE := preload("res://scenes/world/grass_node.tscn")
const BUILDING_SAVE := preload("res://scripts/building/building_save.gd")

var _failures: PackedStringArray = []
var _gathered_drop: Dictionary = {}


func _initialize() -> void:
	BUILDING_SAVE.clear_save()
	test_available_recipes()
	test_can_craft_true()
	test_can_craft_false()
	test_craft_deducts_resources()
	test_craft_adds_result()
	test_wood_sword_stats_present()
	await test_storage_chest_has_separate_inventory()
	await test_transfer_to_chest()
	await test_transfer_to_player()
	test_facility_save_load_preserves_type_position_and_contents()
	await test_fiber_resource_can_be_gathered()
	BUILDING_SAVE.clear_save()
	_report_results()


func test_available_recipes() -> void:
	_assert(CRAFTING_SYSTEM.get_available_recipes().size() >= 5, "Crafting should expose the Phase 4 recipes.")


func test_can_craft_true() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 5)
	_assert(CRAFTING_SYSTEM.can_craft("wood_sword", inventory), "Wood sword should be craftable with 5 wood.")


func test_can_craft_false() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 4)
	_assert(not CRAFTING_SYSTEM.can_craft("wood_sword", inventory), "Wood sword should fail without enough wood.")


func test_craft_deducts_resources() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("stone", 3)
	inventory.add_item("wood", 2)
	_assert(CRAFTING_SYSTEM.craft("stone_pickaxe", inventory), "Stone pickaxe should craft successfully.")
	_assert(inventory.get_item_count("stone") == 0, "Crafting should deduct the required stone.")
	_assert(inventory.get_item_count("wood") == 0, "Crafting should deduct the required wood.")


func test_craft_adds_result() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("fiber", 3)
	_assert(CRAFTING_SYSTEM.craft("bandage", inventory), "Bandage should craft successfully.")
	_assert(inventory.get_item_count("bandage") == 1, "Crafting should add the crafted result item.")


func test_wood_sword_stats_present() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 5)
	_assert(CRAFTING_SYSTEM.craft("wood_sword", inventory), "Wood sword should craft successfully.")
	var crafted_stack: Dictionary = inventory.items[0]
	_assert(int(crafted_stack.get("stats", {}).get("attack", 0)) == 5, "Crafted wood sword should carry its attack stat.")


func test_facility_save_load_preserves_type_position_and_contents() -> void:
	BUILDING_SAVE.save_buildings({}, Vector2.ZERO, [{
		"id": "storage_chest",
		"position": [4, 6],
		"data": {
			"inventory_items": [{
				"id": "wood",
				"name": "Wood",
				"quantity": 7,
				"max_stack": 99,
				"type": "resource",
			}],
		},
	}])
	var loaded: Dictionary = BUILDING_SAVE.load_buildings()
	var facilities: Array = loaded.get("facilities", [])
	_assert(facilities.size() == 1, "Facility save data should persist.")
	_assert(str(facilities[0]["id"]) == "storage_chest", "Facility save should preserve the facility type.")
	_assert(int(facilities[0]["position"][0]) == 4 and int(facilities[0]["position"][1]) == 6, "Facility save should preserve the position.")
	_assert(int(facilities[0]["data"]["inventory_items"][0]["quantity"]) == 7, "Facility save should preserve chest contents.")


func test_storage_chest_has_separate_inventory() -> void:
	var chest = STORAGE_CHEST_SCENE.instantiate()
	var player_inventory := INVENTORY_SCRIPT.new()
	root.add_child(chest)
	await process_frame
	player_inventory.add_item("wood", 2)
	chest.inventory.add_item("stone", 4)
	_assert(player_inventory.get_item_count("wood") == 2, "Player inventory should retain its own contents.")
	_assert(chest.inventory.get_item_count("stone") == 4, "Storage chest should keep separate contents.")
	chest.queue_free()
	await process_frame


func test_transfer_to_chest() -> void:
	var chest = STORAGE_CHEST_SCENE.instantiate()
	var player_inventory := INVENTORY_SCRIPT.new()
	root.add_child(chest)
	await process_frame
	player_inventory.add_item("wood", 5)
	_assert(player_inventory.move_stack_to(chest.inventory, 0), "Moving a stack into the chest should succeed.")
	_assert(player_inventory.get_item_count("wood") == 0, "Transferred stack should leave the player inventory.")
	_assert(chest.inventory.get_item_count("wood") == 5, "Transferred stack should appear in the chest.")
	chest.queue_free()
	await process_frame


func test_transfer_to_player() -> void:
	var chest = STORAGE_CHEST_SCENE.instantiate()
	var player_inventory := INVENTORY_SCRIPT.new()
	root.add_child(chest)
	await process_frame
	chest.inventory.add_item("stone", 3)
	_assert(chest.inventory.move_stack_to(player_inventory, 0), "Moving a stack back to the player should succeed.")
	_assert(chest.inventory.get_item_count("stone") == 0, "Transferred stack should leave the chest inventory.")
	_assert(player_inventory.get_item_count("stone") == 3, "Transferred stack should appear in the player inventory.")
	chest.queue_free()
	await process_frame


func test_fiber_resource_can_be_gathered() -> void:
	var grass = GRASS_SCENE.instantiate()
	root.add_child(grass)
	await process_frame
	_gathered_drop.clear()
	grass.gathered.connect(_on_grass_gathered)
	grass.hit()
	_assert(_gathered_drop.get("resource_id", "") == "fiber", "Grass should gather fiber.")
	_assert(int(_gathered_drop.get("quantity", 0)) >= 1, "Grass should drop at least one fiber.")
	grass.queue_free()
	await process_frame


func _on_grass_gathered(resource_id: String, quantity: int) -> void:
	_gathered_drop = {
		"resource_id": resource_id,
		"quantity": quantity,
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All crafting tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
