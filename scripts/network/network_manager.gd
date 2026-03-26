extends Node

signal players_changed(player_ids: Array[int])
signal connection_status_changed(status_text: String)
signal connection_failed_message(message: String)

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const LOBBY_SCENE_PATH := "res://scenes/ui/lobby.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"

var is_multiplayer: bool = false
var is_host: bool = false
var port: int = 7777
var max_players: int = 4

var _connected_player_ids: Array[int] = []
var _connection_status: String = ""
var _last_join_ip: String = "127.0.0.1"


func _ready() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	_update_status("")


func host_game() -> void:
	disconnect_game()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players)
	if error != OK:
		push_error("Failed to host game on port %d (error %d)." % [port, error])
		return
	multiplayer.multiplayer_peer = peer
	is_multiplayer = true
	is_host = true
	_set_connected_players([multiplayer.get_unique_id()])
	_update_status("Hosting on port %d | %s" % [port, get_local_ip()])
	print("Server started on port ", port)


func join_game(ip: String) -> void:
	disconnect_game()
	_last_join_ip = ip.strip_edges()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_last_join_ip, port)
	if error != OK:
		push_error("Failed to connect to %s:%d (error %d)." % [_last_join_ip, port, error])
		connection_failed_message.emit("Unable to start connection.")
		return
	multiplayer.multiplayer_peer = peer
	is_multiplayer = true
	is_host = false
	_set_connected_players([])
	_update_status("Connecting to %s:%d" % [_last_join_ip, port])
	print("Connecting to ", _last_join_ip, ":", port)


func disconnect_game() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_multiplayer = false
	is_host = false
	_set_connected_players([])
	_update_status("")


func return_to_main_menu() -> void:
	disconnect_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func show_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func start_game() -> void:
	if is_multiplayer and not is_host:
		return
	if is_multiplayer:
		_load_game_scene.rpc()
	else:
		_load_game_scene()


func get_connected_player_ids() -> Array[int]:
	return _connected_player_ids.duplicate()


func get_player_count() -> int:
	return _connected_player_ids.size()


func get_last_join_ip() -> String:
	return _last_join_ip


func get_connection_status() -> String:
	if not is_multiplayer:
		return ""
	if is_host:
		return "Hosting on port %d | %s" % [port, get_local_ip()]
	return "Connected | %d players" % max(get_player_count(), 1)


func get_local_ip() -> String:
	var fallback := "127.0.0.1"
	for address in IP.get_local_addresses():
		if "." not in address:
			continue
		if address.begins_with("127."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
		if fallback == "127.0.0.1":
			fallback = address
	return fallback


@rpc("authority", "call_local", "reliable")
func _load_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


@rpc("authority", "call_remote", "reliable")
func _sync_connected_players(player_ids: Array[int]) -> void:
	_set_connected_players(player_ids)
	_update_status("Connected | %d players" % max(player_ids.size(), 1))


func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	var next_players := get_connected_player_ids()
	if not next_players.has(id):
		next_players.append(id)
		next_players.sort()
	_set_connected_players(next_players)
	_sync_connected_players.rpc(next_players)
	print("Peer connected: ", id)


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		var next_players := get_connected_player_ids()
		next_players.erase(id)
		_set_connected_players(next_players)
		_sync_connected_players.rpc(next_players)
	print("Peer disconnected: ", id)


func _on_connected_to_server() -> void:
	is_multiplayer = true
	is_host = false
	_update_status("Connected | 1 players")


func _on_connection_failed() -> void:
	var message := "Connection failed for %s:%d" % [_last_join_ip, port]
	connection_failed_message.emit(message)
	disconnect_game()


func _on_server_disconnected() -> void:
	connection_failed_message.emit("Disconnected from host.")
	disconnect_game()


func _set_connected_players(player_ids: Array[int]) -> void:
	_connected_player_ids = player_ids.duplicate()
	_connected_player_ids.sort()
	players_changed.emit(get_connected_player_ids())


func _update_status(status_text: String) -> void:
	_connection_status = status_text
	connection_status_changed.emit(_connection_status)

