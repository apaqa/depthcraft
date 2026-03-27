extends Control

## QuestBoardUI — full-screen overlay opened when the player interacts with a
## BountyBoardFacility.
##
## Add this node to your HUD / game scene and it will connect itself to
## QuestManager.board_open_requested automatically.
##
## Layout (built entirely in code — no .tscn required):
##
##   Control (this node, full screen, hidden by default)
##     ColorRect            ← dim background
##     PanelContainer       ← main window
##       MarginContainer
##         VBoxContainer
##           HBoxContainer  ← title bar
##           HSeparator
##           HBoxContainer  ← two columns
##             VBoxContainer  ← available bounties
##             VSeparator
##             VBoxContainer  ← active / accepted quests
##           HSeparator
##           HBoxContainer  ← bottom bar (Refresh + Close)

signal close_requested

const COLOR_GOLD: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_GREEN: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_GREY: Color = Color(0.65, 0.65, 0.65, 1.0)
const COLOR_RED: Color = Color(1.0, 0.4, 0.4, 1.0)
const COLOR_DIM_BG: Color = Color(0.0, 0.0, 0.0, 0.55)
const PANEL_MIN_SIZE: Vector2 = Vector2(820.0, 560.0)
const COLUMN_MIN_WIDTH: float = 360.0

# ---------------------------------------------------------------------------
# Node refs built in _setup_ui()
# ---------------------------------------------------------------------------

var _panel: PanelContainer = null
var _available_list: VBoxContainer = null
var _active_list: VBoxContainer = null
var _current_player: Node = null

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui()
	_connect_to_quest_manager()


func _setup_ui() -> void:
	# Dim background
	var dim: ColorRect = ColorRect.new()
	dim.color = COLOR_DIM_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Main panel — centred
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
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

	# ── Title bar ──
	var title_bar: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(title_bar)

	var title_lbl: Label = Label.new()
	title_lbl.text = "Bounty Board"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.self_modulate = COLOR_GOLD
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(_close)
	title_bar.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# ── Two-column body ──
	var body_hbox: HBoxContainer = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 12)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_hbox)

	# Left column — available bounties
	var left_col: VBoxContainer = _make_column("Available Bounties", body_hbox)
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(COLUMN_MIN_WIDTH, 0.0)
	left_col.add_child(left_scroll)
	_available_list = VBoxContainer.new()
	_available_list.add_theme_constant_override("separation", 8)
	_available_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_available_list)

	body_hbox.add_child(VSeparator.new())

	# Right column — accepted / active quests
	var right_col: VBoxContainer = _make_column("My Quests", body_hbox)
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(COLUMN_MIN_WIDTH, 0.0)
	right_col.add_child(right_scroll)
	_active_list = VBoxContainer.new()
	_active_list.add_theme_constant_override("separation", 8)
	_active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_active_list)

	root_vbox.add_child(HSeparator.new())

	# ── Bottom bar ──
	var bottom: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(bottom)

	var refresh_btn: Button = Button.new()
	refresh_btn.text = "Refresh Board"
	refresh_btn.custom_minimum_size = Vector2(140.0, 30.0)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	bottom.add_child(refresh_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var hint: Label = Label.new()
	hint.text = "Press Esc to close"
	hint.self_modulate = COLOR_GREY
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(hint)


func _make_column(header_text: String, parent: HBoxContainer) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var lbl: Label = Label.new()
	lbl.text = header_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.self_modulate = COLOR_GOLD
	col.add_child(lbl)

	col.add_child(HSeparator.new())
	return col


func _connect_to_quest_manager() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return
	if qm.has_signal("board_open_requested"):
		qm.board_open_requested.connect(_on_board_open_requested)
	if qm.has_signal("quest_accepted"):
		qm.quest_accepted.connect(_on_quest_state_changed)
	if qm.has_signal("quest_turned_in"):
		qm.quest_turned_in.connect(_on_quest_state_changed)
	if qm.has_signal("quest_progress_updated"):
		qm.quest_progress_updated.connect(_on_progress_updated)
	if qm.has_signal("quest_completed"):
		qm.quest_completed.connect(_on_quest_state_changed)


# ---------------------------------------------------------------------------
# Opening / closing
# ---------------------------------------------------------------------------

func open_for_board(player: Node) -> void:
	_current_player = player
	visible = true
	_rebuild()


func _close() -> void:
	if not visible:
		return
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


# ---------------------------------------------------------------------------
# Rebuild lists
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_available()
	_rebuild_active()


func _rebuild_available() -> void:
	for child: Node in _available_list.get_children():
		child.queue_free()

	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return

	var quests: Array[Dictionary] = qm.get_available_quests()
	if quests.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No bounties available.\nTry refreshing the board."
		empty_lbl.self_modulate = COLOR_GREY
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_available_list.add_child(empty_lbl)
		return

	for q: Dictionary in quests:
		_available_list.add_child(_build_available_row(q))


func _rebuild_active() -> void:
	for child: Node in _active_list.get_children():
		child.queue_free()

	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return

	var quests: Array[Dictionary] = qm.get_active_quests()
	if quests.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No active quests.\nAccept a bounty on the left!"
		empty_lbl.self_modulate = COLOR_GREY
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active_list.add_child(empty_lbl)
		return

	for q: Dictionary in quests:
		_active_list.add_child(_build_active_row(q))


# ---------------------------------------------------------------------------
# Row builders
# ---------------------------------------------------------------------------

func _build_available_row(q: Dictionary) -> Control:
	var quest_id: String = str(q.get("id", ""))

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	m.add_child(vbox)

	# Title + difficulty stars
	var title_lbl: Label = Label.new()
	var difficulty: int = int(q.get("difficulty", 1))
	var stars: String = "★".repeat(difficulty) + "☆".repeat(5 - difficulty)
	title_lbl.text = "%s  %s" % [str(q.get("title", "")), stars]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.self_modulate = COLOR_GOLD
	vbox.add_child(title_lbl)

	# Description
	var desc_lbl: Label = Label.new()
	desc_lbl.text = str(q.get("description", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Reward line
	var reward_lbl: Label = Label.new()
	var gold: int = int(q.get("reward_gold", 0))
	var shards: int = int(q.get("reward_shards", 0))
	reward_lbl.text = "Reward: %d Gold  +%d Shards" % [gold, shards]
	reward_lbl.self_modulate = COLOR_GREEN
	vbox.add_child(reward_lbl)

	# Accept button
	var accept_btn: Button = Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(90.0, 26.0)
	accept_btn.pressed.connect(_on_accept_pressed.bind(quest_id))
	vbox.add_child(accept_btn)

	return panel


func _build_active_row(q: Dictionary) -> Control:
	var quest_id: String = str(q.get("id", ""))
	var completed: bool = bool(q.get("completed", false))
	var progress: int = int(q.get("progress", 0))
	var goal: int = int(q.get("goal", 1))

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.self_modulate = Color(0.85, 1.0, 0.85, 1.0) if completed else Color(1.0, 1.0, 1.0, 1.0)

	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	m.add_child(vbox)

	# Title
	var title_lbl: Label = Label.new()
	title_lbl.text = str(q.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.self_modulate = COLOR_GOLD if completed else Color(0.95, 0.95, 0.95, 1.0)
	vbox.add_child(title_lbl)

	# Progress bar text
	var progress_lbl: Label = Label.new()
	var pct: float = clampf(float(progress) / float(maxi(goal, 1)), 0.0, 1.0)
	var bar_filled: int = int(pct * 20.0)
	var bar_str: String = "[".repeat(1) + "█".repeat(bar_filled) + "░".repeat(20 - bar_filled) + "]"
	progress_lbl.text = "%s  %d / %d" % [bar_str, progress, goal]
	progress_lbl.self_modulate = COLOR_GREEN if completed else COLOR_GREY
	vbox.add_child(progress_lbl)

	# Reward
	var reward_lbl: Label = Label.new()
	var gold: int = int(q.get("reward_gold", 0))
	var shards: int = int(q.get("reward_shards", 0))
	reward_lbl.text = "Reward: %d Gold  +%d Shards" % [gold, shards]
	reward_lbl.self_modulate = COLOR_GREEN if completed else COLOR_GREY
	vbox.add_child(reward_lbl)

	# Turn In button (enabled only when completed)
	var turnin_btn: Button = Button.new()
	turnin_btn.text = "Turn In" if completed else "In Progress…"
	turnin_btn.custom_minimum_size = Vector2(110.0, 26.0)
	turnin_btn.disabled = not completed
	turnin_btn.pressed.connect(_on_turn_in_pressed.bind(quest_id))
	vbox.add_child(turnin_btn)

	return panel


# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_accept_pressed(quest_id: String) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return
	if qm.has_method("accept_quest"):
		qm.accept_quest(quest_id)
	# Rebuild both lists immediately
	_rebuild()


func _on_turn_in_pressed(quest_id: String) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return
	if qm.has_method("turn_in_quest"):
		qm.turn_in_quest(quest_id, _current_player)
	_rebuild()


func _on_refresh_pressed() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return
	# refresh_available_quests() re-rolls using QuestManager's internal _current_day
	if qm.has_method("refresh_available_quests"):
		qm.refresh_available_quests()
	_rebuild()


# ---------------------------------------------------------------------------
# QuestManager signal callbacks
# ---------------------------------------------------------------------------

func _on_board_open_requested(player: Node) -> void:
	open_for_board(player)


func _on_quest_state_changed(_quest_id: String) -> void:
	if visible:
		_rebuild()


func _on_progress_updated(_quest_id: String, _progress: int, _goal: int) -> void:
	if visible:
		_rebuild_active()
