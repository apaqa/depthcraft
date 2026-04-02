extends Control

class TalentMapCanvas:
	extends Control

	var owner_ui: Variant = null

	func _draw() -> void:
		if owner_ui != null:
			owner_ui._draw_talent_map(self)


const TALENT_DATA = preload("res://scripts/talent/talent_data.gd")
const BRANCH_ICON_OFFENSE_OPEN: Texture2D = preload("res://assets/icons/kyrise/book_03g.png")
const BRANCH_ICON_OFFENSE_CLOSED: Texture2D = preload("res://assets/icons/kyrise/book_03a.png")
const BRANCH_ICON_DEFENSE_OPEN: Texture2D = preload("res://assets/icons/kyrise/book_04g.png")
const BRANCH_ICON_DEFENSE_CLOSED: Texture2D = preload("res://assets/icons/kyrise/book_04a.png")
const BRANCH_ICON_SUPPORT_OPEN: Texture2D = preload("res://assets/icons/kyrise/book_02g.png")
const BRANCH_ICON_SUPPORT_CLOSED: Texture2D = preload("res://assets/icons/kyrise/book_02a.png")

const BASE_MAP_SIZE = Vector2(6000, 4500)
const MAP_CENTER = Vector2(3000, 2250)
const NODE_SIZE = 68.0
const GLOW_SIZE = 92.0
const MAIN_STEP = 200.0
const SUB_STEP = 150.0
const MIN_ZOOM: float = 0.15
const MAX_ZOOM: float = 1.5
const ZOOM_STEP: float = 0.05
const MAP_BACKGROUND = Color(0.12, 0.14, 0.18, 0.95)
const LINE_LOCKED = Color(0.35, 0.38, 0.44, 0.45)
const LINE_AVAILABLE = Color(0.76, 0.86, 0.95, 1.0)
const LINE_UNLOCKED = Color(1.0, 0.82, 0.34, 1.0)

const BRANCH_MAIN_DIRECTIONS: Dictionary = {
	"offense": Vector2(-0.88, -0.62),
	"defense": Vector2(0.88, -0.62),
	"support": Vector2(0.0, 1.0),
	"ultimate": Vector2(0.0, -1.0),
}

const BRANCH_SPLIT_ANGLES: Dictionary = {
	"offense": [-0.55, 0.38],
	"defense": [0.55, -0.38],
	"support": [0.55, -0.55],
	"ultimate": [],
}

const BRANCH_COLORS: Dictionary = {
	"offense": Color(0.94, 0.42, 0.34, 1.0),
	"defense": Color(0.34, 0.66, 0.98, 1.0),
	"support": Color(0.42, 0.88, 0.56, 1.0),
	"ultimate": Color(0.9, 0.2, 0.2, 1.0),
}

const GEM_COLORS: Dictionary = {
	"talent_shard": Color(0.6, 0.3, 0.9, 1.0),
	"gem_green": Color(0.3, 0.85, 0.3, 1.0),
	"gem_blue": Color(0.3, 0.55, 1.0, 1.0),
	"gem_purple": Color(0.65, 0.3, 0.9, 1.0),
	"gem_red": Color(0.9, 0.2, 0.2, 1.0),
}

signal close_requested

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var upgrade_summary_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopBar/UpgradeBox/UpgradeSummary
@onready var upgrade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/UpgradeBox/UpgradeButton
@onready var offense_jump_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/BranchButtons/OffenseButton
@onready var defense_jump_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/BranchButtons/DefenseButton
@onready var support_jump_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/BranchButtons/SupportButton
@onready var shard_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopBar/ShardLabel
@onready var map_scroll: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/MapPanel/ScrollContainer
@onready var map_root: Control = $PanelContainer/MarginContainer/VBoxContainer/MapPanel/ScrollContainer/MapRoot
@onready var detail_panel: PanelContainer = $PanelContainer/TalentDetail
@onready var detail_title: Label = $PanelContainer/TalentDetail/MarginContainer/VBoxContainer/TitleLabel
@onready var detail_desc: RichTextLabel = $PanelContainer/TalentDetail/MarginContainer/VBoxContainer/DescriptionLabel
@onready var detail_cost: Label = $PanelContainer/TalentDetail/MarginContainer/VBoxContainer/CostLabel
@onready var detail_unlock_button: Button = $PanelContainer/TalentDetail/MarginContainer/VBoxContainer/UnlockButton

var player = null
var facility = null
var selected_talent_id: String = ""
var map_canvas: TalentMapCanvas = null
var node_positions: Dictionary = {}
var node_widgets: Dictionary = {}
var branch_focus_points: Dictionary = {}
var zoom_level: float = 1.0
var _ultimate_overlay: Control = null
var _gem_overlay: Panel = null
var _gem_labels: Array[Label] = []
var _detail_backdrop: ColorRect = null
var dragging_map: bool = false
var last_drag_position: Vector2 = Vector2.ZERO
var _reset_confirm_dialog: ConfirmationDialog = null
var _zoom_label: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = LocaleManager.L("title_talents")
	title_label.add_theme_font_size_override("font_size", 22)
	map_root.custom_minimum_size = BASE_MAP_SIZE
	map_root.size = BASE_MAP_SIZE
	_build_map_canvas()
	_setup_top_controls()
	_build_unified_top_bar()
	_setup_detail_panel()
	_update_zoom()
	var tt_style: StyleBoxFlat = StyleBoxFlat.new()
	tt_style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	tt_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	tt_style.border_width_left = 1
	tt_style.border_width_top = 1
	tt_style.border_width_right = 1
	tt_style.border_width_bottom = 1
	panel_container.add_theme_stylebox_override("panel", tt_style)
	_setup_zoom_controls()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_close_btn_pos()


func open_for_player(target_player, target_facility = null) -> void:
	player = target_player
	facility = target_facility
	visible = true
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	zoom_level = 0.4
	_update_zoom()
	_refresh()
	_center_on_point.call_deferred(MAP_CENTER)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	dragging_map = false
	_close_detail_panel()
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(false)
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		if _ultimate_overlay != null and _ultimate_overlay.visible:
			_ultimate_overlay.visible = false
		elif detail_panel.visible:
			_close_detail_panel()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


func _build_map_canvas() -> void:
	if map_canvas != null:
		map_canvas.queue_free()
	map_canvas = TalentMapCanvas.new()
	map_canvas.name = "MapCanvas"
	map_canvas.owner_ui = self
	map_canvas.custom_minimum_size = BASE_MAP_SIZE
	map_canvas.size = BASE_MAP_SIZE
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_root.add_child(map_canvas)


func _setup_top_controls() -> void:
	# Hide all old scene-defined top controls; unified top bar replaces them
	upgrade_summary_label.visible = false
	upgrade_button.visible = false
	upgrade_summary_label.get_parent().visible = false
	title_label.visible = false
	shard_label.visible = false
	offense_jump_button.get_parent().get_parent().visible = false  # TopBar HBoxContainer
	map_scroll.gui_input.connect(_on_map_gui_input)


func _build_unified_top_bar() -> void:
	var vbox: VBoxContainer = title_label.get_parent() as VBoxContainer
	if vbox == null or vbox.get_node_or_null("UnifiedTopBar") != null:
		return
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "UnifiedTopBar"
	bar.custom_minimum_size = Vector2(0, 28)
	bar.add_theme_constant_override("separation", 6)
	# X close button
	var close_btn: Button = Button.new()
	close_btn.name = "UnifiedCloseBtn"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(close_menu)
	bar.add_child(close_btn)
	# Title
	var title_lbl: Label = Label.new()
	title_lbl.name = "UnifiedTitle"
	title_lbl.text = LocaleManager.L("title_talents")
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title_lbl)
	# Separator
	bar.add_child(VSeparator.new())
	# Branch tab buttons
	var branch_defs: Array = [
		["offense", _jump_to_branch.bind("offense")],
		["defense", _jump_to_branch.bind("defense")],
		["support", _jump_to_branch.bind("support")],
		["ultimate", _toggle_ultimate_overlay],
	]
	for branch_def: Array in branch_defs:
		var branch_id: String = str(branch_def[0])
		var btn: Button = Button.new()
		btn.text = LocaleManager.L(TALENT_DATA.get_branch_label(branch_id))
		btn.custom_minimum_size = Vector2(0, 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(branch_def[1] as Callable)
		var btn_color: Color = BRANCH_COLORS.get(branch_id, Color.WHITE) as Color
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = btn_color.darkened(0.55)
		btn_style.border_color = btn_color
		btn_style.border_width_left = 1
		btn_style.border_width_top = 1
		btn_style.border_width_right = 1
		btn_style.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", btn_style)
		bar.add_child(btn)
	# Separator
	bar.add_child(VSeparator.new())
	# Gem count row
	_gem_labels.clear()
	var gem_defs: Array = [
		["talent_shard", "綠"],
		["gem_blue", "藍"],
		["gem_purple", "紫"],
		["gem_red", "紅"],
	]
	for gem_def: Array in gem_defs:
		var gem_key: String = str(gem_def[0])
		var gem_char: String = str(gem_def[1])
		var gem_color: Color = GEM_COLORS.get(gem_key, Color.WHITE) as Color
		var dot: ColorRect = ColorRect.new()
		dot.color = gem_color
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(dot)
		var count_lbl: Label = Label.new()
		count_lbl.text = gem_char + "0"
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", gem_color)
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(count_lbl)
		_gem_labels.append(count_lbl)
	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	# Reset button
	var reset_btn: Button = Button.new()
	reset_btn.name = "UnifiedResetBtn"
	reset_btn.text = "重置天賦"
	reset_btn.custom_minimum_size = Vector2(0, 28)
	reset_btn.add_theme_font_size_override("font_size", 12)
	var reset_style: StyleBoxFlat = StyleBoxFlat.new()
	reset_style.bg_color = Color(0.42, 0.12, 0.12, 0.95)
	reset_style.border_color = Color(0.75, 0.28, 0.28, 1.0)
	reset_style.border_width_left = 1
	reset_style.border_width_top = 1
	reset_style.border_width_right = 1
	reset_style.border_width_bottom = 1
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.pressed.connect(_on_reset_button_pressed)
	bar.add_child(reset_btn)
	# Insert as first child of VBoxContainer
	vbox.add_child(bar)
	vbox.move_child(bar, 0)
	# Confirm dialog
	if _reset_confirm_dialog == null:
		_reset_confirm_dialog = ConfirmationDialog.new()
		_reset_confirm_dialog.title = "確認重置"
		_reset_confirm_dialog.dialog_text = "重置所有天賦？將返還 90% 的各色寶石（含天賦碎片）。"
		_reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
		add_child(_reset_confirm_dialog)


func _setup_detail_panel() -> void:
	detail_desc.bbcode_enabled = true
	detail_desc.fit_content = true
	detail_unlock_button.pressed.connect(_on_detail_unlock_pressed)
	detail_unlock_button.custom_minimum_size = Vector2(120, 36)
	detail_panel.visible = false
	# Reposition to center of panel_container
	detail_panel.anchor_left = 0.5
	detail_panel.anchor_top = 0.5
	detail_panel.anchor_right = 0.5
	detail_panel.anchor_bottom = 0.5
	detail_panel.offset_left = -200.0
	detail_panel.offset_top = -140.0
	detail_panel.offset_right = 200.0
	detail_panel.offset_bottom = 140.0
	# Style the detail panel for visual clarity
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.97)
	panel_style.border_color = Color(0.60, 0.44, 0.22, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	detail_panel.add_theme_stylebox_override("panel", panel_style)
	# Backdrop — full panel_container dimmer, click to close
	_detail_backdrop = ColorRect.new()
	_detail_backdrop.name = "DetailBackdrop"
	_detail_backdrop.layout_mode = 0
	_detail_backdrop.anchor_left = 0.0
	_detail_backdrop.anchor_top = 0.0
	_detail_backdrop.anchor_right = 1.0
	_detail_backdrop.anchor_bottom = 1.0
	_detail_backdrop.color = Color(0.0, 0.0, 0.0, 0.35)
	_detail_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_backdrop.visible = false
	_detail_backdrop.z_index = detail_panel.z_index - 1
	_detail_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_detail_panel()
	)
	panel_container.add_child(_detail_backdrop)
	panel_container.move_child(_detail_backdrop, detail_panel.get_index())


func _refresh() -> void:
	if player == null:
		return
	var green_count: int = player.inventory.get_item_count("talent_shard")
	var blue_count: int = player.inventory.get_item_count("gem_blue")
	var purple_count: int = player.inventory.get_item_count("gem_purple")
	var red_count: int = player.inventory.get_item_count("gem_red")
	var gem_counts_arr: Array[int] = [green_count, blue_count, purple_count, red_count]
	var gem_chars: Array[String] = ["綠", "藍", "紫", "紅"]
	for i: int in range(mini(_gem_labels.size(), gem_counts_arr.size())):
		_gem_labels[i].text = gem_chars[i] + str(gem_counts_arr[i])
	_refresh_upgrade_controls()
	_rebuild_map()
	if _ultimate_overlay != null and _ultimate_overlay.visible:
		_refresh_ultimate_overlay()
	if selected_talent_id != "":
		_show_talent_detail(selected_talent_id)
	else:
		detail_panel.visible = false
		if _detail_backdrop != null:
			_detail_backdrop.visible = false


func _rebuild_map() -> void:
	for child in map_canvas.get_children():
		child.queue_free()
	node_positions.clear()
	node_widgets.clear()
	branch_focus_points.clear()
	# Tweens bound to freed nodes stop automatically; just clear our refs

	_build_branch_positions()
	_add_branch_markers()
	_add_nodes()
	map_canvas.queue_redraw()


func _build_branch_positions() -> void:
	for branch_id in TALENT_DATA.get_branch_ids():
		if branch_id == "ultimate":
			continue
		var main_direction: Vector2 = (BRANCH_MAIN_DIRECTIONS.get(branch_id, Vector2.UP) as Vector2).normalized()
		var main_talents: Array[Dictionary] = TALENT_DATA.get_sub_branch_talents(branch_id, "main")
		if main_talents.is_empty():
			continue
		for talent in main_talents:
			var sequence: int = int(talent.get("sequence", 0))
			node_positions[str(talent.get("id", ""))] = MAP_CENTER + main_direction * MAIN_STEP * float(sequence)

		var fork_talent_id: String = "%s5" % _branch_prefix(branch_id)
		var fork_position: Vector2 = MAP_CENTER + main_direction * MAIN_STEP * 5.0
		if node_positions.has(fork_talent_id):
			fork_position = node_positions[fork_talent_id]
		branch_focus_points[branch_id] = MAP_CENTER + main_direction * MAIN_STEP * 6.0
		var split_angles: Array = BRANCH_SPLIT_ANGLES.get(branch_id, [0.45, -0.45])
		var sub_branch_ids: PackedStringArray = TALENT_DATA.get_sub_branch_ids(branch_id)
		for index in range(sub_branch_ids.size()):
			var sub_branch_id: String = sub_branch_ids[index]
			var branch_direction: Vector2 = main_direction.rotated(float(split_angles[index])).normalized()
			var sub_talents: Array[Dictionary] = TALENT_DATA.get_sub_branch_talents(branch_id, sub_branch_id)
			for talent in sub_talents:
				var sequence: int = int(talent.get("sequence", 0))
				node_positions[str(talent.get("id", ""))] = fork_position + branch_direction * SUB_STEP * float(sequence)


func _add_branch_markers() -> void:
	for branch_id in TALENT_DATA.get_branch_ids():
		if branch_id == "ultimate":
			continue
		var label: Label = Label.new()
		var branch_color: Color = Color.WHITE
		if BRANCH_COLORS.has(branch_id):
			branch_color = BRANCH_COLORS[branch_id]
		var branch_point: Vector2 = MAP_CENTER
		if branch_focus_points.has(branch_id):
			branch_point = branch_focus_points[branch_id]
		label.text = LocaleManager.L(TALENT_DATA.get_branch_label(branch_id))
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", branch_color)
		label.position = branch_point - Vector2(80, 120)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(label)


func _add_nodes() -> void:
	for talent in TALENT_DATA.get_all_talents():
		_create_node_widget(talent)


func _create_node_widget(talent: Dictionary) -> void:
	var talent_id: String = str(talent.get("id", ""))
	if not node_positions.has(talent_id):
		return

	var wrapper: Control = Control.new()
	wrapper.name = "%sWrapper" % talent_id
	wrapper.custom_minimum_size = Vector2(148, 122)
	wrapper.size = wrapper.custom_minimum_size
	wrapper.position = (node_positions[talent_id] as Vector2) - Vector2(wrapper.size.x * 0.5, 40.0)
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	var glow: Panel = Panel.new()
	glow.name = "Glow"
	glow.position = Vector2((wrapper.size.x - GLOW_SIZE) * 0.5, -12.0)
	glow.custom_minimum_size = Vector2(GLOW_SIZE, GLOW_SIZE)
	glow.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _make_circle_style(Color(1.0, 0.82, 0.34, 0.18), Color(1.0, 0.82, 0.34, 0.4), 2))
	glow.visible = false
	wrapper.add_child(glow)

	var button: Button = Button.new()
	button.name = "NodeButton"
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.position = Vector2((wrapper.size.x - NODE_SIZE) * 0.5, 0.0)
	button.pressed.connect(_on_talent_selected.bind(talent_id))
	button.tooltip_text = LocaleManager.L(str(talent.get("name", talent_id)))
	wrapper.add_child(button)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "NodeIcon"
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.size = icon_rect.custom_minimum_size
	icon_rect.position = button.position + Vector2((NODE_SIZE - icon_rect.size.x) * 0.5, (NODE_SIZE - icon_rect.size.y) * 0.5)
	icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(icon_rect)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.custom_minimum_size = Vector2(wrapper.size.x, 44)
	name_label.size = name_label.custom_minimum_size
	name_label.position = Vector2(0.0, NODE_SIZE + 6.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = LocaleManager.L(str(talent.get("name", talent_id)))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(name_label)

	map_canvas.add_child(wrapper)
	node_widgets[talent_id] = wrapper
	_apply_node_visuals(talent)


func _apply_node_visuals(talent: Dictionary) -> void:
	var talent_id: String = str(talent.get("id", ""))
	var wrapper: Control = node_widgets.get(talent_id, null)
	if wrapper == null:
		return
	var button: Button = wrapper.get_node("NodeButton") as Button
	var glow: Panel = wrapper.get_node("Glow") as Panel
	var icon_rect: TextureRect = wrapper.get_node("NodeIcon") as TextureRect
	var name_label: Label = wrapper.get_node("NameLabel") as Label
	var state: String = _get_talent_state(talent_id)
	var branch_id: String = str(talent.get("branch", ""))
	var gem_type: String = str(talent.get("gem_type", "talent_shard"))
	var branch_color: Color = Color(0.75, 0.75, 0.75, 1.0)
	if BRANCH_COLORS.has(branch_id):
		branch_color = BRANCH_COLORS[branch_id]
	var gem_color: Color = GEM_COLORS.get(gem_type, branch_color) as Color

	var fill_color: Color = Color(0.32, 0.34, 0.40, 1.0)
	var border_color: Color = Color(0.50, 0.54, 0.62, 1.0)
	var label_color: Color = Color(0.72, 0.74, 0.80, 1.0)
	glow.visible = false
	# Kill any existing pulse tween
	if wrapper.has_meta("_pulse_tween"):
		var old_tween: Tween = wrapper.get_meta("_pulse_tween") as Tween
		if old_tween != null and is_instance_valid(old_tween):
			old_tween.kill()
		wrapper.remove_meta("_pulse_tween")
	wrapper.modulate = Color.WHITE

	if state == "available":
		fill_color = gem_color.lerp(Color.WHITE, 0.22)
		border_color = gem_color.lightened(0.35)
		label_color = Color.WHITE
		var pulse_tween: Tween = wrapper.create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(wrapper, "modulate:a", 0.65, 0.7)
		pulse_tween.tween_property(wrapper, "modulate:a", 1.0, 0.7)
		wrapper.set_meta("_pulse_tween", pulse_tween)
	elif state == "unlocked":
		if gem_type == "gem_red":
			fill_color = Color(0.6, 0.12, 0.12, 1.0)
			border_color = Color(1.0, 0.55, 0.2, 1.0)
			label_color = Color(1.0, 0.75, 0.35, 1.0)
		else:
			fill_color = Color(0.94, 0.76, 0.26, 1.0)
			border_color = Color(1.0, 0.93, 0.66, 1.0)
			label_color = Color(1.0, 0.88, 0.46, 1.0)
		glow.visible = true

	if selected_talent_id == talent_id:
		border_color = Color.WHITE

	button.add_theme_stylebox_override("normal", _make_circle_style(fill_color, border_color, 3))
	button.add_theme_stylebox_override("hover", _make_circle_style(fill_color.lightened(0.08), Color.WHITE, 3))
	button.add_theme_stylebox_override("pressed", _make_circle_style(fill_color.darkened(0.08), Color.WHITE, 3))
	button.add_theme_stylebox_override("focus", _make_circle_style(fill_color, Color.WHITE, 4))
	if icon_rect != null:
		icon_rect.texture = _get_branch_icon(branch_id, state)
		if state == "locked":
			icon_rect.modulate = Color(0.55, 0.55, 0.55, 0.8)
		else:
			icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	name_label.add_theme_color_override("font_color", label_color)
	name_label.add_theme_font_size_override("font_size", 13)


func _get_branch_icon(branch_id: String, state: String) -> Texture2D:
	var is_open: bool = state == "unlocked"
	match branch_id:
		"offense":
			return BRANCH_ICON_OFFENSE_OPEN if is_open else BRANCH_ICON_OFFENSE_CLOSED
		"defense":
			return BRANCH_ICON_DEFENSE_OPEN if is_open else BRANCH_ICON_DEFENSE_CLOSED
		"support":
			return BRANCH_ICON_SUPPORT_OPEN if is_open else BRANCH_ICON_SUPPORT_CLOSED
		_:
			return BRANCH_ICON_DEFENSE_OPEN if is_open else BRANCH_ICON_DEFENSE_CLOSED


func _make_circle_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	return style


func _draw_talent_map(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, BASE_MAP_SIZE), MAP_BACKGROUND, true)
	canvas.draw_circle(MAP_CENTER, 28.0, Color(0.22, 0.24, 0.30, 1.0))
	canvas.draw_circle(MAP_CENTER, 22.0, Color(0.95, 0.95, 0.98, 0.18))

	for branch_id in TALENT_DATA.get_branch_ids():
		if branch_id == "ultimate":
			continue
		var first_talent: Dictionary = TALENT_DATA.get_talent("%s1" % _branch_prefix(branch_id))
		if not first_talent.is_empty():
			_draw_connection(canvas, "", str(first_talent.get("id", "")), branch_id)

	for talent in TALENT_DATA.get_all_talents():
		var talent_id: String = str(talent.get("id", ""))
		var prerequisite: String = str(talent.get("prerequisite", ""))
		if prerequisite == "":
			continue
		_draw_connection(canvas, prerequisite, talent_id, str(talent.get("branch", "")))


func _draw_connection(canvas: Control, from_id: String, to_id: String, branch_id: String) -> void:
	var from_point: Vector2 = MAP_CENTER
	if from_id != "" and node_positions.has(from_id):
		from_point = node_positions[from_id]
	var to_point: Vector2 = MAP_CENTER
	if node_positions.has(to_id):
		to_point = node_positions[to_id]
	var branch_color: Color = Color(0.6, 0.64, 0.72, 1.0)
	if BRANCH_COLORS.has(branch_id):
		branch_color = BRANCH_COLORS[branch_id] as Color
	var line_color: Color = branch_color.darkened(0.4)
	line_color.a = 0.45
	var line_width: float = 3.0
	var is_from_unlocked: bool = player != null and (from_id == "" or player.has_talent(from_id))
	var is_to_unlocked: bool = player != null and player.has_talent(to_id)
	if is_to_unlocked:
		line_color = LINE_UNLOCKED
		line_width = 6.0
	elif is_from_unlocked:
		line_color = branch_color
		line_color.a = 0.9
		line_width = 4.5
	canvas.draw_line(from_point, to_point, line_color, line_width, true)
	var dot_color: Color = branch_color if is_from_unlocked else branch_color.darkened(0.3)
	dot_color.a = 0.7 if not is_from_unlocked else 1.0
	canvas.draw_circle(to_point, 4.0, dot_color)


func _branch_prefix(branch_id: String) -> String:
	match branch_id:
		"offense":
			return "O"
		"defense":
			return "D"
		"support":
			return "S"
	return branch_id.left(1).to_upper()


func _get_talent_state(talent_id: String) -> String:
	if player == null:
		return "locked"
	if player.has_talent(talent_id):
		return "unlocked"
	var unlocked: Array[String] = player.get_unlocked_talents()
	var gem_counts: Dictionary = {
		"talent_shard": player.inventory.get_item_count("talent_shard"),
		"gem_green": player.inventory.get_item_count("gem_green"),
		"gem_blue": player.inventory.get_item_count("gem_blue"),
		"gem_purple": player.inventory.get_item_count("gem_purple"),
		"gem_red": player.inventory.get_item_count("gem_red"),
	}
	if TALENT_DATA.can_unlock(unlocked, gem_counts, talent_id):
		return "available"
	return "locked"


func _on_talent_selected(talent_id: String) -> void:
	selected_talent_id = talent_id
	_show_talent_detail(talent_id)
	for talent in TALENT_DATA.get_all_talents():
		_apply_node_visuals(talent)
	map_canvas.queue_redraw()


func _show_talent_detail(talent_id: String) -> void:
	var talent: Dictionary = TALENT_DATA.get_talent(talent_id)
	if talent.is_empty():
		detail_panel.visible = false
		return

	# Title — enlarged font for prominence
	detail_title.text = LocaleManager.L(str(talent.get("name", talent_id)))
	detail_title.add_theme_font_size_override("font_size", 20)

	# Description via BBCode
	var description: String = LocaleManager.L(str(talent.get("description", "")))
	detail_desc.text = "[p]%s[/p]" % description

	# Cost — colour-coded by affordability
	var cost_amount: int = int(talent.get("cost", 0))
	var gem_type: String = str(talent.get("gem_type", "talent_shard"))
	var gem_name_key: String = "gem_%s_short" % gem_type
	var gem_display: String = LocaleManager.L(gem_name_key) if gem_name_key != "gem_talent_shard_short" else LocaleManager.L("talent_shards_short")
	var current_gems: int = player.inventory.get_item_count(gem_type) if player != null else 0
	detail_cost.text = "%s %d  (%d / %d)" % [gem_display, cost_amount, current_gems, cost_amount]
	detail_cost.modulate = Color(0.45, 1.0, 0.45, 1.0) if current_gems >= cost_amount else Color(1.0, 0.45, 0.45, 1.0)
	var gem_node_color: Color = GEM_COLORS.get(gem_type, Color.WHITE) as Color
	detail_cost.add_theme_color_override("font_color", gem_node_color if current_gems >= cost_amount else Color(1.0, 0.45, 0.45, 1.0))

	# Unlock button — state-driven styling
	var state: String = _get_talent_state(talent_id)
	if state == "unlocked":
		detail_unlock_button.text = LocaleManager.L("talent_unlocked")
		detail_unlock_button.disabled = true
		detail_unlock_button.modulate = Color(0.6, 0.6, 0.6, 1.0)
	elif state == "available":
		detail_unlock_button.text = LocaleManager.L("unlock_button")
		detail_unlock_button.disabled = false
		detail_unlock_button.modulate = Color(0.45, 1.0, 0.45, 1.0)
	else:
		detail_unlock_button.text = LocaleManager.L("unlock_button")
		detail_unlock_button.disabled = true
		detail_unlock_button.modulate = Color(0.55, 0.55, 0.55, 1.0)

	if _detail_backdrop != null:
		_detail_backdrop.visible = true
	detail_panel.visible = true


func _close_detail_panel() -> void:
	selected_talent_id = ""
	detail_panel.visible = false
	if _detail_backdrop != null:
		_detail_backdrop.visible = false
	for talent: Dictionary in TALENT_DATA.get_all_talents():
		_apply_node_visuals(talent)
	map_canvas.queue_redraw()


func _on_detail_unlock_pressed() -> void:
	if selected_talent_id == "" or player == null:
		return
	var unlocked_id: String = selected_talent_id
	if player.unlock_talent(unlocked_id):
		if player.has_method("show_status_message"):
			var talent: Dictionary = TALENT_DATA.get_talent(unlocked_id)
			var talent_name: String = LocaleManager.L(str(talent.get("name", unlocked_id)))
			player.show_status_message(LocaleManager.L("talent_unlocked") + ": " + talent_name, Color(1.0, 0.88, 0.3, 1.0), 1.5)
		_close_detail_panel()
		_refresh()


func _refresh_upgrade_controls() -> void:
	upgrade_summary_label.visible = false
	upgrade_button.visible = false
	if true:
		return

	var cost: Dictionary = facility.get_upgrade_cost() if facility.has_method("get_upgrade_cost") else {}
	var parts: PackedStringArray = []
	var can_afford: bool = true
	for resource_id_variant in cost.keys():
		var resource_id: String = str(resource_id_variant)
		var need: int = int(cost[resource_id_variant])
		var have: int = player.inventory.get_item_count(resource_id) if player != null and player.inventory != null else 0
		parts.append("%s %d/%d" % [resource_id.replace("_", " ").capitalize(), have, need])
		if have < need:
			can_afford = false

	var summary: String = facility.get_upgrade_summary() if facility.has_method("get_upgrade_summary") else ""
	upgrade_summary_label.text = "%s %s" % [summary, ", ".join(parts)]
	upgrade_summary_label.visible = true
	upgrade_button.text = facility.get_upgrade_button_text() if facility.has_method("get_upgrade_button_text") else "Upgrade to Lv2"
	upgrade_button.disabled = not can_afford
	upgrade_button.visible = true


func _on_upgrade_pressed() -> void:
	if facility == null or player == null or not facility.has_method("try_upgrade"):
		return
	if facility.try_upgrade(player):
		_refresh()


func _jump_to_branch(branch_id: String) -> void:
	var branch_point: Vector2 = MAP_CENTER
	if branch_focus_points.has(branch_id):
		branch_point = branch_focus_points[branch_id]
	_center_on_point(branch_point)


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_map = mouse_button.pressed
			last_drag_position = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(zoom_level + ZOOM_STEP, mouse_button.position)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom_level - ZOOM_STEP, mouse_button.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging_map:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mouse_motion.position - last_drag_position
		last_drag_position = mouse_motion.position
		_set_scroll(Vector2(map_scroll.scroll_horizontal, map_scroll.scroll_vertical) - delta)


func _apply_zoom(target_zoom: float, pivot_in_scroll: Vector2) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, zoom_level):
		return
	var content_point: Vector2 = (Vector2(map_scroll.scroll_horizontal, map_scroll.scroll_vertical) + pivot_in_scroll) / old_zoom
	_update_zoom()
	_set_scroll(content_point * zoom_level - pivot_in_scroll)


func _update_zoom() -> void:
	if map_canvas == null:
		return
	var scaled_size: Vector2 = BASE_MAP_SIZE * zoom_level
	map_root.custom_minimum_size = scaled_size
	map_root.size = scaled_size
	map_canvas.scale = Vector2.ONE * zoom_level
	map_canvas.size = BASE_MAP_SIZE
	map_canvas.position = Vector2.ZERO
	map_canvas.queue_redraw()
	var show_labels: bool = zoom_level >= 0.3
	for wrapper_variant: Variant in node_widgets.values():
		var wrapper: Control = wrapper_variant as Control
		if wrapper == null:
			continue
		var name_lbl: Label = wrapper.get_node_or_null("NameLabel") as Label
		if name_lbl != null:
			name_lbl.visible = show_labels
	_update_zoom_label()


func _center_on_point(map_point: Vector2) -> void:
	var viewport_size: Vector2 = map_scroll.size
	_set_scroll(map_point * zoom_level - viewport_size * 0.5)


func _set_scroll(target_scroll: Vector2) -> void:
	var max_scroll_x: float = maxf(0.0, map_root.size.x - map_scroll.size.x)
	var max_scroll_y: float = maxf(0.0, map_root.size.y - map_scroll.size.y)
	map_scroll.scroll_horizontal = int(clampf(target_scroll.x, 0.0, max_scroll_x))
	map_scroll.scroll_vertical = int(clampf(target_scroll.y, 0.0, max_scroll_y))


func _update_close_btn_pos() -> void:
	var close_btn: Button = get_node_or_null("CloseButton") as Button
	if close_btn != null:
		close_btn.position = panel_container.position + Vector2(8, 8)


func _ensure_close_button() -> void:
	if panel_container == null or get_node_or_null("CloseButton") != null:
		return
	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = panel_container.position + Vector2(8, 8)
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.size = Vector2(32, 32)
	close_button.z_index = 100
	close_button.pressed.connect(close_menu)
	add_child(close_button)
	_update_close_btn_pos.call_deferred()


func _setup_reset_button() -> void:
	var top_bar: HBoxContainer = panel_container.get_node_or_null("MarginContainer/VBoxContainer/TopBar") as HBoxContainer
	if top_bar == null or top_bar.get_node_or_null("ResetButton") != null:
		return
	var reset_btn: Button = Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "重置天賦"
	reset_btn.custom_minimum_size = Vector2(0, 28)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(_on_reset_button_pressed)
	var reset_style_normal: StyleBoxFlat = StyleBoxFlat.new()
	reset_style_normal.bg_color = Color(0.42, 0.12, 0.12, 0.95)
	reset_style_normal.border_color = Color(0.75, 0.28, 0.28, 1.0)
	reset_style_normal.border_width_left = 1
	reset_style_normal.border_width_top = 1
	reset_style_normal.border_width_right = 1
	reset_style_normal.border_width_bottom = 1
	var reset_style_hover: StyleBoxFlat = reset_style_normal.duplicate() as StyleBoxFlat
	reset_style_hover.bg_color = Color(0.58, 0.18, 0.18, 0.95)
	reset_btn.add_theme_stylebox_override("normal", reset_style_normal)
	reset_btn.add_theme_stylebox_override("hover", reset_style_hover)
	top_bar.add_child(reset_btn)

	_reset_confirm_dialog = ConfirmationDialog.new()
	_reset_confirm_dialog.title = "確認重置"
	_reset_confirm_dialog.dialog_text = "重置所有天賦？將返還 90% 的各色寶石（含天賦碎片）。"
	_reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(_reset_confirm_dialog)


func _on_reset_button_pressed() -> void:
	if player == null:
		return
	var unlocked_count: int = player.get_unlocked_talents().size()
	if unlocked_count == 0:
		return
	if _reset_confirm_dialog != null:
		_reset_confirm_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	if player == null:
		return
	if player.has_method("reset_all_talents"):
		player.reset_all_talents()
	_refresh()


func _setup_zoom_controls() -> void:
	_update_zoom_label()


func _build_gem_overlay() -> void:
	if _gem_overlay != null:
		return
	_gem_overlay = Panel.new()
	_gem_overlay.name = "GemOverlay"
	_gem_overlay.layout_mode = 0
	_gem_overlay.anchor_left = 0.0
	_gem_overlay.anchor_top = 0.0
	_gem_overlay.anchor_right = 0.0
	_gem_overlay.anchor_bottom = 0.0
	_gem_overlay.offset_left = 20.0
	_gem_overlay.offset_top = 86.0
	_gem_overlay.offset_right = 110.0
	_gem_overlay.offset_bottom = 166.0
	_gem_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem_overlay.z_index = 10
	var ov_style: StyleBoxFlat = StyleBoxFlat.new()
	ov_style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	ov_style.corner_radius_top_left = 4
	ov_style.corner_radius_top_right = 4
	ov_style.corner_radius_bottom_left = 4
	ov_style.corner_radius_bottom_right = 4
	_gem_overlay.add_theme_stylebox_override("panel", ov_style)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "GemVBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6.0
	vbox.offset_top = 4.0
	vbox.offset_right = -6.0
	vbox.offset_bottom = -4.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem_overlay.add_child(vbox)
	var gem_keys: Array[String] = ["talent_shard", "gem_blue", "gem_purple", "gem_red"]
	_gem_labels.clear()
	for gem_key: String in gem_keys:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = GEM_COLORS.get(gem_key, Color.WHITE) as Color
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var lbl: Label = Label.new()
		lbl.text = "0"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
		vbox.add_child(row)
		_gem_labels.append(lbl)
	panel_container.add_child(_gem_overlay)


func _update_zoom_label() -> void:
	if _zoom_label == null:
		return
	_zoom_label.text = "%d%%" % int(zoom_level * 100.0)


func _reset_view() -> void:
	zoom_level = 0.4
	_update_zoom()
	_center_on_point(MAP_CENTER)


func _toggle_ultimate_overlay() -> void:
	if _ultimate_overlay == null:
		_build_ultimate_overlay()
	if _ultimate_overlay != null:
		_ultimate_overlay.visible = not _ultimate_overlay.visible
		if _ultimate_overlay.visible:
			_refresh_ultimate_overlay()


func _build_ultimate_overlay() -> void:
	_ultimate_overlay = Control.new()
	_ultimate_overlay.name = "UltimateOverlay"
	_ultimate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ultimate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ultimate_overlay.visible = false

	var backdrop: Panel = Panel.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop_style: StyleBoxFlat = StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.add_theme_stylebox_override("panel", backdrop_style)
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_ultimate_overlay.visible = false
	)
	_ultimate_overlay.add_child(backdrop)

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "OverlayBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -320.0
	box.offset_top = -220.0
	box.offset_right = 320.0
	box.offset_bottom = 220.0
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var box_panel: Panel = Panel.new()
	box_panel.name = "BoxPanel"
	box_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.10, 0.12, 0.16, 0.97)
	box_style.border_color = Color(0.9, 0.2, 0.2, 0.9)
	box_style.border_width_left = 2
	box_style.border_width_top = 2
	box_style.border_width_right = 2
	box_style.border_width_bottom = 2
	box_style.corner_radius_top_left = 8
	box_style.corner_radius_top_right = 8
	box_style.corner_radius_bottom_left = 8
	box_style.corner_radius_bottom_right = 8
	box_panel.add_theme_stylebox_override("panel", box_panel.get_theme_stylebox("panel"))
	box_panel.add_theme_stylebox_override("panel", box_style)
	box.add_child(box_panel)

	var title_lbl: Label = Label.new()
	title_lbl.name = "OverlayTitle"
	title_lbl.text = LocaleManager.L(TALENT_DATA.get_branch_label("ultimate"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_lbl)

	var nodes_row: HBoxContainer = HBoxContainer.new()
	nodes_row.name = "NodesRow"
	nodes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nodes_row.add_theme_constant_override("separation", 32)
	nodes_row.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(nodes_row)

	_ultimate_overlay.add_child(box)
	add_child(_ultimate_overlay)


func _refresh_ultimate_overlay() -> void:
	if _ultimate_overlay == null:
		return
	var nodes_row: HBoxContainer = _ultimate_overlay.get_node_or_null("OverlayBox/NodesRow") as HBoxContainer
	if nodes_row == null:
		return
	for child in nodes_row.get_children():
		child.queue_free()
	var ultimate_talents: Array[Dictionary] = TALENT_DATA.get_branch_talents("ultimate")
	for talent: Dictionary in ultimate_talents:
		var talent_id: String = str(talent.get("id", ""))
		var card: VBoxContainer = VBoxContainer.new()
		card.custom_minimum_size = Vector2(148, 160)
		card.mouse_filter = Control.MOUSE_FILTER_PASS

		var btn: Button = Button.new()
		btn.flat = false
		btn.text = ""
		btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.size = Vector2(NODE_SIZE, NODE_SIZE)
		var state: String = _get_talent_state(talent_id)
		var fill_color: Color = Color(0.26, 0.28, 0.32, 1.0)
		var border_color: Color = Color(0.42, 0.46, 0.52, 1.0)
		if state == "available":
			fill_color = Color(0.6, 0.12, 0.12, 1.0).lerp(Color.WHITE, 0.18)
			border_color = Color(0.9, 0.2, 0.2, 1.0).lightened(0.28)
		elif state == "unlocked":
			fill_color = Color(0.94, 0.76, 0.26, 1.0)
			border_color = Color(1.0, 0.93, 0.66, 1.0)
		btn.add_theme_stylebox_override("normal", _make_circle_style(fill_color, border_color, 3))
		btn.pressed.connect(_on_talent_selected.bind(talent_id))
		card.add_child(btn)

		var name_lbl: Label = Label.new()
		name_lbl.text = LocaleManager.L(str(talent.get("name", talent_id)))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.custom_minimum_size = Vector2(148, 40)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)

		var cost_lbl: Label = Label.new()
		var cost_val: int = int(talent.get("cost", 0))
		cost_lbl.text = "紅:%d" % cost_val
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost_lbl)

		nodes_row.add_child(card)
