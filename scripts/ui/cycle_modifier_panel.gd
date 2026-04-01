extends Control
class_name CycleModifierPanel

signal confirmed(selected_modifiers: Array[String])

var _checkboxes: Dictionary = {}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_panel() -> void:
	_rebuild_ui()
	visible = true


func close_panel() -> void:
	visible = false


func _rebuild_ui() -> void:
	for child: Node in get_children():
		child.queue_free()
	_checkboxes.clear()

	var cm: Node = get_node_or_null("/root/CycleModifier")
	if cm == null:
		return
	var cycle_mgr: Node = get_node_or_null("/root/CycleManager")
	var current_cycle: int = 1
	if cycle_mgr != null:
		current_cycle = int(cycle_mgr.get("current_cycle"))

	# Backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Panel
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.97)
	style.border_color = Color(0.5, 0.3, 0.6, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = LocaleManager.L("cycle_modifier_title") % current_cycle
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0, 1.0))
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = LocaleManager.L("cycle_modifier_subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.7, 0.7, 0.75, 1.0)
	vbox.add_child(subtitle)
	vbox.add_child(HSeparator.new())

	# Modifier list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for mod_id: String in cm.MODIFIER_DEFS.keys():
		var def: Dictionary = cm.MODIFIER_DEFS[mod_id] as Dictionary
		_add_modifier_row(list, mod_id, def, cm.is_modifier_active(mod_id))

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var skip_btn: Button = Button.new()
	skip_btn.text = LocaleManager.L("cycle_modifier_skip")
	skip_btn.custom_minimum_size = Vector2(160, 38)
	skip_btn.pressed.connect(_on_skip)
	btn_row.add_child(skip_btn)

	var start_btn: Button = Button.new()
	start_btn.text = LocaleManager.L("cycle_modifier_start")
	start_btn.custom_minimum_size = Vector2(160, 38)
	var start_style: StyleBoxFlat = StyleBoxFlat.new()
	start_style.bg_color = Color(0.3, 0.15, 0.5, 0.9)
	start_style.corner_radius_top_left = 6
	start_style.corner_radius_top_right = 6
	start_style.corner_radius_bottom_left = 6
	start_style.corner_radius_bottom_right = 6
	start_btn.add_theme_stylebox_override("normal", start_style)
	start_btn.pressed.connect(_on_confirm)
	btn_row.add_child(start_btn)


func _add_modifier_row(parent: VBoxContainer, mod_id: String, def: Dictionary, is_active: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var checkbox: CheckBox = CheckBox.new()
	checkbox.button_pressed = is_active
	checkbox.custom_minimum_size = Vector2(24, 24)
	row.add_child(checkbox)
	_checkboxes[mod_id] = checkbox

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_lbl: Label = Label.new()
	name_lbl.text = LocaleManager.L(str(def.get("name", mod_id)))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	info.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = LocaleManager.L(str(def.get("description", "")))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(0.9, 0.5, 0.5, 1.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	var reward_lbl: Label = Label.new()
	reward_lbl.text = LocaleManager.L(str(def.get("reward", "")))
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.modulate = Color(0.5, 0.9, 0.6, 1.0)
	reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(reward_lbl)


func _on_confirm() -> void:
	var selected: Array[String] = []
	var cm: Node = get_node_or_null("/root/CycleModifier")
	if cm == null:
		close_panel()
		confirmed.emit(selected)
		return
	# Clear all then re-apply selected
	cm.active_modifiers.clear()
	for mod_id: String in _checkboxes.keys():
		var cb: CheckBox = _checkboxes[mod_id] as CheckBox
		if cb != null and cb.button_pressed:
			cm.active_modifiers.append(mod_id)
			selected.append(mod_id)
	cm.modifiers_changed.emit()
	close_panel()
	confirmed.emit(selected)


func _on_skip() -> void:
	var cm: Node = get_node_or_null("/root/CycleModifier")
	if cm != null:
		cm.active_modifiers.clear()
		cm.modifiers_changed.emit()
	close_panel()
	var empty: Array[String] = []
	confirmed.emit(empty)
