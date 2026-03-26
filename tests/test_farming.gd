extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OVERWORLD_SCENE := preload("res://scenes/overworld/test_overworld.tscn")
const FARM_PLOT_SCENE := preload("res://scenes/building/facilities/farm_plot.tscn")
const COOKING_BENCH_SCENE := preload("res://scenes/building/facilities/cooking_bench.tscn")
const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	await test_planting_costs_one_seed()
	await test_harvesting_gives_wheat()
	await test_growth_time_is_correct()
	await test_cooking_bread_costs_three_wheat()
	await test_bread_heals_thirty_hp()
	_report_results()


func test_planting_costs_one_seed() -> void:
	var setup := await _create_setup()
	var farm_plot = FARM_PLOT_SCENE.instantiate()
	setup.level.add_child(farm_plot)
	setup.player.inventory.add_item("seed", 2)
	farm_plot.interact(setup.player)
	_assert(setup.player.inventory.get_item_count("seed") == 1, "Planting should cost exactly 1 seed.")
	_assert(farm_plot.state != farm_plot.PlotState.EMPTY, "Planting should move the plot out of the empty state.")
	await _cleanup_setup(setup)


func test_harvesting_gives_wheat() -> void:
	var setup := await _create_setup()
	var farm_plot = FARM_PLOT_SCENE.instantiate()
	setup.level.add_child(farm_plot)
	farm_plot.state = farm_plot.PlotState.READY
	farm_plot.interact(setup.player)
	_assert(setup.player.inventory.get_item_count("wheat") >= 2, "Harvesting should award at least 2 wheat.")
	_assert(farm_plot.state == farm_plot.PlotState.EMPTY, "Harvesting should reset the plot to empty.")
	await _cleanup_setup(setup)


func test_growth_time_is_correct() -> void:
	var farm_plot = FARM_PLOT_SCENE.instantiate()
	root.add_child(farm_plot)
	await process_frame
	farm_plot.state = farm_plot.PlotState.PLANTED
	farm_plot.planted_at_unix = Time.get_unix_time_from_system() - 60.0
	farm_plot._update_growth_state()
	_assert(farm_plot.state == farm_plot.PlotState.GROWING, "A half-grown crop should be in the growing state.")
	_assert(absf(farm_plot.get_time_remaining() - 60.0) <= 1.5, "Growth time remaining should be about 60 seconds halfway through.")
	farm_plot.queue_free()
	await process_frame


func test_cooking_bread_costs_three_wheat() -> void:
	var inventory = preload("res://scripts/inventory/inventory.gd").new()
	inventory.add_item("wheat", 3)
	_assert(CRAFTING_SYSTEM.craft("bread", inventory), "Cooking bread should succeed with 3 wheat.")
	_assert(inventory.get_item_count("wheat") == 0, "Cooking bread should consume 3 wheat.")
	_assert(inventory.get_item_count("bread") == 1, "Cooking bread should add bread to the inventory.")


func test_bread_heals_thirty_hp() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.current_hp = 40
	player.inventory.add_item("bread", 1)
	player.use_first_consumable()
	_assert(player.current_hp == 70, "Bread should heal the player for 30 HP.")
	player.queue_free()
	await process_frame


func _create_setup() -> Dictionary:
	var level = OVERWORLD_SCENE.instantiate()
	var player = PLAYER_SCENE.instantiate()
	root.add_child(level)
	root.add_child(player)
	await process_frame
	player.building_system.set_active_level("overworld", level)
	level.place_player(player)
	return {
		"level": level,
		"player": player,
	}


func _cleanup_setup(setup: Dictionary) -> void:
	setup.level.queue_free()
	setup.player.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All farming tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)

