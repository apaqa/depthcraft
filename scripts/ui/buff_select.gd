extends Control

signal buff_chosen(buff_id: String)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var card_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardContainer
@onready var auto_timer: Timer = $AutoSelectTimer

var active_options: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not auto_timer.timeout.is_connected(_on_auto_timer_timeout):
		auto_timer.timeout.connect(_on_auto_timer_timeout)


func open_with_options(options: Array[Dictionary]) -> void:
	active_options = options.duplicate(true)
	visible = true
	title_label.text = "選擇一個強化"
	_rebuild_cards()
	auto_timer.start(30.0)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	auto_timer.stop()
	for child in card_container.get_children():
		child.queue_free()


func _rebuild_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	for option in active_options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 180)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.14, 0.14, 0.18, 0.96)
		panel_style.border_width_left = 3
		panel_style.border_width_top = 3
		panel_style.border_width_right = 3
		panel_style.border_width_bottom = 3
		panel_style.border_color = option.get("color", Color.WHITE)
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override("normal", panel_style)
		button.add_theme_stylebox_override("hover", panel_style)
		button.add_theme_stylebox_override("pressed", panel_style)
		button.text = "%s\n[%s]\n%s" % [
			str(option.get("name", "")),
			str(option.get("category", "")),
			str(option.get("description", "")),
		]
		button.pressed.connect(_choose_buff.bind(str(option.get("id", ""))))
		card_container.add_child(button)


func _choose_buff(buff_id: String) -> void:
	if buff_id == "":
		return
	close_menu()
	buff_chosen.emit(buff_id)


func _on_auto_timer_timeout() -> void:
	if active_options.is_empty():
		return
	var random_option: Dictionary = active_options[randi() % active_options.size()]
	_choose_buff(str(random_option.get("id", "")))
