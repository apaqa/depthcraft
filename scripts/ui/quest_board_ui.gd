extends Control
class_name QuestBoardUI

signal close_requested

const COLOR_GOLD: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_GREEN: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_GREY: Color = Color(0.65, 0.65, 0.65, 1.0)
const COLOR_DIM_BG: Color = Color(0.0, 0.0, 0.0, 0.55)
const PANEL_MIN_SIZE: Vector2 = Vector2(820.0, 560.0)
const COLUMN_MIN_WIDTH: float = 360.0

var _panel: PanelContainer = null
var _available_list: VBoxContainer = null
var _active_list: VBoxContainer = null
var _current_player: Node = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui()
	_connect_to_quest_manager()


func _setup_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = COLOR_DIM_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-PANEL_MIN_SIZE.x * 0.5, -PANEL_MIN_SIZE.y * 0.5)
	_panel.size = PANEL_MIN_SIZE
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var title_bar: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(title_bar)

	var title_label: Label = Label.new()
	title_label.text = "Bounty Board"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.self_modulate = COLOR_GOLD
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_label)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32.0, 32.0)
	close_button.pressed.connect(_close)
	title_bar.add_child(close_button)

	root_vbox.add_child(HSeparator.new())

	var body_hbox: HBoxContainer = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 12)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_hbox)

	var left_column: VBoxContainer = _make_column("Available Bounties", body_hbox)
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(COLUMN_MIN_WIDTH, 0.0)
	left_column.add_child(left_scroll)
	_available_list = VBoxContainer.new()
	_available_list.add_theme_constant_override("separation", 8)
	_available_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_available_list)

	body_hbox.add_child(VSeparator.new())

	var right_column: VBoxContainer = _make_column("My Quests", body_hbox)
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(COLUMN_MIN_WIDTH, 0.0)
	right_column.add_child(right_scroll)
	_active_list = VBoxContainer.new()
	_active_list.add_theme_constant_override("separation", 8)
	_active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_active_list)

	root_vbox.add_child(HSeparator.new())

	var bottom_bar: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(bottom_bar)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Board"
	refresh_button.custom_minimum_size = Vector2(140.0, 30.0)
	refresh_button.pressed.connect(_on_refresh_pressed)
	bottom_bar.add_child(refresh_button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	var hint_label: Label = Label.new()
	hint_label.text = "Press Esc to close"
	hint_label.self_modulate = COLOR_GREY
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_bar.add_child(hint_label)


func _make_column(header_text: String, parent: HBoxContainer) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)

	var header_label: Label = Label.new()
	header_label.text = header_text
	header_label.add_theme_font_size_override("font_size", 15)
	header_label.self_modulate = COLOR_GOLD
	column.add_child(header_label)

	column.add_child(HSeparator.new())
	return column


func _connect_to_quest_manager() -> void:
	var quest_manager: Node = get_node_or_null("/root/QuestManager")
	if quest_manager == null:
		return
	if quest_manager.has_signal("board_open_requested") and not quest_manager.board_open_requested.is_connected(_on_board_open_requested):
		quest_manager.board_open_requested.connect(_on_board_open_requested)
	if quest_manager.has_signal("quest_accepted") and not quest_manager.quest_accepted.is_connected(_on_quest_state_changed):
		quest_manager.quest_accepted.connect(_on_quest_state_changed)
	if quest_manager.has_signal("quest_turned_in") and not quest_manager.quest_turned_in.is_connected(_on_quest_state_changed):
		quest_manager.quest_turned_in.connect(_on_quest_state_changed)
	if quest_manager.has_signal("quest_completed") and not quest_manager.quest_completed.is_connected(_on_quest_state_changed):
		quest_manager.quest_completed.connect(_on_quest_state_changed)
	if quest_manager.has_signal("quest_progress_updated") and not quest_manager.quest_progress_updated.is_connected(_on_progress_updated):
		quest_manager.quest_progress_updated.connect(_on_progress_updated)


func open_for_board(player: Node) -> void:
	_current_player = player
	visible = true
	if _current_player != null and _current_player.has_method("set_ui_blocked"):
		_current_player.set_ui_blocked(true)
	_rebuild()


func close_menu() -> void:
	_close()


func _close() -> void:
	if not visible:
		return
	if _current_player != null and _current_player.has_method("set_ui_blocked"):
		_current_player.set_ui_blocked(false)
	visible = false
	_current_player = null
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	_rebuild_available()
	_rebuild_active()


func _rebuild_available() -> void:
	if _available_list == null:
		return
	for child: Node in _available_list.get_children():
		child.queue_free()

	var quests: Array[Dictionary] = QuestManager.get_available_quests()
	if quests.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No bounties available.\nTry refreshing the board."
		empty_label.self_modulate = COLOR_GREY
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_available_list.add_child(empty_label)
		return

	for quest: Dictionary in quests:
		_available_list.add_child(_build_available_row(quest))


func _rebuild_active() -> void:
	if _active_list == null:
		return
	for child: Node in _active_list.get_children():
		child.queue_free()

	var quests: Array[Dictionary] = QuestManager.get_active_quests()
	if quests.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No active quests.\nAccept a bounty on the left."
		empty_label.self_modulate = COLOR_GREY
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active_list.add_child(empty_label)
		return

	for quest: Dictionary in quests:
		_active_list.add_child(_build_active_row(quest))


func _build_available_row(quest: Dictionary) -> Control:
	var quest_id: String = str(quest.get("id", ""))
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title_label: Label = Label.new()
	var difficulty: int = int(quest.get("difficulty", 1))
	var star_count: int = clampi(difficulty, 0, 5)
	var stars: String = "*".repeat(star_count) + "-".repeat(5 - star_count)
	title_label.text = "%s  %s" % [str(quest.get("title", "")), stars]
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.self_modulate = COLOR_GOLD
	vbox.add_child(title_label)

	var description_label: Label = Label.new()
	description_label.text = str(quest.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description_label)

	var reward_label: Label = Label.new()
	var gold: int = int(quest.get("reward_gold", 0))
	var shards: int = int(quest.get("reward_shards", 0))
	reward_label.text = "Reward: %d Gold  +%d Shards" % [gold, shards]
	reward_label.self_modulate = COLOR_GREEN
	vbox.add_child(reward_label)

	var accept_button: Button = Button.new()
	accept_button.text = "Accept"
	accept_button.custom_minimum_size = Vector2(90.0, 26.0)
	accept_button.pressed.connect(_on_accept_pressed.bind(quest_id))
	vbox.add_child(accept_button)

	return panel


func _build_active_row(quest: Dictionary) -> Control:
	var quest_id: String = str(quest.get("id", ""))
	var completed: bool = bool(quest.get("completed", false))
	var progress: int = int(quest.get("progress", 0))
	var goal: int = int(quest.get("goal", 1))

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.self_modulate = Color(0.85, 1.0, 0.85, 1.0) if completed else Color(1.0, 1.0, 1.0, 1.0)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = str(quest.get("title", ""))
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.self_modulate = COLOR_GOLD if completed else Color(0.95, 0.95, 0.95, 1.0)
	vbox.add_child(title_label)

	var progress_label: Label = Label.new()
	var ratio: float = clampf(float(progress) / float(maxi(goal, 1)), 0.0, 1.0)
	var bar_filled: int = int(round(ratio * 20.0))
	var bar_string: String = "[" + "#".repeat(bar_filled) + "-".repeat(20 - bar_filled) + "]"
	progress_label.text = "%s  %d / %d" % [bar_string, progress, goal]
	progress_label.self_modulate = COLOR_GREEN if completed else COLOR_GREY
	vbox.add_child(progress_label)

	var reward_label: Label = Label.new()
	var gold: int = int(quest.get("reward_gold", 0))
	var shards: int = int(quest.get("reward_shards", 0))
	reward_label.text = "Reward: %d Gold  +%d Shards" % [gold, shards]
	reward_label.self_modulate = COLOR_GREEN if completed else COLOR_GREY
	vbox.add_child(reward_label)

	var turn_in_button: Button = Button.new()
	turn_in_button.text = "Turn In" if completed else "In Progress"
	turn_in_button.custom_minimum_size = Vector2(110.0, 26.0)
	turn_in_button.disabled = not completed
	turn_in_button.pressed.connect(_on_turn_in_pressed.bind(quest_id))
	vbox.add_child(turn_in_button)

	return panel


func _on_accept_pressed(quest_id: String) -> void:
	QuestManager.accept_quest(quest_id)
	_rebuild()


func _on_turn_in_pressed(quest_id: String) -> void:
	QuestManager.turn_in_quest(quest_id, _current_player)
	_rebuild()


func _on_refresh_pressed() -> void:
	if QuestManager.has_method("refresh_available_quests"):
		QuestManager.refresh_available_quests()
	_rebuild()


func _on_board_open_requested(player: Node) -> void:
	open_for_board(player)


func _on_quest_state_changed(_quest_id: String) -> void:
	if visible:
		_rebuild()


func _on_progress_updated(_quest_id: String, _progress: int, _goal: int) -> void:
	if visible:
		_rebuild_active()
