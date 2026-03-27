extends Control

signal buff_chosen(buff_id: String)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var card_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardContainer
@onready var auto_timer: Timer = $AutoSelectTimer

var active_options: Array[Dictionary] = []

const ATTACK_CARD_COLOR: Color = Color(0.92, 0.34, 0.30, 1.0)
const DEFENSE_CARD_COLOR: Color = Color(0.30, 0.55, 0.92, 1.0)
const SUPPORT_CARD_COLOR: Color = Color(0.32, 0.78, 0.42, 1.0)
const DEFAULT_CARD_COLORS: Array[Color] = [
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
	for child: Node in card_container.get_children():
		child.queue_free()
	for i in range(active_options.size()):
		var option: Dictionary = active_options[i]
		var card_color: Color = _get_option_color(option, i)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(160, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE

		button.add_theme_stylebox_override("normal", _make_card_style(card_color))
		button.add_theme_stylebox_override("hover", _make_card_style(card_color.lightened(0.18), 0.16))
		button.add_theme_stylebox_override("pressed", _make_card_style(card_color.darkened(0.1), 0.08))
		button.add_theme_stylebox_override("focus", _make_card_style(card_color.lightened(0.1), 0.14))
		button.add_theme_stylebox_override("hover_pressed", _make_card_style(card_color.darkened(0.1), 0.08))
		button.add_theme_stylebox_override("disabled", _make_card_style(card_color.darkened(0.2), 0.06))
		button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
		button.text = "%s\n[%s]\n%s" % [
			LocaleManager.L(str(option.get("name", ""))),
			LocaleManager.L(str(option.get("category", ""))),
			LocaleManager.L(str(option.get("description", ""))),
		]
		_apply_card_border(button, card_color)
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
	var category_key: String = str(option.get("category", ""))
	if category_key == "buff_atk_up_1_cat" or category_key == "buff_atk_up_2_cat" or category_key == "buff_crit_chance_cat" or category_key == "buff_atk_speed_cat" or category_key == "buff_lifesteal_cat" or category_key == "buff_aoe_attack_cat":
		return ATTACK_CARD_COLOR
	if category_key == "buff_hp_up_cat" or category_key == "buff_armor_cat" or category_key == "buff_dodge_chance_cat" or category_key == "buff_regen_cat":
		return DEFENSE_CARD_COLOR
	if category_key == "buff_speed_up_cat" or category_key == "buff_loot_up_cat":
		return SUPPORT_CARD_COLOR
	var color: Variant = option.get("color", null)
	if color is Color:
		return color
	return DEFAULT_CARD_COLORS[fallback_index % DEFAULT_CARD_COLORS.size()]


func _make_card_style(border_color: Color, tint_strength: float = 0.12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base_background: Color = Color(0.15, 0.17, 0.23, 0.96)
	var tinted_background: Color = Color(border_color.r * 0.18, border_color.g * 0.18, border_color.b * 0.18, 0.96)
	style.bg_color = base_background.lerp(tinted_background, clampf(tint_strength, 0.0, 1.0))
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.25)
	style.shadow_size = 2
	return style


func _apply_card_border(button: Button, base_color: Color) -> void:
	for child: Node in button.get_children():
		if child.name == "CardBorder":
			child.queue_free()
	var border_drawer: Control = Control.new()
	border_drawer.name = "CardBorder"
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.draw.connect(func() -> void:
		var rect: Rect2 = border_drawer.get_rect().grow(-2.0)
		border_drawer.draw_rect(rect.grow(2), base_color.darkened(0.4), false, 2.0)
		border_drawer.draw_rect(rect, base_color, false, 2.0)
		border_drawer.draw_rect(rect.grow(-2), base_color.lightened(0.4), false, 1.0)
	)
	border_drawer.resized.connect(border_drawer.queue_redraw)
	button.add_child(border_drawer)
