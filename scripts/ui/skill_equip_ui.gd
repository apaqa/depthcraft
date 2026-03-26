extends Control

signal close_requested

const KEY_NAMES := ["Z", "X", "C", "V", "G", "H"]

var _selected_skill_id: String = ""
var _slot_buttons: Array[Button] = []
var _slot_list: VBoxContainer = null
var _unlocked_list: VBoxContainer = null
var _info_label: Label = null
var _title_label: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.layout_mode = 1
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -220.0
	panel.offset_right = 280.0
	panel.offset_bottom = 220.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# Title row
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "技能裝備  [K 關閉]"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	title_row.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(close_menu)
	title_row.add_child(close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Main columns
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(columns)

	# Left: equipped slots
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(200, 0)
	left_panel.add_theme_constant_override("separation", 4)
	columns.add_child(left_panel)

	var left_header := Label.new()
	left_header.text = "已裝備技能槽"
	left_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
	left_header.add_theme_font_size_override("font_size", 12)
	left_panel.add_child(left_header)

	var left_hint := Label.new()
	left_hint.text = "← 點此槽位裝備選中技能"
	left_hint.add_theme_font_size_override("font_size", 10)
	left_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	left_panel.add_child(left_hint)

	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 3)
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_slot_list)

	var vsep := VSeparator.new()
	columns.add_child(vsep)

	# Right: unlocked skill list
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 4)
	columns.add_child(right_panel)

	var right_header := Label.new()
	right_header.text = "已解鎖技能"
	right_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
	right_header.add_theme_font_size_override("font_size", 12)
	right_panel.add_child(right_header)

	var right_hint := Label.new()
	right_hint.text = "← 點此選擇技能，再點左側槽位裝備"
	right_hint.add_theme_font_size_override("font_size", 10)
	right_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	right_panel.add_child(right_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	right_panel.add_child(scroll)

	_unlocked_list = VBoxContainer.new()
	_unlocked_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlocked_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_unlocked_list)

	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	# Info / description area
	_info_label = Label.new()
	_info_label.text = "選擇右側技能後，點左側槽位裝備。點已裝備槽位可卸除技能。"
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(0, 36)
	root_vbox.add_child(_info_label)


func open_for_player(_player) -> void:
	_selected_skill_id = ""
	visible = true
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	_selected_skill_id = ""
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_skills"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_refresh_slot_list()
	_refresh_unlocked_list()


func _refresh_slot_list() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var skill_system = _get_skill_system()
	if skill_system == null:
		return

	var snapshots: Array = skill_system.get_equipped_skill_snapshots()
	for slot_index in range(6):
		var slot: Dictionary = snapshots[slot_index] if slot_index < snapshots.size() else {}
		var key_name: String = KEY_NAMES[slot_index]

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(190, 32)

		if slot.is_empty():
			btn.text = "[%s]  ─ 空槽" % key_name
			btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		else:
			var cd := float(slot.get("current_cooldown", 0.0))
			var name_str := str(slot.get("name", "技能"))
			if cd > 0.0:
				btn.text = "[%s]  %s  (CD: %.1fs)" % [key_name, name_str, cd]
				btn.modulate = Color(0.65, 0.65, 0.65, 1.0)
			else:
				btn.text = "[%s]  %s" % [key_name, name_str]
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

		btn.pressed.connect(_on_slot_pressed.bind(slot_index))
		_slot_list.add_child(btn)
		_slot_buttons.append(btn)


func _refresh_unlocked_list() -> void:
	for child in _unlocked_list.get_children():
		child.queue_free()

	var skill_system = _get_skill_system()
	if skill_system == null:
		return

	if skill_system.unlocked_skill_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "尚未解鎖任何技能。\n在天賦祭壇解鎖技能。"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		_unlocked_list.add_child(empty_label)
		return

	for skill_id in skill_system.unlocked_skill_ids:
		var def: Dictionary = skill_system.skills.get(skill_id, {})
		if def.is_empty():
			continue

		var is_passive: bool = bool(def.get("passive", false))
		var is_equipped: bool = skill_system.equipped_skill_ids.has(skill_id)
		var is_selected: bool = (_selected_skill_id == skill_id)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var cd_text := ""
		if is_passive:
			cd_text = " [被動]"
		else:
			var cd := float(def.get("cooldown", 0.0))
			cd_text = " [CD: %.0fs]" % cd

		btn.text = "%s%s" % [str(def.get("name", skill_id)), cd_text]

		if is_selected:
			btn.modulate = Color(1.0, 1.0, 0.4, 1.0)
		elif is_equipped:
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
		elif is_passive:
			btn.modulate = Color(0.7, 0.55, 0.85, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

		btn.pressed.connect(_on_skill_selected.bind(skill_id))
		_unlocked_list.add_child(btn)


func _on_skill_selected(skill_id: String) -> void:
	var skill_system = _get_skill_system()
	if skill_system == null:
		return

	var def: Dictionary = skill_system.skills.get(skill_id, {})
	var is_passive: bool = bool(def.get("passive", false))

	_selected_skill_id = skill_id

	var name_str := str(def.get("name", skill_id))
	var desc_str := str(def.get("desc", ""))
	var cd := float(def.get("cooldown", 0.0))

	if is_passive:
		_info_label.text = "%s（被動技能，無法裝備進槽位）\n%s" % [name_str, desc_str]
		_selected_skill_id = ""
	else:
		var cd_text := "CD: %.0f 秒" % cd
		var equipped_in := ""
		for i in range(skill_system.equipped_skill_ids.size()):
			if skill_system.equipped_skill_ids[i] == skill_id:
				equipped_in = "  ▶ 目前在槽位 %s" % KEY_NAMES[i]
				break
		_info_label.text = "%s  [%s]%s\n%s" % [name_str, cd_text, equipped_in, desc_str]

	_refresh_unlocked_list()


func _on_slot_pressed(slot_index: int) -> void:
	var skill_system = _get_skill_system()
	if skill_system == null:
		return

	if _selected_skill_id != "":
		skill_system.equip_to_slot(_selected_skill_id, slot_index)
		_selected_skill_id = ""
		_info_label.text = "技能已裝備。"
	else:
		# No skill selected — unequip the slot
		var equipped_id: String = skill_system.equipped_skill_ids[slot_index]
		if equipped_id != "":
			skill_system.unequip_slot(slot_index)
			_info_label.text = "已從槽位卸除技能。"
		else:
			_info_label.text = "此槽位為空。先從右側選擇技能再點此裝備。"

	_refresh()


func _get_skill_system() -> Node:
	return get_node_or_null("/root/SkillSystem")
