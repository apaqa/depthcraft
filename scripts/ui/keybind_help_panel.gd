extends Control
class_name KeybindHelpPanel

var _built: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func toggle() -> void:
	if visible:
		visible = false
		return
	if not _built:
		_build_ui()
		_built = true
	visible = true


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240.0
	panel.offset_right = 240.0
	panel.offset_top = -220.0
	panel.offset_bottom = 220.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.35, 0.35, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	var title: Label = Label.new()
	title.text = LocaleManager.L("keybind_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1.0, 0.95, 0.7, 1.0)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var binds: Array[Array] = [
		["WASD", "keybind_move"],
		["LMB", "keybind_attack"],
		["RMB", "keybind_charge"],
		["Z / X / V", "keybind_skills"],
		["E", "keybind_interact"],
		["Q / R", "keybind_consumables"],
		["I", "keybind_inventory"],
		["C", "keybind_equipment"],
		["K", "keybind_skill_panel"],
		["B", "keybind_build"],
		["TAB", "keybind_status"],
		["Shift", "keybind_sprint"],
		["F1", "keybind_help"],
		["ESC", "keybind_pause"],
	]

	for bind: Array in binds:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var key_lbl: Label = Label.new()
		key_lbl.text = str(bind[0])
		key_lbl.custom_minimum_size = Vector2(100, 0)
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.modulate = Color(0.9, 0.85, 0.5, 1.0)
		row.add_child(key_lbl)
		var desc_lbl: Label = Label.new()
		desc_lbl.text = LocaleManager.L(str(bind[1]))
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)
		row.add_child(desc_lbl)
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	var close_hint: Label = Label.new()
	close_hint.text = LocaleManager.L("keybind_close_hint")
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 12)
	close_hint.modulate = Color(0.6, 0.6, 0.6, 1.0)
	vbox.add_child(close_hint)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("help"):
		visible = false
		get_viewport().set_input_as_handled()
