extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	var npc_manager: Node = root.get_node("/root/NpcManager")
	npc_manager.call("clear_state")
	npc_manager.call("set_current_day", 3)

	var overworld_scene: PackedScene = load("res://scenes/overworld/test_overworld.tscn") as PackedScene
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var world_npc_container: Node = overworld.get_node("WorldNpcContainer")
	_assert(world_npc_container.get_child_count() > 0, "Overworld should spawn recruitable village NPCs.")

	npc_manager.call("recruit_npc", {
		"id": "npc_farmer_test",
		"name": "阿洛1",
		"role": "farmer",
		"portrait_path": "res://assets/npc_dwarf.png",
	})
	await process_frame

	var recruited_npc_container: Node = overworld.get_node("RecruitedNpcContainer")
	_assert(recruited_npc_container.get_child_count() == 1, "Recruiting an NPC should spawn them near the home anchor.")

	npc_manager.call("recruit_npc", {
		"id": "npc_assistant_test",
		"name": "米菈2",
		"role": "merchant_assistant",
		"portrait_path": "res://assets/npc_merchant.png",
	})
	npc_manager.call("recruit_npc", {
		"id": "npc_blacksmith_test",
		"name": "拓恩3",
		"role": "blacksmith",
		"portrait_path": "res://assets/npc_paladin.png",
	})
	npc_manager.call("recruit_npc", {
		"id": "npc_guard_test",
		"name": "賽娜4",
		"role": "guard",
		"portrait_path": "res://assets/npc_knight_blue.png",
	})
	npc_manager.call("recruit_npc", {
		"id": "npc_explorer_test",
		"name": "魯卡5",
		"role": "explorer",
		"portrait_path": "res://assets/npc_elf.png",
	})
	await process_frame

	_assert(is_equal_approx(float(npc_manager.call("get_merchant_price_multiplier")), 0.9), "Merchant assistant should apply a 10% discount.")
	_assert(int(npc_manager.call("get_merchant_stock_bonus")) == 1, "Merchant assistant should add merchant stock.")
	_assert(is_equal_approx(float(npc_manager.call("get_repair_cost_multiplier")), 0.5), "Blacksmith should halve repair costs.")
	_assert(int(npc_manager.call("get_guard_damage_per_volley")) > 0, "Guard should contribute raid damage.")

	var portal: Node = overworld.get_node("ReturnPortal")
	_assert(portal.has_method("secondary_interact"), "Dungeon portal should support explorer intel interaction.")
	_assert(str(portal.call("get_interaction_prompt")).contains("[F]"), "Explorer intel prompt should appear on the dungeon portal.")

	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame

	_report_results()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("NPC recruitment test passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("NPC recruitment test failed.")
	quit(1)
