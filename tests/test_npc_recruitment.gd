extends SceneTree

var _failures: PackedStringArray = []


class FakeInventory extends RefCounted:
	var items: Dictionary = {}

	func add_item(item_id: String, quantity: int) -> bool:
		if quantity <= 0:
			return true
		items[item_id] = int(items.get(item_id, 0)) + quantity
		return true

	func get_item_count(item_id: String) -> int:
		return int(items.get(item_id, 0))


class FakePlayer extends Node:
	var inventory: FakeInventory = FakeInventory.new()
	var applied_buffs: Array[String] = []

	func apply_buff(buff_id: String) -> void:
		applied_buffs.append(buff_id)


func _initialize() -> void:
	var npc_manager: Node = root.get_node("/root/NpcManager")
	npc_manager.call("clear_state")
	await test_overworld_population_and_role_bonuses(npc_manager)
	test_npc_state_round_trip(npc_manager)
	await test_daily_role_support(npc_manager)
	test_clear_state_resets_runtime(npc_manager)
	npc_manager.call("clear_state")
	_report_results()


func test_overworld_population_and_role_bonuses(npc_manager: Node) -> void:
	npc_manager.call("clear_state")
	npc_manager.call("set_current_day", 3)

	var overworld_scene: PackedScene = load("res://scenes/overworld/test_overworld.tscn") as PackedScene
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var world_npc_container: Node = overworld.get_node("WorldNpcContainer")
	_assert(world_npc_container.get_child_count() > 0, "Overworld should spawn recruitable village NPCs.")

	npc_manager.call("recruit_npc", _make_npc_entry("npc_farmer_test", "阿洛1", "farmer", "res://assets/npc_dwarf.png"))
	await process_frame

	var recruited_npc_container: Node = overworld.get_node("RecruitedNpcContainer")
	_assert(recruited_npc_container.get_child_count() == 1, "Recruiting an NPC should spawn them near the home anchor.")

	npc_manager.call("recruit_npc", _make_npc_entry("npc_assistant_test", "米菈2", "merchant_assistant", "res://assets/npc_merchant.png"))
	npc_manager.call("recruit_npc", _make_npc_entry("npc_blacksmith_test", "拓恩3", "blacksmith", "res://assets/npc_paladin.png"))
	npc_manager.call("recruit_npc", _make_npc_entry("npc_guard_test", "賽娜4", "guard", "res://assets/npc_knight_blue.png"))
	npc_manager.call("recruit_npc", _make_npc_entry("npc_explorer_test", "魯卡5", "explorer", "res://assets/npc_elf.png"))
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
	current_scene = null
	await process_frame


func test_npc_state_round_trip(npc_manager: Node) -> void:
	npc_manager.call("clear_state")
	npc_manager.call("set_current_day", 7)
	npc_manager.call("recruit_npc", _make_npc_entry("npc_guard_round_trip", "羅恩6", "guard", "res://assets/npc_knight_green.png"))
	npc_manager.call("recruit_npc", _make_npc_entry("npc_blacksmith_round_trip", "維拉7", "blacksmith", "res://assets/npc_knight_yellow.png"))

	var saved_state_variant: Variant = npc_manager.call("serialize_state")
	var saved_state: Dictionary = saved_state_variant as Dictionary if saved_state_variant is Dictionary else {}

	npc_manager.call("clear_state")
	npc_manager.call("restore_state", saved_state)

	_assert(int(npc_manager.call("get_recruited_count")) == 2, "NpcManager save state should restore the recruited roster.")
	_assert(int(npc_manager.call("get_role_count", "guard")) == 1, "Restored NPC state should preserve guard roles.")
	_assert(int(npc_manager.call("get_role_count", "blacksmith")) == 1, "Restored NPC state should preserve blacksmith roles.")


func test_daily_role_support(npc_manager: Node) -> void:
	npc_manager.call("clear_state")
	npc_manager.call("restore_state", {
		"recruited_npcs": [
			_make_npc_entry("npc_farmer_daily", "阿洛1", "farmer", "res://assets/npc_dwarf.png"),
			_make_npc_entry("npc_explorer_daily", "魯卡5", "explorer", "res://assets/npc_elf.png"),
		],
		"current_day": 4,
		"last_processed_day": 4,
		"last_claimed_explorer_day": 0,
	})

	var fake_player: FakePlayer = FakePlayer.new()
	var messages_variant: Variant = npc_manager.call("process_new_day", 5, fake_player)
	var messages: Array = messages_variant as Array if messages_variant is Array else []
	var harvested_wheat: int = fake_player.inventory.get_item_count("wheat")
	_assert(harvested_wheat >= 1 and harvested_wheat <= 3, "Farmer should harvest 1-3 wheat each new day.")
	_assert(not messages.is_empty(), "Farmer daily harvest should produce a status message.")

	var first_intel_variant: Variant = npc_manager.call("claim_explorer_intel", fake_player, 5)
	var first_intel: Dictionary = first_intel_variant as Dictionary if first_intel_variant is Dictionary else {}
	_assert(not first_intel.is_empty(), "Explorer should provide one piece of intel each day.")
	if str(first_intel.get("type", "")) == "buff":
		_assert(fake_player.applied_buffs.size() == 1, "Explorer buff intel should apply a buff to the player.")

	var second_intel_variant: Variant = npc_manager.call("claim_explorer_intel", fake_player, 5)
	var second_intel: Dictionary = second_intel_variant as Dictionary if second_intel_variant is Dictionary else {}
	_assert(str(second_intel.get("type", "")) == "empty", "Explorer intel should only be claimable once per day.")


func test_clear_state_resets_runtime(npc_manager: Node) -> void:
	npc_manager.call("clear_state")
	_assert(int(npc_manager.call("get_recruited_count")) == 0, "Clearing NPC state should remove all recruited NPCs.")
	_assert(not bool(npc_manager.call("has_available_explorer_intel", 1)), "Clearing NPC state should remove explorer intel availability.")


func _make_npc_entry(npc_id: String, npc_name: String, role: String, portrait_path: String) -> Dictionary:
	return {
		"id": npc_id,
		"name": npc_name,
		"role": role,
		"portrait_path": portrait_path,
		"recruited": true,
	}


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
