extends Control
class_name BlessingChoicePanel

signal blessing_chosen(blessing_id: String)

var _input_lock_until: int = 0
var _choice_made: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_with_choices(choices: Array[Dictionary]) -> void:
	_choice_made = false
	_input_lock_until = Time.get_ticks_msec() + 500
	_rebuild_ui(choices)
	visible = true


func close_panel() -> void:
	visible = false
	_choice_made = true


func _rebuild_ui(choices: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()

	# Fullscreen backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Center container
	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -300.0
	center.offset_right = 300.0
	center.offset_top = -160.0
	center.offset_bottom = 160.0
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	# Title
	var title: Label = Label.new()
	title.text = LocaleManager.L("blessing_select_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	center.add_child(title)

	# Card row
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 14)
	center.add_child(card_row)

	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		card_row.add_child(_build_card(choice))

	if choices.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "..."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(empty_label)


func _build_card(data: Dictionary) -> Button:
	var blessing_id: String = str(data.get("id", ""))
	var card_color: Color = Color(0.3, 0.3, 0.4, 1.0)
	var color_val: Variant = data.get("color", null)
	if color_val is Color:
		card_color = color_val

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(180, 220)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.focus_mode = Control.FOCUS_NONE

	var normal_style: StyleBoxFlat = _make_card_style(card_color, 0.12)
	var hover_style: StyleBoxFlat = _make_card_style(card_color, 0.28)
	var pressed_style: StyleBoxFlat = _make_card_style(card_color, 0.06)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))

	var display_name: String = LocaleManager.L(str(data.get("name", blessing_id)))
	var tier: String = str(data.get("tier", "sub"))
	var tier_label: String = LocaleManager.L("blessing_cat_main") if tier == "main" else LocaleManager.L("blessing_cat_sub")
	var description: String = LocaleManager.L(str(data.get("description", "")))
	var category: String = LocaleManager.L(str(data.get("category", "")))
	var stacks: int = int(data.get("current_stacks", 0))
	var stack_text: String = ""
	if stacks > 0:
		stack_text = " Lv.%d->%d" % [stacks, stacks + 1]

	btn.text = "%s%s\n[%s]\n%s\n%s" % [display_name, stack_text, category, description, tier_label]
	btn.pressed.connect(_on_card_pressed.bind(blessing_id))

	# Border effect
	var border: Control = Control.new()
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.draw.connect(func() -> void:
		var rect: Rect2 = border.get_rect().grow(-2.0)
		border.draw_rect(rect.grow(2), card_color.darkened(0.3), false, 2.0)
		border.draw_rect(rect, card_color, false, 2.0)
		border.draw_rect(rect.grow(-2), card_color.lightened(0.3), false, 1.0)
	)
	border.resized.connect(border.queue_redraw)
	btn.add_child(border)

	return btn


func _on_card_pressed(blessing_id: String) -> void:
	if _choice_made:
		return
	if Time.get_ticks_msec() < _input_lock_until:
		return
	_choice_made = true
	close_panel()
	blessing_chosen.emit(blessing_id)


func _make_card_style(accent: Color, tint: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = Color(0.13, 0.14, 0.19, 0.96)
	var tinted: Color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 0.96)
	style.bg_color = bg.lerp(tinted, clampf(tint, 0.0, 1.0))
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Block all input from passing through
	if event is InputEventMouseButton or event is InputEventKey:
		get_viewport().set_input_as_handled()
