extends Control

const TALENT_DATA := preload("res://scripts/talent/talent_data.gd")

signal close_requested

@onready var shard_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ShardLabel
@onready var branch_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/BranchRow

var player = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_for_player(target_player) -> void:
	player = target_player
	visible = true
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in branch_row.get_children():
		child.queue_free()
	if player == null:
		return
	shard_label.text = LocaleManager.L("talent_shards") % player.inventory.get_item_count("talent_shard")
	for branch_id in TALENT_DATA.get_branch_ids():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(340, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

		var branch_box := VBoxContainer.new()
		branch_box.add_theme_constant_override("separation", 4)
		branch_box.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(branch_box)

		var title := Label.new()
		title.text = LocaleManager.L(TALENT_DATA.get_branch_label(branch_id))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		branch_box.add_child(title)

		# Main line nodes 1-5
		var main_talents := TALENT_DATA.get_sub_branch_talents(branch_id, "main")
		var main_top: Array[Dictionary] = []
		var main_bot: Array[Dictionary] = []
		for t in main_talents:
			if int(t.get("sequence", 0)) <= 5:
				main_top.append(t)
			else:
				main_bot.append(t)

		for talent in main_top:
			branch_box.add_child(_make_talent_button(talent, false))

		# Branch fork divider
		var sub_ids := TALENT_DATA.get_sub_branch_ids(branch_id)
		if sub_ids.size() >= 2:
			var divider := Label.new()
			divider.text = "┌─ 分支點 ─┐"
			divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			divider.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 1.0))
			branch_box.add_child(divider)

			var fork_row := HBoxContainer.new()
			fork_row.add_theme_constant_override("separation", 4)
			fork_row.mouse_filter = Control.MOUSE_FILTER_PASS
			branch_box.add_child(fork_row)

			for sub_id in sub_ids:
				var sub_col := VBoxContainer.new()
				sub_col.add_theme_constant_override("separation", 4)
				sub_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				sub_col.mouse_filter = Control.MOUSE_FILTER_PASS
				fork_row.add_child(sub_col)

				var sub_title := Label.new()
				sub_title.text = TALENT_DATA.get_sub_branch_label(branch_id, sub_id)
				sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				sub_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sub_title.add_theme_font_size_override("font_size", 11)
				sub_col.add_child(sub_title)

				var sub_talents := TALENT_DATA.get_sub_branch_talents(branch_id, sub_id)
				for talent in sub_talents:
					sub_col.add_child(_make_talent_button(talent, true))

		# Continuation divider
		if main_bot.size() > 0:
			var cont_lbl := Label.new()
			cont_lbl.text = "└─ 主線繼續 ─┘"
			cont_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cont_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cont_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 1.0))
			branch_box.add_child(cont_lbl)

			for talent in main_bot:
				branch_box.add_child(_make_talent_button(talent, false))

		branch_row.add_child(panel)


func _make_talent_button(talent: Dictionary, is_sub: bool) -> Button:
	var button := Button.new()
	var talent_id := str(talent.get("id", ""))
	var is_milestone := bool(talent.get("is_milestone", false))

	button.text = _build_talent_text(talent)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_sub:
		button.custom_minimum_size = Vector2(140, 56)
	elif is_milestone:
		button.custom_minimum_size = Vector2(200, 72)
	else:
		button.custom_minimum_size = Vector2(200, 52)

	var shards: int = player.inventory.get_item_count("talent_shard") if player != null else 0
	var unlocked: Array[String] = player.get_unlocked_talents() if player != null else []
	var prereq := str(talent.get("prerequisite", ""))
	var prereq_met := prereq == "" or unlocked.has(prereq)
	var can_afford := shards >= int(talent.get("cost", 0))

	if player != null and player.has_talent(talent_id):
		# Unlocked: golden glow
		button.modulate = Color(1.0, 0.92, 0.4, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.96, 0.82, 0.26, 1.0)))
	elif prereq_met and can_afford:
		# Available: green
		button.modulate = Color(0.55, 0.95, 0.55, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.3, 0.8, 0.3, 1.0)))
	elif prereq_met and not can_afford:
		# Prerequisite met but too expensive: reddish
		button.modulate = Color(1.0, 0.5, 0.45, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.85, 0.3, 0.3, 1.0)))
	else:
		# Locked: gray
		button.modulate = Color(0.55, 0.55, 0.55, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.4, 0.4, 0.4, 1.0)))

	button.pressed.connect(_on_talent_pressed.bind(talent_id))
	return button


func _make_milestone_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.06, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _build_talent_text(talent: Dictionary) -> String:
	var talent_id := str(talent.get("id", ""))
	var is_milestone := bool(talent.get("is_milestone", false))
	var milestone_prefix := "[里程碑]\n" if is_milestone else ""
	if player != null and player.has_talent(talent_id):
		return "%s%s
%s" % [milestone_prefix, LocaleManager.L(str(talent.get("name", talent_id))), LocaleManager.L("talent_unlocked")]
	return "%s%s
%s
%s" % [
		milestone_prefix,
		LocaleManager.L(str(talent.get("name", talent_id))),
		LocaleManager.L(str(talent.get("description", ""))),
		LocaleManager.L("talent_cost") % int(talent.get("cost", 0)),
	]


func _on_talent_pressed(talent_id: String) -> void:
	if player == null:
		return
	var data: Dictionary = TALENT_DATA.get_talent(talent_id)
	var shards: int = player.inventory.get_item_count("talent_shard")
	if player.has_talent(talent_id):
		print("Talent already unlocked: ", talent_id)
		return
	if shards < int(data.get("cost", 0)):
		print("Not enough shards: have ", shards, " need ", int(data.get("cost", 0)))
		return
	var prerequisite := str(data.get("prerequisite", ""))
	if prerequisite != "" and not player.has_talent(prerequisite):
		print("Prerequisite not met for ", talent_id)
		return
	if player.unlock_talent(talent_id):
		print("Unlocked talent: ", talent_id)
		_refresh()
