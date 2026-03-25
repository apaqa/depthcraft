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
	shard_label.text = "天賦碎片: %d" % player.inventory.get_item_count("talent_shard")
	for branch_id in TALENT_DATA.get_branch_ids():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(240, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var branch_box := VBoxContainer.new()
		branch_box.add_theme_constant_override("separation", 6)
		branch_box.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(branch_box)
		var title := Label.new()
		title.text = TALENT_DATA.get_branch_label(branch_id)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		branch_box.add_child(title)
		for talent in TALENT_DATA.get_branch_talents(branch_id):
			var button := Button.new()
			button.text = _build_talent_text(talent)
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.focus_mode = Control.FOCUS_ALL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(120, 60)
			if bool(talent.get("is_milestone", false)):
				button.modulate = Color(1, 0.85, 0.3)
				button.custom_minimum_size = Vector2(140, 80)
				var milestone_style := StyleBoxFlat.new()
				milestone_style.bg_color = Color(0.18, 0.14, 0.06, 1.0)
				milestone_style.border_width_left = 3
				milestone_style.border_width_top = 3
				milestone_style.border_width_right = 3
				milestone_style.border_width_bottom = 3
				milestone_style.border_color = Color(0.96, 0.82, 0.26, 1.0)
				milestone_style.corner_radius_top_left = 8
				milestone_style.corner_radius_top_right = 8
				milestone_style.corner_radius_bottom_left = 8
				milestone_style.corner_radius_bottom_right = 8
				button.add_theme_stylebox_override("normal", milestone_style)
				button.add_theme_stylebox_override("hover", milestone_style)
				button.add_theme_stylebox_override("pressed", milestone_style)
			var talent_id := str(talent.get("id", ""))
			if player.has_talent(talent_id):
				if not bool(talent.get("is_milestone", false)):
					button.modulate = Color(0.95, 0.9, 0.45, 1.0)
			elif TALENT_DATA.can_unlock(player.get_unlocked_talents(), player.inventory.get_item_count("talent_shard"), talent_id):
				if not bool(talent.get("is_milestone", false)):
					button.modulate = Color(0.6, 0.95, 0.6, 1.0)
			else:
				if not bool(talent.get("is_milestone", false)):
					button.modulate = Color(0.65, 0.65, 0.65, 1.0)
			button.pressed.connect(_on_talent_pressed.bind(talent_id))
			branch_box.add_child(button)
		branch_row.add_child(panel)


func _build_talent_text(talent: Dictionary) -> String:
	var talent_id := str(talent.get("id", ""))
	var milestone_prefix := "[里程碑]\n" if bool(talent.get("is_milestone", false)) else ""
	if player != null and player.has_talent(talent_id):
		return "%s%s\n已解鎖" % [milestone_prefix, str(talent.get("name", talent_id))]
	return "%s%s\n%s\n花費: %d" % [
		milestone_prefix,
		str(talent.get("name", talent_id)),
		str(talent.get("description", "")),
		int(talent.get("cost", 0)),
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
