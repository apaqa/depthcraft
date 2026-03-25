extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const NETWORK_MANAGER_SCRIPT := preload("res://scripts/network/network_manager.gd")
const PLAYER_SPAWNER_SCRIPT := preload("res://scripts/network/player_spawner.gd")

var _failures: PackedStringArray = []
var _network_manager = null


func _initialize() -> void:
	_network_manager = NETWORK_MANAGER_SCRIPT.new()
	root.add_child(_network_manager)
	await process_frame
	test_network_manager_defaults_to_single_player()
	await test_network_manager_host_game_sets_host_flag()
	await test_player_spawner_tracks_spawned_players()
	await test_single_player_main_scene_works_without_network_peer()
	await test_main_menu_buttons_exist_and_are_clickable()
	await test_join_menu_reveals_ip_input()
	_report_results()


func test_network_manager_defaults_to_single_player() -> void:
	_network_manager.disconnect_game()
	_assert(not _network_manager.is_multiplayer, "NetworkManager should default to non-multiplayer mode.")


func test_network_manager_host_game_sets_host_flag() -> void:
	_network_manager.port = 7781
	_network_manager.host_game()
	await process_frame
	_assert(_network_manager.is_host, "Hosting should mark NetworkManager as host.")
	_assert(_network_manager.is_multiplayer, "Hosting should enable multiplayer mode.")
	_assert(_network_manager.get_connected_player_ids().has(1), "Hosting should register the host as player 1.")
	_network_manager.disconnect_game()
	await process_frame


func test_player_spawner_tracks_spawned_players() -> void:
	var spawner = PLAYER_SPAWNER_SCRIPT.new()
	root.add_child(spawner)
	await process_frame
	spawner.spawn_player(1, Vector2(16, 16))
	spawner.spawn_player(2, Vector2(32, 16))
	_assert(spawner.get_player(1) != null, "PlayerSpawner should return the spawned host player.")
	_assert(spawner.get_player_ids().size() == 2, "PlayerSpawner should track both spawned players.")
	spawner.despawn_player(2)
	await process_frame
	_assert(spawner.get_player(2) == null, "PlayerSpawner should remove despawned players.")
	spawner.queue_free()
	await process_frame


func test_single_player_main_scene_works_without_network_peer() -> void:
	_network_manager.disconnect_game()
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	_assert(main.player != null, "Main scene should still spawn a local player in single-player mode.")
	_assert(main.current_level_id == "overworld", "Single-player should start in the overworld.")
	main.queue_free()
	await process_frame


func test_main_menu_buttons_exist_and_are_clickable() -> void:
	var menu = MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	_assert(menu.get_node("Panel/MarginContainer/VBoxContainer/SinglePlayerButton") is Button, "Main menu should expose a Single Player button.")
	_assert(menu.get_node("Panel/MarginContainer/VBoxContainer/HostGameButton") is Button, "Main menu should expose a Host Game button.")
	_assert(menu.get_node("Panel/MarginContainer/VBoxContainer/JoinGameButton") is Button, "Main menu should expose a Join Game button.")
	_assert(menu.get_node("Panel/MarginContainer/VBoxContainer/QuitButton") is Button, "Main menu should expose a Quit button.")
	_assert(not menu.get_node("Panel/MarginContainer/VBoxContainer/SinglePlayerButton").disabled, "Main menu buttons should be clickable.")
	menu.queue_free()
	await process_frame


func test_join_menu_reveals_ip_input() -> void:
	var menu = MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	var join_button: Button = menu.get_node("Panel/MarginContainer/VBoxContainer/JoinGameButton")
	join_button.pressed.emit()
	await process_frame
	_assert(menu.get_node("Panel/MarginContainer/VBoxContainer/JoinPanel").visible, "Join Game should reveal the connection form.")
	menu.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	_network_manager.disconnect_game()
	_network_manager.queue_free()
	if _failures.is_empty():
		print("All network tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
