extends Control

signal return_to_surface_requested
signal start_new_cycle_requested

var _stats: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_victory(stats: Dictionary) -> void:
	_stats = stats.duplicate()
	visible = true
	_build_ui()


func close() -> void:
	visible = false
	for child: Node in get_children():
		child.queue_free()


func _build_ui() -> void:
	for child: Node in get_children():
		child.queue_free()

	# Gold background dimmer
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.02, 0.93)
	add_child(bg)

	# Gold border flash overlay
	var border: ColorRect = ColorRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.color = Color(1.0, 0.82, 0.1, 0.0)
	add_child(border)

	# Center panel
	var panel: PanelContainer = PanelContainer.new()
	panel.layout_mode = 1
	panel.anchor_left = 0.15
	panel.anchor_top = 0.05
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.95
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.09, 0.06, 0.96)
	panel_style.border_color = Color(1.0, 0.82, 0.1, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title_lbl: Label = Label.new()
	title_lbl.text = "通關！"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.0, 1.0))
	vbox.add_child(title_lbl)

	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle_num: int = int(cycle_manager.current_cycle) if cycle_manager != null else 1
	var sub_lbl: Label = Label.new()
	sub_lbl.text = "第 %d 輪迴完成！" % cycle_num
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
	vbox.add_child(sub_lbl)

	var sep1: HSeparator = HSeparator.new()
	vbox.add_child(sep1)

	# Stats grid
	var stats_grid: GridContainer = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(stats_grid)

	var stat_rows: Array = [
		["總擊殺", str(int(_stats.get("total_kills", 0)))],
		["獲得金幣（銅）", str(int(_stats.get("gold_earned", 0)))],
		["裝備數量", str(int(_stats.get("equipment_count", 0)))],
		["死亡次數", str(int(_stats.get("deaths", 0)))],
		["用時（秒）", "%d:%02d" % [int(_stats.get("elapsed_seconds", 0)) / 60, int(_stats.get("elapsed_seconds", 0)) % 60]],
	]
	for row_data in stat_rows:
		var key_lbl: Label = Label.new()
		key_lbl.text = str(row_data[0])
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1.0))
		stats_grid.add_child(key_lbl)
		var val_lbl: Label = Label.new()
		val_lbl.text = str(row_data[1])
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_grid.add_child(val_lbl)

	# Achievements earned this run
	var achievements_earned: Array = _stats.get("achievements_earned", [])
	if not achievements_earned.is_empty():
		var sep2: HSeparator = HSeparator.new()
		vbox.add_child(sep2)
		var ach_title: Label = Label.new()
		ach_title.text = "本次達成挑戰"
		ach_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ach_title.add_theme_font_size_override("font_size", 18)
		ach_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1, 1.0))
		vbox.add_child(ach_title)
		for ach_name: String in achievements_earned:
			var ach_lbl: Label = Label.new()
			ach_lbl.text = "★ %s" % ach_name
			ach_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ach_lbl.add_theme_font_size_override("font_size", 14)
			ach_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0))
			vbox.add_child(ach_lbl)

	var sep3: HSeparator = HSeparator.new()
	vbox.add_child(sep3)

	# Buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 32)
	vbox.add_child(btn_row)

	var cycle_btn: Button = Button.new()
	cycle_btn.text = "進入輪迴"
	cycle_btn.custom_minimum_size = Vector2(160, 52)
	cycle_btn.add_theme_font_size_override("font_size", 18)
	cycle_btn.pressed.connect(_on_cycle_pressed)
	btn_row.add_child(cycle_btn)

	var surface_btn: Button = Button.new()
	surface_btn.text = "返回據點"
	surface_btn.custom_minimum_size = Vector2(160, 52)
	surface_btn.add_theme_font_size_override("font_size", 18)
	surface_btn.pressed.connect(_on_surface_pressed)
	btn_row.add_child(surface_btn)


func _on_cycle_pressed() -> void:
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	if cycle_manager != null:
		cycle_manager.advance_cycle()
	close()
	start_new_cycle_requested.emit()


func _on_surface_pressed() -> void:
	close()
	return_to_surface_requested.emit()
