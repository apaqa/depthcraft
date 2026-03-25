extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var single_player_button: Button = $Panel/MarginContainer/VBoxContainer/SinglePlayerButton
@onready var host_game_button: Button = $Panel/MarginContainer/VBoxContainer/HostGameButton
@onready var join_game_button: Button = $Panel/MarginContainer/VBoxContainer/JoinGameButton
@onready var join_panel: VBoxContainer = $Panel/MarginContainer/VBoxContainer/JoinPanel
@onready var ip_input: LineEdit = $Panel/MarginContainer/VBoxContainer/JoinPanel/IPInput
@onready var connect_button: Button = $Panel/MarginContainer/VBoxContainer/JoinPanel/ConnectButton
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	title_label.text = "深淵工坊 DepthCraft"
	join_panel.visible = false
	ip_input.text = _get_network_manager().get_last_join_ip() if _get_network_manager() != null else "127.0.0.1"
	if not single_player_button.pressed.is_connected(_on_single_player_pressed):
		single_player_button.pressed.connect(_on_single_player_pressed)
	if not host_game_button.pressed.is_connected(_on_host_game_pressed):
		host_game_button.pressed.connect(_on_host_game_pressed)
	if not join_game_button.pressed.is_connected(_on_join_game_pressed):
		join_game_button.pressed.connect(_on_join_game_pressed)
	if not connect_button.pressed.is_connected(_on_connect_pressed):
		connect_button.pressed.connect(_on_connect_pressed)
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	var network_manager = _get_network_manager()
	if network_manager != null and not network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.connect(_on_connection_failed_message)
	status_label.text = ""


func _exit_tree() -> void:
	var network_manager = _get_network_manager()
	if network_manager != null and network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.disconnect(_on_connection_failed_message)


func _on_single_player_pressed() -> void:
	var network_manager = _get_network_manager()
	if network_manager != null:
		network_manager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_host_game_pressed() -> void:
	var network_manager = _get_network_manager()
	if network_manager == null:
		return
	network_manager.host_game()
	network_manager.show_lobby()


func _on_join_game_pressed() -> void:
	join_panel.visible = not join_panel.visible
	if join_panel.visible:
		ip_input.grab_focus()


func _on_connect_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter a host IP address."
		return
	var network_manager = _get_network_manager()
	if network_manager == null:
		return
	network_manager.join_game(ip)
	network_manager.show_lobby()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_connection_failed_message(message: String) -> void:
	status_label.text = message


func _get_network_manager():
	return get_node_or_null("/root/NetworkManager")
