extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLAYER_SAVE := preload("res://scripts/player/player_save.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	PLAYER_SAVE.clear_save()
	await test_equip_item_adds_stats()
	await test_equip_item_adds_defense_hp_and_speed()
	await test_unequip_item_removes_stats()
	await test_durability_decreases_on_attack()
	await test_broken_item_halves_bonus()
	await test_repair_restores_durability()
	await test_death_penalty_reduces_durability()
	await test_equipment_save_load_preserves_state()
	await test_equipping_swaps_previous_item()
	await test_damage_reduces_armor_durability()
	await test_repair_cost_scales_with_loss()
	await test_inventory_stack_preserves_durability()
	await test_equipment_slots_expose_expected_labels()
	await test_broken_item_display_name_is_red_and_prefixed()
	PLAYER_SAVE.clear_save()
	_report_results()


func test_equip_item_adds_stats() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	var before_attack: int = player.get_attack_damage()
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	_assert(player.get_attack_damage() == before_attack + 5, "Equipping a wood sword should raise attack.")
	player.queue_free()
	await process_frame


func test_unequip_item_removes_stats() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_attack: int = player.get_attack_damage()
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.equipment_system.unequip("weapon", player.inventory)
	_assert(player.get_attack_damage() == base_attack, "Unequipping the weapon should remove its attack bonus.")
	player.queue_free()
	await process_frame


func test_equip_item_adds_defense_hp_and_speed() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_summary: Dictionary = player.get_stats_summary()
	var boots := {
		"id": "test_boots",
		"name": "Runner Boots",
		"type": "equipment",
		"slot": "boots",
		"max_stack": 1,
		"stats": {"speed": 12.0},
		"durability": 40,
		"max_durability": 40,
	}
	player.inventory.add_item("leather_vest", 1)
	player.inventory.add_stack(boots)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	var summary: Dictionary = player.get_stats_summary()
	_assert(int(summary.get("defense", 0)) >= int(base_summary.get("defense", 0)) + 4, "Chest armor should increase defense.")
	_assert(int(summary.get("max_hp", 0)) >= int(base_summary.get("max_hp", 0)) + 10, "Chest armor should increase max HP.")
	_assert(int(summary.get("speed", 0)) >= int(base_summary.get("speed", 0)) + 12, "Boots should increase speed.")
	player.queue_free()
	await process_frame


func test_durability_decreases_on_attack() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.perform_attack()
	_assert(int(player.equipment_system.get_equipped("weapon").get("durability", 0)) == 49, "Attacking should reduce weapon durability by one.")
	player.queue_free()
	await process_frame


func test_broken_item_halves_bonus() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var base_attack: int = player.get_attack_damage()
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	var item: Dictionary = player.equipment_system.get_equipped("weapon")
	item["durability"] = 0
	player.equipment_system.equip(item, "weapon")
	_assert(player.get_attack_damage() == int(round(base_attack + 2.5)), "Broken weapon should only grant half its attack bonus.")
	player.queue_free()
	await process_frame


func test_repair_restores_durability() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.inventory.add_item("iron_ore", 5)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.perform_attack()
	_assert(player.equipment_system.repair_slot("weapon", player.inventory), "Repair should succeed with enough resources.")
	_assert(int(player.equipment_system.get_equipped("weapon").get("durability", 0)) == 50, "Repair should restore the weapon to full durability.")
	player.queue_free()
	await process_frame


func test_death_penalty_reduces_durability() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("iron_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.finish_dungeon_run(false)
	_assert(int(player.equipment_system.get_equipped("weapon").get("durability", 0)) == 64, "Death should remove 20 percent of max durability.")
	player.queue_free()
	await process_frame


func test_equipment_save_load_preserves_state() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.perform_attack()
	player.queue_free()
	await process_frame
	var player_two = PLAYER_SCENE.instantiate()
	root.add_child(player_two)
	await process_frame
	_assert(int(player_two.equipment_system.get_equipped("weapon").get("durability", 0)) == 49, "Equipment save should preserve equipped durability.")
	player_two.queue_free()
	await process_frame


func test_equipping_swaps_previous_item() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.inventory.add_item("iron_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	_assert(player.inventory.get_item_count("wood_sword") == 1, "Equipping a new weapon should return the previous weapon to the bag.")
	player.queue_free()
	await process_frame


func test_damage_reduces_armor_durability() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("leather_vest", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	player.take_damage(5)
	_assert(int(player.equipment_system.get_equipped("chest_armor").get("durability", 0)) == 39, "Taking damage should reduce armor durability.")
	player.queue_free()
	await process_frame


func test_repair_cost_scales_with_loss() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	var item: Dictionary = player.equipment_system.get_equipped("weapon")
	item["durability"] = 35
	player.equipment_system.equip(item, "weapon")
	var cost: Dictionary = player.equipment_system.get_repair_cost("weapon")
	_assert(int(cost.get("iron_ore", 0)) == 2, "Weapon repair cost should scale with missing durability and use iron ore.")
	player.queue_free()
	await process_frame


func test_inventory_stack_preserves_durability() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	var item: Dictionary = player.equipment_system.get_equipped("weapon")
	item["durability"] = 12
	player.equipment_system.equip(item, "weapon")
	player.equipment_system.unequip("weapon", player.inventory)
	_assert(int(player.inventory.items[0].get("durability", 0)) == 12, "Unequipping should preserve exact durability in the bag.")
	player.queue_free()
	await process_frame


func test_equipment_slots_expose_expected_labels() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var slots: PackedStringArray = player.equipment_system.get_slot_order()
	_assert(slots.has("weapon") and slots.has("helmet") and slots.has("chest_armor") and slots.has("boots") and slots.has("accessory"), "Equipment system should expose the main character gear slots.")
	player.queue_free()
	await process_frame


func test_broken_item_display_name_is_red_and_prefixed() -> void:
	PLAYER_SAVE.clear_save()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.inventory.add_item("wood_sword", 1)
	player.equipment_system.equip_from_inventory(player.inventory, 0)
	var item: Dictionary = player.equipment_system.get_equipped("weapon")
	item["durability"] = 0
	player.equipment_system.equip(item, "weapon")
	var broken_item: Dictionary = player.equipment_system.get_equipped("weapon")
	_assert(player.equipment_system.get_item_display_name(broken_item).begins_with("(Broken) "), "Broken equipment should display a broken prefix.")
	_assert(player.equipment_system.get_item_display_color(broken_item) == Color(1.0, 0.3, 0.3, 1.0), "Broken equipment should display in red.")
	player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All equipment tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
