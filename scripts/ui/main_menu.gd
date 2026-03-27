extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var single_player_button: Button = $Panel/MarginContainer/VBoxContainer/SinglePlayerButton
@onready var load_game_button: Button = $Panel/MarginContainer/VBoxContainer/LoadGameButton
@onready var host_game_button: Button = $Panel/MarginContainer/VBoxContainer/HostGameButton
@onready var join_game_button: Button = $Panel/MarginContainer/VBoxContainer/JoinGameButton
@onready var join_panel: VBoxContainer = $Panel/MarginContainer/VBoxContainer/JoinPanel
@onready var ip_input: LineEdit = $Panel/MarginContainer/VBoxContainer/JoinPanel/IPInput
@onready var connect_button: Button = $Panel/MarginContainer/VBoxContainer/JoinPanel/ConnectButton
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/QuitButton

const CONTINUE_GAME_ZH: String = "\u7e7c\u7e8c\u904a\u6232"
const NO_SAVE_ZH: String = "\u6c92\u6709\u53ef\u7528\u5b58\u6a94\u3002"
const SAVE_SUMMARY_ZH: String = "\u5b58\u6a94 1: \u7b2c %d \u5929 / \u6700\u6df1 %d \u5c64 / %dG %dS %dC"


func _ready() -> void:
	title_label.text = LocaleManager.L("main_title")
	join_panel.visible = false
	ip_input.text = _get_network_manager().get_last_join_ip() if _get_network_manager() != null else "127.0.0.1"
	load_game_button.text = _get_load_button_text()
	load_game_button.disabled = not SaveManager.has_save(1)
	if not single_player_button.pressed.is_connected(_on_single_player_pressed):
		single_player_button.pressed.connect(_on_single_player_pressed)
	if not load_game_button.pressed.is_connected(_on_load_game_pressed):
		load_game_button.pressed.connect(_on_load_game_pressed)
	if not host_game_button.pressed.is_connected(_on_host_game_pressed):
		host_game_button.pressed.connect(_on_host_game_pressed)
	if not join_game_button.pressed.is_connected(_on_join_game_pressed):
		join_game_button.pressed.connect(_on_join_game_pressed)
	if not connect_button.pressed.is_connected(_on_connect_pressed):
		connect_button.pressed.connect(_on_connect_pressed)
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	var network_manager: Node = _get_network_manager()
	if network_manager != null and not network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.connect(_on_connection_failed_message)
	status_label.text = _format_save_summary(SaveManager.get_save_meta(1)) if SaveManager.has_save(1) else ""


func _exit_tree() -> void:
	var network_manager: Node = _get_network_manager()
	if network_manager != null and network_manager.connection_failed_message.is_connected(_on_connection_failed_message):
		network_manager.connection_failed_message.disconnect(_on_connection_failed_message)


func _on_single_player_pressed() -> void:
	var network_manager: Node = _get_network_manager()
	if network_manager != null:
		network_manager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_load_game_pressed() -> void:
	if not SaveManager.has_save(1):
		status_label.text = _get_missing_save_text()
		return
	var network_manager: Node = _get_network_manager()
	if network_manager != null:
		network_manager.disconnect_game()
	SaveManager.load_game(1)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_host_game_pressed() -> void:
	var network_manager: Node = _get_network_manager()
	if network_manager == null:
		return
	network_manager.host_game()
	network_manager.show_lobby()


func _on_join_game_pressed() -> void:
	join_panel.visible = not join_panel.visible
	if join_panel.visible:
		ip_input.grab_focus()


func _on_connect_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = LocaleManager.L("enter_ip")
		return
	var network_manager: Node = _get_network_manager()
	if network_manager == null:
		return
	network_manager.join_game(ip)
	network_manager.show_lobby()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_connection_failed_message(message: String) -> void:
	status_label.text = message


func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")


func _get_load_button_text() -> String:
	return CONTINUE_GAME_ZH if LocaleManager.get_locale().begins_with("zh") else "Continue Game"


func _get_missing_save_text() -> String:
	return NO_SAVE_ZH if LocaleManager.get_locale().begins_with("zh") else "No save available."


func _format_save_summary(meta: Dictionary) -> String:
	if meta.is_empty():
		return _get_missing_save_text()
	var current_day: int = int(meta.get("current_day", 1))
	var deepest_floor: int = int(meta.get("deepest_floor", 1))
	var gold: int = int(meta.get("gold", 0))
	var silver: int = int(meta.get("silver", 0))
	var copper: int = int(meta.get("copper", 0))
	if LocaleManager.get_locale().begins_with("zh"):
		return SAVE_SUMMARY_ZH % [current_day, deepest_floor, gold, silver, copper]
	return "Slot 1: Day %d / Deepest Floor %d / %dG %dS %dC" % [current_day, deepest_floor, gold, silver, copper]
