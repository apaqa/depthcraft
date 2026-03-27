extends Control

signal buff_chosen(buff_id: String)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var card_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardContainer
@onready var auto_timer: Timer = $AutoSelectTimer

var active_options: Array[Dictionary] = []

const DEFAULT_CARD_COLORS := [
	Color(1.0, 0.82, 0.20, 1.0),
	Color(0.58, 0.22, 0.90, 1.0),
	Color(0.22, 0.55, 0.95, 1.0),
]


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not auto_timer.timeout.is_connected(_on_auto_timer_timeout):
		auto_timer.timeout.connect(_on_auto_timer_timeout)


func open_with_options(options: Array[Dictionary]) -> void:
	active_options = options.duplicate(true)
	visible = true
	title_label.text = LocaleManager.L("buff_select_title")
	for child in card_container.get_children():
		child.queue_free()
	for i in range(active_options.size()):
		var option: Dictionary = active_options[i]
		var card_color := _get_option_color(option, i)
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER

		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.16, 0.18, 0.24, 0.96)
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.border_color = card_color
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override("normal", panel_style)
		button.add_theme_stylebox_override("hover", _make_card_style(card_color.lightened(0.2)))
		button.add_theme_stylebox_override("pressed", _make_card_style(card_color.darkened(0.15)))
		button.text = "%s\n[%s]\n%s" % [
			LocaleManager.L(str(option.get("name", ""))),
			LocaleManager.L(str(option.get("category", ""))),
			LocaleManager.L(str(option.get("description", ""))),
		]
		button.pressed.connect(_choose_buff.bind(str(option.get("id", ""))))
		card_container.add_child(button)

	auto_timer.stop()
	if not active_options.is_empty():
		auto_timer.start()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	auto_timer.stop()
	release_focus()


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


func _get_option_color(option: Dictionary, fallback_index: int = 0) -> Color:
	var color = option.get("color", null)
	if color is Color:
		return color
	return DEFAULT_CARD_COLORS[fallback_index % DEFAULT_CARD_COLORS.size()]


func _make_card_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.24, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
