extends Control

const TALENT_DATA := preload("res://scripts/talent/talent_data.gd")

const PANEL_WIDTH := 372.0
const MAIN_BUTTON_SIZE := Vector2(216, 60)
const MILESTONE_BUTTON_SIZE := Vector2(216, 82)
const SUB_BUTTON_SIZE := Vector2(160, 78)
const CONNECTOR_COLOR := Color(0.82, 0.72, 0.38, 0.9)

signal close_requested

@onready var panel_container: PanelContainer = $PanelContainer

@onready var shard_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ShardLabel
@onready var branch_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/BranchRow
@onready var content_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

var player = null
var facility = null
var upgrade_label: Label = null
var upgrade_button: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_close_button()
	_ensure_upgrade_controls()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_close_btn_pos()


func _update_close_btn_pos() -> void:
	var close_btn := get_node_or_null("CloseButton") as Button
	if close_btn != null and panel_container != null:
		close_btn.position = panel_container.position + Vector2(8, 8)


func open_for_player(target_player, target_facility = null) -> void:
	player = target_player
	facility = target_facility
	visible = true
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(false)
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
	_refresh_upgrade_controls()

	for branch_id in TALENT_DATA.get_branch_ids():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

		var branch_box := VBoxContainer.new()
		branch_box.add_theme_constant_override("separation", 6)
		branch_box.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(branch_box)

		var title := Label.new()
		title.text = LocaleManager.L(TALENT_DATA.get_branch_label(branch_id))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		branch_box.add_child(title)

		var main_talents := TALENT_DATA.get_sub_branch_talents(branch_id, "main")
		var main_top: Array[Dictionary] = []
		var main_bot: Array[Dictionary] = []
		for talent in main_talents:
			if int(talent.get("sequence", 0)) <= 5:
				main_top.append(talent)
			else:
				main_bot.append(talent)

		for talent in main_top:
			branch_box.add_child(_make_talent_button(talent, false))

		var sub_ids := TALENT_DATA.get_sub_branch_ids(branch_id)
		if sub_ids.size() >= 2:
			branch_box.add_child(_make_split_connector())
			branch_box.add_child(_make_info_label(LocaleManager.L("talent_branch_divider")))

			var fork_row := HBoxContainer.new()
			fork_row.add_theme_constant_override("separation", 8)
			fork_row.mouse_filter = Control.MOUSE_FILTER_PASS
			branch_box.add_child(fork_row)

			for sub_id in sub_ids:
				var sub_col := VBoxContainer.new()
				sub_col.add_theme_constant_override("separation", 4)
				sub_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				sub_col.mouse_filter = Control.MOUSE_FILTER_PASS
				fork_row.add_child(sub_col)

				var sub_title := Label.new()
				sub_title.text = TALENT_DATA.get_sub_branch_label(branch_id, str(sub_id))
				sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				sub_title.add_theme_font_size_override("font_size", 12)
				sub_title.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 1.0))
				sub_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sub_col.add_child(sub_title)

				var sub_talents := TALENT_DATA.get_sub_branch_talents(branch_id, str(sub_id))
				for talent in sub_talents:
					sub_col.add_child(_make_talent_button(talent, true))

		if main_bot.size() > 0:
			if sub_ids.size() >= 2:
				branch_box.add_child(_make_merge_connector())
			branch_box.add_child(_make_info_label(LocaleManager.L("talent_branch_continue")))
			for talent in main_bot:
				branch_box.add_child(_make_talent_button(talent, false))

		branch_row.add_child(panel)


func _make_info_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_split_connector() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(PANEL_WIDTH - 36.0, 28.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = root.custom_minimum_size.x
	var center_x: float = floor(width * 0.5)
	root.add_child(_make_line(Vector2(center_x, 0.0), Vector2(2.0, 10.0)))
	root.add_child(_make_line(Vector2(36.0, 10.0), Vector2(width - 72.0, 2.0)))
	root.add_child(_make_line(Vector2(36.0, 10.0), Vector2(2.0, 18.0)))
	root.add_child(_make_line(Vector2(width - 38.0, 10.0), Vector2(2.0, 18.0)))
	return root


func _make_merge_connector() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(PANEL_WIDTH - 36.0, 28.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = root.custom_minimum_size.x
	var center_x: float = floor(width * 0.5)
	root.add_child(_make_line(Vector2(36.0, 0.0), Vector2(2.0, 18.0)))
	root.add_child(_make_line(Vector2(width - 38.0, 0.0), Vector2(2.0, 18.0)))
	root.add_child(_make_line(Vector2(36.0, 18.0), Vector2(width - 72.0, 2.0)))
	root.add_child(_make_line(Vector2(center_x, 18.0), Vector2(2.0, 10.0)))
	return root


func _make_line(position_value: Vector2, size_value: Vector2) -> ColorRect:
	var line := ColorRect.new()
	line.position = position_value
	line.custom_minimum_size = size_value
	line.size = size_value
	line.color = CONNECTOR_COLOR
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _make_talent_button(talent: Dictionary, is_sub: bool) -> Button:
	var button := Button.new()
	var talent_id := str(talent.get("id", ""))
	var is_milestone := bool(talent.get("is_milestone", false))

	button.text = _build_talent_text(talent)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if is_sub:
		button.custom_minimum_size = SUB_BUTTON_SIZE
	elif is_milestone:
		button.custom_minimum_size = MILESTONE_BUTTON_SIZE
	else:
		button.custom_minimum_size = MAIN_BUTTON_SIZE

	var shards: int = player.inventory.get_item_count("talent_shard") if player != null else 0
	var unlocked: Array[String] = player.get_unlocked_talents() if player != null else []
	var prerequisite := str(talent.get("prerequisite", ""))
	var prereq_met := prerequisite == "" or unlocked.has(prerequisite)
	var can_afford := shards >= int(talent.get("cost", 0))

	if player != null and player.has_talent(talent_id):
		button.modulate = Color(1.0, 0.92, 0.4, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.96, 0.82, 0.26, 1.0)))
	elif prereq_met and can_afford:
		button.modulate = Color(0.55, 0.95, 0.55, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.3, 0.8, 0.3, 1.0)))
	elif prereq_met and not can_afford:
		button.modulate = Color(1.0, 0.5, 0.45, 1.0)
		if is_milestone:
			button.add_theme_stylebox_override("normal", _make_milestone_style(Color(0.85, 0.3, 0.3, 1.0)))
	else:
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
	var milestone_prefix := LocaleManager.L("milestone_prefix") if is_milestone else ""
	var talent_name := LocaleManager.L(str(talent.get("name", talent_id)))
	if player != null and player.has_talent(talent_id):
		return "%s%s\n%s" % [milestone_prefix, talent_name, LocaleManager.L("talent_unlocked")]
	return "%s%s\n%s\n%s" % [
		milestone_prefix,
		talent_name,
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


func _ensure_close_button() -> void:
	if panel_container == null or get_node_or_null("CloseButton") != null:
		return
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = panel_container.position + Vector2(8, 8)
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.size = Vector2(32, 32)
	close_button.z_index = 100
	close_button.pressed.connect(close_menu)
	add_child(close_button)
	_update_close_btn_pos.call_deferred()


func _ensure_upgrade_controls() -> void:
	if content_vbox == null or upgrade_label != null:
		return
	upgrade_label = Label.new()
	upgrade_label.visible = false
	upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(upgrade_label)
	content_vbox.move_child(upgrade_label, 1)

	upgrade_button = Button.new()
	upgrade_button.visible = false
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	content_vbox.add_child(upgrade_button)
	content_vbox.move_child(upgrade_button, 2)


func _refresh_upgrade_controls() -> void:
	if upgrade_label == null or upgrade_button == null:
		return
	if facility == null or not facility.has_method("can_upgrade") or not facility.can_upgrade():
		upgrade_label.visible = false
		upgrade_button.visible = false
		return
	var cost: Dictionary = facility.get_upgrade_cost() if facility.has_method("get_upgrade_cost") else {}
	var parts: PackedStringArray = []
	var can_afford := true
	for resource_id in cost.keys():
		var need := int(cost[resource_id])
		var have: int = player.inventory.get_item_count(str(resource_id)) if player != null and player.inventory != null else 0
		parts.append("%s %d/%d" % [resource_id.replace("_", " ").capitalize(), have, need])
		if have < need:
			can_afford = false
	upgrade_label.text = "%s\nUpgrade Cost: %s" % [facility.get_upgrade_summary() if facility.has_method("get_upgrade_summary") else "", ", ".join(parts)]
	upgrade_label.visible = true
	upgrade_button.text = facility.get_upgrade_button_text() if facility.has_method("get_upgrade_button_text") else "Upgrade"
	upgrade_button.disabled = not can_afford
	upgrade_button.visible = true


func _on_upgrade_pressed() -> void:
	if facility == null or player == null or not facility.has_method("try_upgrade"):
		return
	if facility.try_upgrade(player):
		_refresh()
