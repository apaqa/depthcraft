extends Control
class_name BlessingStatusPanel

var _player: Variant = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func toggle(target_player: Variant) -> void:
	_player = target_player
	if visible:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	_rebuild_ui()
	visible = true


func close_panel() -> void:
	visible = false


func _rebuild_ui() -> void:
	for child: Node in get_children():
		child.queue_free()

	# Backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Main panel (70% x 80%, centered)
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	panel_style.border_color = Color(0.35, 0.35, 0.4, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 24)
	margin.add_child(main_hbox)

	# Left side: player stats
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(left_vbox)
	_build_player_stats(left_vbox)

	# Separator
	var sep: VSeparator = VSeparator.new()
	main_hbox.add_child(sep)

	# Right side: blessings
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right_vbox)
	_build_blessing_list(right_vbox)


func _build_player_stats(parent: VBoxContainer) -> void:
	var title: Label = _make_header(LocaleManager.L("status_panel_stats"))
	parent.add_child(title)
	parent.add_child(HSeparator.new())

	# Class name
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	var class_name_text: String = ""
	if class_system != null and class_system.has_method("get_class_display_name"):
		class_name_text = str(class_system.get_class_display_name())
	if class_name_text == "":
		class_name_text = "Warrior"
	parent.add_child(_make_stat_row(LocaleManager.L("status_class"), class_name_text, Color(1.0, 0.9, 0.5, 1.0)))

	if _player == null:
		return
	var ps: Variant = _player.get("player_stats")
	if ps == null:
		return

	parent.add_child(_make_stat_row(LocaleManager.L("status_attack"), str(ps.get_total_attack()), Color(0.95, 0.45, 0.35, 1.0)))
	parent.add_child(_make_stat_row(LocaleManager.L("status_defense"), str(ps.get_total_defense()), Color(0.4, 0.65, 0.95, 1.0)))
	parent.add_child(_make_stat_row(LocaleManager.L("status_max_hp"), str(ps.get_total_max_hp()), Color(0.4, 0.9, 0.45, 1.0)))
	parent.add_child(_make_stat_row(LocaleManager.L("status_speed"), "%.0f" % ps.get_total_speed(), Color(0.5, 0.8, 1.0, 1.0)))
	var crit_pct: float = ps.get_total_crit_chance() * 100.0
	parent.add_child(_make_stat_row(LocaleManager.L("status_crit"), "%.1f%%" % crit_pct, Color(1.0, 0.8, 0.2, 1.0)))

	# Blessing effect bonuses
	var bs_node: Node = get_node_or_null("/root/BlessingSystem")
	if bs_node == null:
		return
	parent.add_child(HSeparator.new())
	var bonus_title: Label = _make_header(LocaleManager.L("status_blessing_bonus"))
	parent.add_child(bonus_title)

	var effect_names: Array[Array] = [
		["atk_percent", LocaleManager.L("status_atk_bonus")],
		["def_percent", LocaleManager.L("status_def_bonus")],
		["hp_percent", LocaleManager.L("status_hp_bonus")],
		["speed_percent", LocaleManager.L("status_speed_bonus")],
		["lifesteal", LocaleManager.L("status_lifesteal")],
		["crit_rate_bonus", LocaleManager.L("status_crit_bonus")],
	]
	for pair: Array in effect_names:
		var val: float = float(bs_node.get_total_effect_value(str(pair[0])))
		if val > 0.0:
			parent.add_child(_make_stat_row(str(pair[1]), "+%.0f%%" % (val * 100.0), Color(0.6, 1.0, 0.7, 1.0)))


func _build_blessing_list(parent: VBoxContainer) -> void:
	var title: Label = _make_header(LocaleManager.L("status_blessings_title"))
	parent.add_child(title)
	parent.add_child(HSeparator.new())

	var bs_node: Node = get_node_or_null("/root/BlessingSystem")
	if bs_node == null:
		parent.add_child(_make_dim_label(LocaleManager.L("status_no_blessings")))
		return

	var has_any: bool = false

	# Main blessing slots
	var slots: Dictionary = bs_node.main_blessing_slots
	for slot_id: String in ["primary", "secondary", "skill"]:
		var theme: String = str(slots.get(slot_id, ""))
		if theme == "":
			continue
		has_any = true
		var slot_label: String = LocaleManager.L(str(bs_node.SLOT_NAME_KEYS.get(slot_id, slot_id)))
		var theme_name: String = LocaleManager.L(str(bs_node.THEME_NAME_KEYS.get(theme, theme)))
		var theme_color: Color = bs_node.THEME_COLORS.get(theme, Color.WHITE) as Color
		var main_bid: String = str(bs_node.THEME_MAIN_BLESSING.get(theme, ""))
		var desc: String = ""
		if main_bid != "" and bs_node.BLESSING_DEFS.has(main_bid):
			desc = LocaleManager.L(str((bs_node.BLESSING_DEFS[main_bid] as Dictionary).get("description", "")))
		parent.add_child(_make_blessing_row(theme_color, "%s: %s" % [slot_label, theme_name], LocaleManager.L("blessing_cat_main"), desc, theme))

	# Sub blessings
	for entry: Dictionary in bs_node.active_sub_blessings:
		var bid: String = str(entry.get("id", ""))
		var stacks: int = int(entry.get("stacks", 1))
		if not bs_node.BLESSING_DEFS.has(bid):
			continue
		has_any = true
		var def: Dictionary = bs_node.BLESSING_DEFS[bid] as Dictionary
		var b_name: String = LocaleManager.L(str(def.get("name", bid)))
		var b_desc: String = LocaleManager.L(str(def.get("description", "")))
		var b_color: Color = Color(0.7, 0.7, 0.7, 1.0)
		var color_val: Variant = def.get("color", null)
		if color_val is Color:
			b_color = color_val
		var b_theme: String = str(def.get("theme", "generic"))
		parent.add_child(_make_blessing_row(b_color, b_name, "Lv.%d" % stacks, b_desc, b_theme))

	if not has_any:
		parent.add_child(_make_dim_label(LocaleManager.L("status_no_blessings")))


func _make_header(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_stat_row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.modulate = Color(0.8, 0.82, 0.88, 1.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)
	var val_lbl: Label = Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)
	return row


func _make_blessing_row(dot_color: Color, title_text: String, tag_text: String, desc_text: String, theme_id: String = "generic") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Theme icon (24x24)
	var icon_texture: Texture2D = BlessingChoicePanel.THEME_ICONS.get(theme_id, BlessingChoicePanel.THEME_ICONS.get("generic", null)) as Texture2D
	if icon_texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = dot_color
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	# Name + tag
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl: Label = Label.new()
	name_lbl.text = title_text
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(name_lbl)
	var tag_lbl: Label = Label.new()
	tag_lbl.text = tag_text
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.modulate = Color(0.65, 0.65, 0.7, 1.0)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(tag_lbl)
	info_vbox.add_child(top_row)
	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc_text
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(0.6, 0.62, 0.68, 1.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(desc_lbl)
	row.add_child(info_vbox)
	return row


func _make_dim_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.5, 0.5, 0.55, 1.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
