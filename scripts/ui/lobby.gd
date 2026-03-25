extends Control

@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var players_label: Label = $Panel/MarginContainer/VBoxContainer/PlayersLabel
@onready var player_list: ItemList = $Panel/MarginContainer/VBoxContainer/PlayerList
@onready var start_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/StartButton
@onready var leave_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/LeaveButton


func _ready() -> void:
	var network_manager = _get_network_manager()
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not leave_button.pressed.is_connected(_on_leave_pressed):
		leave_button.pressed.connect(_on_leave_pressed)
	if network_manager != null and not network_manager.players_changed.is_connected(_refresh_players):
		network_manager.players_changed.connect(_refresh_players)
	if network_manager != null and not network_manager.connection_status_changed.is_connected(_on_connection_status_changed):
		network_manager.connection_status_changed.connect(_on_connection_status_changed)
	if network_manager != null and not network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.connect(_on_connection_failed_message)
	start_button.visible = network_manager != null and network_manager.is_host
	_refresh_players(network_manager.get_connected_player_ids() if network_manager != null else [])
	_on_connection_status_changed(network_manager.get_connection_status() if network_manager != null else "")


func _exit_tree() -> void:
	var network_manager = _get_network_manager()
	if network_manager != null and network_manager.players_changed.is_connected(_refresh_players):
		network_manager.players_changed.disconnect(_refresh_players)
	if network_manager != null and network_manager.connection_status_changed.is_connected(_on_connection_status_changed):
		network_manager.connection_status_changed.disconnect(_on_connection_status_changed)
	if network_manager != null and network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.disconnect(_on_connection_failed_message)


func _refresh_players(player_ids: Array[int]) -> void:
	player_list.clear()
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var network_manager = _get_network_manager()
	if player_ids.is_empty() and network_manager != null and network_manager.is_multiplayer and not network_manager.is_host:
		player_list.add_item("Waiting for host...")
	else:
		for peer_id in player_ids:
			var label := "Player %d" % peer_id
			if network_manager != null and network_manager.is_host and peer_id == 1:
				label += " (Host)"
			elif peer_id == local_peer_id:
				label += " (You)"
			player_list.add_item(label)
	players_label.text = "Players: %d" % max(player_ids.size(), 1 if network_manager != null and network_manager.is_multiplayer else 0)


func _on_connection_status_changed(status_text: String) -> void:
	status_label.text = "Waiting for players..." if status_text.is_empty() else status_text


func _on_connection_failed_message(message: String) -> void:
	status_label.text = message


func _on_start_pressed() -> void:
	var network_manager = _get_network_manager()
	if network_manager != null:
		network_manager.start_game()


func _on_leave_pressed() -> void:
	var network_manager = _get_network_manager()
	if network_manager != null:
		network_manager.return_to_main_menu()


func _get_network_manager():
	return get_node_or_null("/root/NetworkManager")
