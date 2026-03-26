extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/inventory/inventory.gd")
const RESOURCE_SCENE := preload("res://scenes/world/resource_node.tscn")

var _failures: PackedStringArray = []
var _last_drop: Dictionary = {}


func _initialize() -> void:
	test_new_inventory_defaults()
	test_add_item_increases_count()
	test_add_item_stacks_correctly()
	test_add_item_returns_false_when_full()
	test_remove_item_decreases_quantity()
	test_remove_item_clears_slot_at_zero()
	test_remove_item_leaves_other_items_untouched()
	test_has_item_checks_quantity()
	test_get_item_count_reports_total()
	test_get_free_slots_updates()
	test_resource_node_hit_count_tracks()
	test_resource_node_gather_drop_range()
	_report_results()


func test_new_inventory_defaults() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	_assert(inventory.items.is_empty(), "New inventory should start empty.")
	_assert(inventory.get_free_slots() == 20, "New inventory should have 20 free slots.")


func test_add_item_increases_count() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	_assert(inventory.add_item("wood", 2), "Adding a valid item should succeed.")
	_assert(inventory.get_item_count("wood") == 2, "Adding items should increase the total count.")


func test_add_item_stacks_correctly() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 5)
	inventory.add_item("wood", 3)
	_assert(inventory.get_item_count("wood") == 8, "Wood count should stack to 8.")
	_assert(inventory.items.size() == 1, "Stacked wood should use one slot.")


func test_add_item_returns_false_when_full() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.max_slots = 1
	inventory.add_item("wood", 99)
	_assert(not inventory.add_item("stone", 1), "Adding a new stack when full should fail.")


func test_remove_item_decreases_quantity() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 5)
	_assert(inventory.remove_item("wood", 2), "Removing available items should succeed.")
	_assert(inventory.get_item_count("wood") == 3, "Wood count should decrease after removal.")


func test_remove_item_clears_slot_at_zero() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 1)
	inventory.remove_item("wood", 1)
	_assert(inventory.items.is_empty(), "Removing the last item should clear the slot.")


func test_remove_item_leaves_other_items_untouched() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 5)
	_assert(inventory.remove_item("wood", 2), "Removing one resource type should succeed when enough is present.")
	_assert(inventory.get_item_count("wood") == 8, "Removing wood should only reduce the wood quantity.")
	_assert(inventory.get_item_count("stone") == 5, "Removing wood should not affect stone.")


func test_has_item_checks_quantity() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("stone", 2)
	_assert(inventory.has_item("stone", 2), "Inventory should report enough stone when available.")
	_assert(not inventory.has_item("stone", 3), "Inventory should report false when quantity is too high.")


func test_get_item_count_reports_total() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("iron_ore", 4)
	_assert(inventory.get_item_count("iron_ore") == 4, "Iron ore count should match added quantity.")


func test_get_free_slots_updates() -> void:
	var inventory := INVENTORY_SCRIPT.new()
	inventory.add_item("wood", 1)
	inventory.add_item("stone", 1)
	_assert(inventory.get_free_slots() == 18, "Two occupied slots should leave 18 free slots.")


func test_resource_node_hit_count_tracks() -> void:
	var resource := RESOURCE_SCENE.instantiate()
	resource.hits_to_gather = 3
	resource.respawn_time = 0.0
	resource.hit()
	resource.hit()
	_assert(resource.current_hits == 2, "Resource node should track current hits.")
	_assert(not resource.is_depleted, "Resource should not deplete before enough hits.")


func test_resource_node_gather_drop_range() -> void:
	var resource := RESOURCE_SCENE.instantiate()
	resource.resource_id = "wood"
	resource.hits_to_gather = 1
	resource.drop_quantity_min = 2
	resource.drop_quantity_max = 4
	resource.respawn_time = 0.0
	resource.gathered.connect(_on_resource_gathered)
	resource.hit()
	_assert(resource.is_depleted, "Resource should be depleted after the final hit.")
	_assert(_last_drop["resource_id"] == "wood", "Gathered signal should report the resource id.")
	_assert(_last_drop["quantity"] >= 2 and _last_drop["quantity"] <= 4, "Gathered quantity should be inside the configured drop range.")


func _on_resource_gathered(resource_id: String, quantity: int) -> void:
	_last_drop = {
		"resource_id": resource_id,
		"quantity": quantity,
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All inventory tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)

