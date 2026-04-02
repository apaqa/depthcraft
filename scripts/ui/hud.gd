extends Control

signal death_return_requested

const BUFF_SYSTEM = preload("res://scripts/dungeon/buff_system.gd")
const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const HOME_ARROW_SCRIPT = preload("res://scripts/ui/home_arrow.gd")
const UI_AUDIO_CLICK_HOOK = preload("res://scripts/ui/ui_audio_click_hook.gd")
const MINIMAP_SCRIPT = preload("res://scripts/ui/minimap.gd")

@onready var hp_label: Label = $HPLabel
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar_fill: ColorRect = $HPBarBG/HPBarFill
@onready var bag_label: Label = $BagLabel
@onready var floor_label: Label = $FloorLabel
@onready var kills_label: Label = $KillsLabel
@onready var buff_row: HBoxContainer = $BuffRow
@onready var day_label: Label = $DayLabel
@onready var npc_count_label: Label = $NpcCountLabel
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var inventory_list: VBoxContainer = $InventoryPanel/MarginContainer/VBoxContainer/ScrollContainer/ItemListContainer
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var build_hud: Control = $BuildHUD
@onready var debug_label: Label = $DebugLabel
@onready var connection_label: Label = $ConnectionLabel
@onready var crafting_menu: Control = $CraftingMenu
@onready var storage_ui: Control = $StorageUI
@onready var repair_ui: Control = $RepairUI
@onready var talent_tree: Control = $TalentTree
@onready var equipment_panel: Control = $EquipmentPanel
@onready var skill_equip_ui: Control = $SkillEquipUI
@onready var achievement_popup: Control = $AchievementPopup
@onready var achievement_panel: Control = $AchievementPanel
@onready var quest_board_ui: Control = $QuestBoardUI
@onready var tavern_ui: Control = $TavernUI
@onready var minimap: Control = $Minimap
@onready var buff_select: Control = $BuffSelect
@onready var death_overlay: Control = $DeathOverlay
@onready var death_backdrop: ColorRect = $DeathOverlay/Backdrop
@onready var death_vbox: VBoxContainer = $DeathOverlay/VBoxContainer
@onready var death_title_label: Label = $DeathOverlay/VBoxContainer/TitleLabel
@onready var death_summary_label: Label = $DeathOverlay/VBoxContainer/SummaryLabel
@onready var event_banner: Label = $EventBanner
@onready var raid_countdown_label: Label = $RaidCountdownLabel
@onready var raid_border: ColorRect = $RaidBorder
@onready var status_label: Label = $StatusLabel
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var transition_label: Label = $TransitionOverlay/TransitionLabel
@onready var consumable_bar: Label = $ConsumableBar
@onready var skill_slot_row: HBoxContainer = $SkillSlotRow

const HUD_LEFT_MARGIN = 8.0
const HUD_TOP_MARGIN = 8.0
const HUD_LINE_HEIGHT = 18.0
const HP_BAR_SIZE = Vector2(120.0, 10.0)
const HP_LABEL_SIZE = Vector2(120.0, 18.0)
const CLASS_LABEL_SIZE = Vector2(280.0, 18.0)
const INFO_LABEL_SIZE = Vector2(220.0, 18.0)
const BUFF_ROW_SIZE = Vector2(220.0, 24.0)
const SKILL_ROW_BOTTOM_MARGIN = 56.0
const CONSUMABLE_BAR_BOTTOM_MARGIN = 24.0
const BOTTOM_UI_GAP = 10.0

var player: Node = null
var inventory: Node = null
var current_level: Node = null
var _blessing_panel: BlessingChoicePanel = null
var _blessing_stage: int = 0
var _blessing_pending_theme: String = ""
var _blessing_pending_slot: String = ""
var _blessing_reroll_count: int = 0
var _status_panel: BlessingStatusPanel = null
var _help_panel: KeybindHelpPanel = null
var current_level_id: String = ""
var fullscreen_map: Control = null
var settings_menu: SettingsMenu = null
var currency_label: Label = null
var class_label: Label = null
var hp_penalty_label: Label = null
var home_arrow: Control = null
var _consumable_slot_row: HBoxContainer = null
var _consumable_slot_views: Array[Dictionary] = []
var _death_edge_glow: ColorRect = null
var _tracked_ui_visibility: Dictionary = {}
var _death_dynamic_nodes: Array[Node] = []
var _last_minimap_player_tile: Vector2i = Vector2i(-9999, -9999)
var _last_explored_count: int = -1
var _minimap_force_timer: float = 0.0
var _skill_slot_overlays: Array[ColorRect] = []
var _skill_slot_cd_labels: Array[Label] = []
var _skill_slot_name_labels: Array[Label] = []
var _skill_hint_label: Label = null
var _victory_screen: Control = null
var _skill_system_cache: Node = null
var _codex_panel: Control = null
var _set_bonus_panel: PanelContainer = null
var _set_bonus_label: Label = null
var _combo_label: Label = null
var _boss_bar_root: Control = null
var _boss_name_label: Label = null
var _boss_hp_bg: ColorRect = null
var _boss_hp_fill: ColorRect = null
var _boss_max_hp: float = 1.0


func _ready() -> void:
	UI_AUDIO_CLICK_HOOK.attach(self)
	skill_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not resized.is_connected(_on_hud_resized):
		resized.connect(_on_hud_resized)

	currency_label = Label.new()
	currency_label.add_theme_constant_override("outline_size", 2)
	currency_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	currency_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	currency_label.add_theme_font_size_override("font_size", 12)
	currency_label.text = ""
	add_child(currency_label)

	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1.0))
	class_label.add_theme_constant_override("outline_size", 2)
	class_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_child(class_label)

	hp_penalty_label = Label.new()
	hp_penalty_label.add_theme_font_size_override("font_size", 12)
	hp_penalty_label.add_theme_constant_override("outline_size", 2)
	hp_penalty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_penalty_label.add_theme_color_override("font_color", Color(0.84, 0.46, 1.0, 1.0))
	hp_penalty_label.visible = false
	add_child(hp_penalty_label)
	refresh_meta_labels()
	_layout_static_hud()
	_build_consumable_slot_row()
	_configure_death_overlay()
	_layout_bottom_hud()
	_set_bonus_panel = PanelContainer.new()
	_set_bonus_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_bonus_panel.visible = false
	var set_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	set_panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.72)
	set_panel_style.border_color = Color(0.28, 0.28, 0.34, 0.9)
	set_panel_style.border_width_left = 1
	set_panel_style.border_width_top = 1
	set_panel_style.border_width_right = 1
	set_panel_style.border_width_bottom = 1
	set_panel_style.corner_radius_top_left = 4
	set_panel_style.corner_radius_top_right = 4
	set_panel_style.corner_radius_bottom_left = 4
	set_panel_style.corner_radius_bottom_right = 4
	_set_bonus_panel.add_theme_stylebox_override("panel", set_panel_style)
	var set_margin: MarginContainer = MarginContainer.new()
	set_margin.add_theme_constant_override("margin_left", 8)
	set_margin.add_theme_constant_override("margin_top", 6)
	set_margin.add_theme_constant_override("margin_right", 8)
	set_margin.add_theme_constant_override("margin_bottom", 6)
	_set_bonus_panel.add_child(set_margin)
	_set_bonus_label = Label.new()
	_set_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_bonus_label.add_theme_font_size_override("font_size", 11)
	_set_bonus_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	_set_bonus_label.add_theme_constant_override("line_spacing", 2)
	set_margin.add_child(_set_bonus_label)
	add_child(_set_bonus_panel)

	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 14)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_combo_label.add_theme_constant_override("outline_size", 2)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo_label.position = Vector2(-130.0, HUD_TOP_MARGIN)
	_combo_label.size = Vector2(120.0, HUD_LINE_HEIGHT * 2.0)
	_combo_label.visible = false
	add_child(_combo_label)

	_boss_bar_root = Control.new()
	_boss_bar_root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_bar_root.size = Vector2(320.0, 46.0)
	_boss_bar_root.position = Vector2(-160.0, -70.0)
	_boss_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_root.visible = false
	add_child(_boss_bar_root)
	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override("font_size", 13)
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
	_boss_name_label.add_theme_constant_override("outline_size", 2)
	_boss_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name_label.size = Vector2(320.0, 18.0)
	_boss_bar_root.add_child(_boss_name_label)
	_boss_hp_bg = ColorRect.new()
	_boss_hp_bg.color = Color(0.1, 0.0, 0.0, 0.85)
	_boss_hp_bg.size = Vector2(320.0, 14.0)
	_boss_hp_bg.position = Vector2(0.0, 22.0)
	_boss_bar_root.add_child(_boss_hp_bg)
	_boss_hp_fill = ColorRect.new()
	_boss_hp_fill.color = Color(0.85, 0.15, 0.1, 1.0)
	_boss_hp_fill.size = Vector2(320.0, 14.0)
	_boss_hp_fill.position = Vector2(0.0, 0.0)
	_boss_hp_bg.add_child(_boss_hp_fill)

	update_hp(100, 100)
	update_bag_label(0, 20)
	update_consumable_bar([])
	var network_manager = get_node_or_null("/root/NetworkManager")
	set_connection_info(network_manager.get_connection_status() if network_manager != null else "")
	inventory_panel.visible = false
	if crafting_menu.has_signal("close_requested") and not crafting_menu.close_requested.is_connected(_on_menu_closed):
		crafting_menu.close_requested.connect(_on_menu_closed)
	if storage_ui.has_signal("close_requested") and not storage_ui.close_requested.is_connected(_on_menu_closed):
		storage_ui.close_requested.connect(_on_menu_closed)
	if repair_ui.has_signal("close_requested") and not repair_ui.close_requested.is_connected(_on_menu_closed):
		repair_ui.close_requested.connect(_on_menu_closed)
	if talent_tree.has_signal("close_requested") and not talent_tree.close_requested.is_connected(_on_menu_closed):
		talent_tree.close_requested.connect(_on_menu_closed)
	if equipment_panel.has_signal("close_requested") and not equipment_panel.close_requested.is_connected(_on_menu_closed):
		equipment_panel.close_requested.connect(_on_menu_closed)
	if skill_equip_ui.has_signal("close_requested") and not skill_equip_ui.close_requested.is_connected(_on_menu_closed):
		skill_equip_ui.close_requested.connect(_on_menu_closed)
	if achievement_panel.has_signal("close_requested") and not achievement_panel.close_requested.is_connected(_on_menu_closed):
		achievement_panel.close_requested.connect(_on_menu_closed)
	if quest_board_ui.has_signal("close_requested") and not quest_board_ui.close_requested.is_connected(_on_menu_closed):
		quest_board_ui.close_requested.connect(_on_menu_closed)
	if tavern_ui.has_signal("close_requested") and not tavern_ui.close_requested.is_connected(_on_menu_closed):
		tavern_ui.close_requested.connect(_on_menu_closed)
	_setup_blessing_panel()
	# Note: _codex_panel is created later in _ready after fullscreen_map
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and not achievement_manager.achievement_unlocked.is_connected(_on_achievement_unlocked):
		achievement_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	set_process(true)
	settings_menu = SettingsMenu.new()
	settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_menu)
	if not settings_menu.close_requested.is_connected(_on_menu_closed):
		settings_menu.close_requested.connect(_on_menu_closed)
	_register_ui_audio_target(inventory_panel)
	_register_ui_audio_target(build_hud)
	_register_ui_audio_target(crafting_menu)
	_register_ui_audio_target(storage_ui)
	_register_ui_audio_target(repair_ui)
	_register_ui_audio_target(talent_tree)
	_register_ui_audio_target(equipment_panel)
	_register_ui_audio_target(skill_equip_ui)
	_register_ui_audio_target(achievement_panel)
	_register_ui_audio_target(quest_board_ui)
	_register_ui_audio_target(buff_select)
	_register_ui_audio_target(settings_menu)
	_ensure_home_arrow()
	if NpcManager != null and not NpcManager.roster_changed.is_connected(_on_npc_roster_changed):
		NpcManager.roster_changed.connect(_on_npc_roster_changed)
	_update_npc_count_label(NpcManager.get_recruited_count() if NpcManager != null else 0)
	if WorldLevel != null and not WorldLevel.world_level_changed.is_connected(_on_world_level_changed):
		WorldLevel.world_level_changed.connect(_on_world_level_changed)
	var fsmap: Control = MINIMAP_SCRIPT.new()
	fsmap.name = "FullscreenMap"
	fsmap.set_anchors_preset(Control.PRESET_FULL_RECT)
	fsmap.offset_left = 80.0
	fsmap.offset_top = 60.0
	fsmap.offset_right = -80.0
	fsmap.offset_bottom = -60.0
	fsmap.visible = false
	fsmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fsmap)
	fullscreen_map = fsmap

	var codex_script: Script = load("res://scripts/ui/codex_panel.gd")
	_codex_panel = Control.new()
	_codex_panel.set_script(codex_script)
	_codex_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_codex_panel)
	if _codex_panel.has_signal("panel_closed") and not _codex_panel.panel_closed.is_connected(_on_menu_closed):
		_codex_panel.panel_closed.connect(_on_menu_closed)


func _build_consumable_slot_row() -> void:
	consumable_bar.visible = false
	_consumable_slot_row = HBoxContainer.new()
	_consumable_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_consumable_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_consumable_slot_row.add_theme_constant_override("separation", 8)
	add_child(_consumable_slot_row)
	move_child(_consumable_slot_row, consumable_bar.get_index())
	_consumable_slot_views.clear()
	for slot_index: int in range(2):
		var slot_panel: Panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(56.0, 56.0)
		slot_panel.size = Vector2(56.0, 56.0)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		slot_style.border_color = Color(0.32, 0.32, 0.32, 0.95)
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot_panel.add_theme_stylebox_override("panel", slot_style)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.position = Vector2(4.0, 4.0)
		icon_rect.size = Vector2(48.0, 48.0)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(icon_rect)

		var quantity_label: Label = Label.new()
		quantity_label.position = Vector2(0.0, 38.0)
		quantity_label.size = Vector2(52.0, 14.0)
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		quantity_label.add_theme_font_size_override("font_size", 12)
		quantity_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		quantity_label.add_theme_constant_override("outline_size", 2)
		quantity_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(quantity_label)

		var key_label: Label = Label.new()
		key_label.position = Vector2(5.0, 3.0)
		key_label.size = Vector2(14.0, 12.0)
		key_label.text = "Q" if slot_index == 0 else "R"
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
		key_label.add_theme_constant_override("outline_size", 2)
		key_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(key_label)

		var dashed_overlay: Control = _build_empty_slot_overlay()
		slot_panel.add_child(dashed_overlay)
		slot_panel.move_child(quantity_label, slot_panel.get_child_count() - 1)
		slot_panel.move_child(key_label, slot_panel.get_child_count() - 1)
		_consumable_slot_row.add_child(slot_panel)
		_consumable_slot_views.append({
			"panel": slot_panel,
			"icon": icon_rect,
			"quantity": quantity_label,
			"key": key_label,
			"dashed": dashed_overlay,
		})


func _build_empty_slot_overlay() -> Control:
	var overlay: Control = Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(56.0, 56.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dash_color: Color = Color(0.55, 0.55, 0.55, 0.85)
	var dash_rects: Array[Rect2] = [
		Rect2(6.0, 4.0, 10.0, 2.0),
		Rect2(22.0, 4.0, 10.0, 2.0),
		Rect2(38.0, 4.0, 10.0, 2.0),
		Rect2(6.0, 50.0, 10.0, 2.0),
		Rect2(22.0, 50.0, 10.0, 2.0),
		Rect2(38.0, 50.0, 10.0, 2.0),
		Rect2(4.0, 8.0, 2.0, 10.0),
		Rect2(4.0, 24.0, 2.0, 10.0),
		Rect2(4.0, 40.0, 2.0, 10.0),
		Rect2(50.0, 8.0, 2.0, 10.0),
		Rect2(50.0, 24.0, 2.0, 10.0),
		Rect2(50.0, 40.0, 2.0, 10.0),
	]
	for dash_rect: Rect2 in dash_rects:
		var dash: ColorRect = ColorRect.new()
		dash.position = dash_rect.position
		dash.size = dash_rect.size
		dash.color = dash_color
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(dash)
	return overlay


func _configure_death_overlay() -> void:
	death_backdrop.color = Color(0.0, 0.0, 0.0, 0.75)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	death_vbox.set_anchors_preset(Control.PRESET_CENTER)
	death_vbox.offset_left = -250.0
	death_vbox.offset_top = -190.0
	death_vbox.offset_right = 250.0
	death_vbox.offset_bottom = 190.0
	death_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	death_vbox.add_theme_constant_override("separation", 12)
	death_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title_label.add_theme_constant_override("outline_size", 3)
	death_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	death_summary_label.visible = false
	_death_edge_glow = ColorRect.new()
	_death_edge_glow.name = "EdgeGlow"
	_death_edge_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge_material: ShaderMaterial = ShaderMaterial.new()
	var edge_shader: Shader = Shader.new()
	edge_shader.code = "shader_type canvas_item;\nuniform vec4 glow_color : source_color = vec4(1.0, 0.12, 0.12, 0.95);\nuniform float edge_width = 0.18;\nvoid fragment() {\n\tfloat dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));\n\tfloat edge = 1.0 - smoothstep(0.0, edge_width, dist);\n\tfloat alpha = edge * edge * glow_color.a;\n\tCOLOR = vec4(glow_color.rgb, alpha);\n}\n"
	edge_material.shader = edge_shader
	_death_edge_glow.material = edge_material
	death_overlay.add_child(_death_edge_glow)
	death_overlay.move_child(_death_edge_glow, death_backdrop.get_index() + 1)


func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "%s: %d/%d" % [LocaleManager.L("hp"), current, max_hp]
	var ratio: float = float(current) / float(max(max_hp, 1))
	hp_bar_fill.size.x = HP_BAR_SIZE.x * clampf(ratio, 0.0, 1.0)
	hp_bar_fill.color = Color(0.85, 0.15, 0.15, 1.0) if ratio > 0.25 else Color(1.0, 0.1, 0.1, 1.0)


func update_run_max_hp_penalty(lost_percent: int) -> void:
	if hp_penalty_label == null:
		return
	hp_penalty_label.visible = lost_percent > 0
	if not hp_penalty_label.visible:
		hp_penalty_label.text = ""
		return
	hp_penalty_label.text = "已損失上限：-%d%%" % max(lost_percent, 0)


func bind_player(new_player) -> void:
	var skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system != null and skill_system.skills_changed.is_connected(_refresh_skill_slots):
		skill_system.skills_changed.disconnect(_refresh_skill_slots)

	player = new_player
	inventory = player.inventory
	if not player.interaction_prompt_changed.is_connected(show_interaction_prompt):
		player.interaction_prompt_changed.connect(show_interaction_prompt)
	if not player.interaction_prompt_cleared.is_connected(hide_interaction_prompt):
		player.interaction_prompt_cleared.connect(hide_interaction_prompt)
	if not player.hp_changed.is_connected(update_hp):
		player.hp_changed.connect(update_hp)
	if player.has_signal("run_max_hp_penalty_changed") and not player.run_max_hp_penalty_changed.is_connected(update_run_max_hp_penalty):
		player.run_max_hp_penalty_changed.connect(update_run_max_hp_penalty)
	if player.has_signal("combo_changed") and not player.combo_changed.is_connected(update_combo):
		player.combo_changed.connect(update_combo)
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if not player.equipment_system.equipment_changed.is_connected(_on_equipment_changed):
		player.equipment_system.equipment_changed.connect(_on_equipment_changed)
	if not player.building_system.build_state_changed.is_connected(_refresh_debug_label):
		player.building_system.build_state_changed.connect(_refresh_debug_label)
	if not player.crafting_requested.is_connected(_on_crafting_requested):
		player.crafting_requested.connect(_on_crafting_requested)
	if not player.storage_requested.is_connected(_on_storage_requested):
		player.storage_requested.connect(_on_storage_requested)
	if not player.repair_requested.is_connected(_on_repair_requested):
		player.repair_requested.connect(_on_repair_requested)
	if not player.talent_requested.is_connected(_on_talent_requested):
		player.talent_requested.connect(_on_talent_requested)
	if not player.equipment_panel_requested.is_connected(_on_equipment_requested):
		player.equipment_panel_requested.connect(_on_equipment_requested)
	if not player.tavern_requested.is_connected(_on_tavern_requested):
		player.tavern_requested.connect(_on_tavern_requested)
	if not player.buffs_changed.is_connected(_refresh_buff_icons):
		player.buffs_changed.connect(_refresh_buff_icons)
	if not player.status_message_requested.is_connected(show_status_message):
		player.status_message_requested.connect(show_status_message)
	skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system != null and not skill_system.skills_changed.is_connected(_refresh_skill_slots):
		skill_system.skills_changed.connect(_refresh_skill_slots)
	if build_hud.has_method("bind_system"):
		build_hud.bind_system(player.building_system, inventory)
	if home_arrow != null and home_arrow.has_method("bind_player"):
		home_arrow.bind_player(player)
	_on_inventory_changed()
	_on_equipment_changed()
	_refresh_debug_label()
	_refresh_buff_icons(player.get_active_buffs())
	_refresh_set_bonus_panel()
	if player.has_method("get_run_max_hp_penalty_percent"):
		update_run_max_hp_penalty(int(player.get_run_max_hp_penalty_percent()))
	refresh_meta_labels()
	_refresh_skill_slots()


func bind_level(level, level_id: String) -> void:
	current_level = level
	current_level_id = level_id
	minimap.visible = level_id == "dungeon" or level_id == "overworld"
	_last_minimap_player_tile = Vector2i(-9999, -9999)
	_last_explored_count = -1
	if fullscreen_map != null:
		fullscreen_map.visible = false
	if level_id != "overworld":
		set_raid_countdown("", Color(1.0, 0.15, 0.15, 1.0), false)


func _unhandled_input(event: InputEvent) -> void:
	if fullscreen_map != null and fullscreen_map.visible:
		if event.is_action_pressed("toggle_map") or event.is_action_pressed("ui_cancel"):
			_toggle_fullscreen_map()
			get_viewport().set_input_as_handled()
		return

	if _is_modal_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("toggle_equipment") or event.is_action_pressed("toggle_skills"):
			_close_all_menus()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_map"):
		_toggle_fullscreen_map()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_equipment") and player != null and not player.building_system.is_build_mode_active():
		_toggle_equipment_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_skills") and player != null and not player.building_system.is_build_mode_active():
		_toggle_skill_equip_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_achievements") and player != null and not player.building_system.is_build_mode_active():
		_toggle_achievement_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_codex") and (player == null or not player.building_system.is_build_mode_active()):
		_toggle_codex_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("help"):
		_toggle_help_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and inventory_panel.visible:
		inventory_panel.visible = false
		_on_menu_closed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_toggle_settings_menu()
		get_viewport().set_input_as_handled()


func toggle_inventory_panel() -> void:
	if _is_modal_open():
		return
	inventory_panel.visible = not inventory_panel.visible
	if player != null:
		player.set_ui_blocked(inventory_panel.visible)
	if inventory_panel.visible:
		rebuild_inventory_grid()
	else:
		_on_menu_closed()


func show_interaction_prompt(prompt_text: String) -> void:
	if interaction_prompt.has_method("show_prompt"):
		interaction_prompt.show_prompt(prompt_text)
	else:
		interaction_prompt.text = prompt_text
		interaction_prompt.visible = true


func hide_interaction_prompt() -> void:
	if interaction_prompt.has_method("hide_prompt"):
		interaction_prompt.hide_prompt()
	else:
		interaction_prompt.text = ""
		interaction_prompt.visible = false


func _on_inventory_changed() -> void:
	if inventory == null:
		return

	update_bag_label(inventory.items.size(), inventory.max_slots)
	if currency_label != null:
		var gold_count: int = int(inventory.get_item_count("gold"))
		var silver_count: int = int(inventory.get_item_count("silver"))
		var copper_count: int = int(inventory.get_item_count("copper"))
		currency_label.text = "%dG %dS %dC" % [gold_count, silver_count, copper_count]
	if player != null and player.has_method("get_consumable_slots"):
		update_consumable_bar(player.get_consumable_slots())
	_sync_achievement_equipment_state()
	rebuild_inventory_grid()


func _on_equipment_changed() -> void:
	_sync_achievement_equipment_state()
	_refresh_set_bonus_panel()


func _refresh_set_bonus_panel() -> void:
	if _set_bonus_panel == null or _set_bonus_label == null:
		return
	if player == null or player.equipment_system == null or not player.equipment_system.has_method("get_active_set_entries"):
		_set_bonus_panel.visible = false
		return
	var entries: Array = player.equipment_system.get_active_set_entries()
	if entries.is_empty():
		_set_bonus_panel.visible = false
		return
	var lines: PackedStringArray = []
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		var set_name: String = str(entry.get("set_name", ""))
		if set_name == "":
			continue
		lines.append(set_name)
		for effect_variant: Variant in entry.get("active_effects", []):
			lines.append(str(effect_variant))
	if lines.is_empty():
		_set_bonus_panel.visible = false
		return
	_set_bonus_label.text = "\n".join(lines)
	_set_bonus_panel.visible = true
	_set_bonus_panel.reset_size()
	_layout_bottom_hud()


func _sync_achievement_equipment_state() -> void:
	if player == null:
		return
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null:
		achievement_manager.record_equipment_state(inventory, player.equipment_system)
	if achievement_panel != null and achievement_panel.visible and achievement_panel.has_method("rebuild"):
		achievement_panel.rebuild()


func update_bag_label(used_slots: int, max_slots: int) -> void:
	bag_label.text = LocaleManager.L("backpack") + ": %d/%d" % [used_slots, max_slots]


func update_floor_label(current_floor: int) -> void:
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle_prefix: String = ""
	if cycle_manager != null and int(cycle_manager.current_cycle) > 1:
		cycle_prefix = "輪迴%d " % int(cycle_manager.current_cycle)
	floor_label.text = cycle_prefix + (LocaleManager.L("floor") + ": %d" % current_floor) if current_floor > 0 else ""
	day_label.visible = current_floor <= 0


func refresh_meta_labels() -> void:
	_refresh_class_label()


func _refresh_class_label() -> void:
	if class_label == null:
		return
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	var class_display_name: String = ""
	if class_system != null and class_system.has_method("get_class_display_name"):
		class_display_name = str(class_system.call("get_class_display_name"))
	var world_level_text: String = _get_world_level_text()
	class_label.text = world_level_text if class_display_name == "" else "%s | %s" % [class_display_name, world_level_text]


func _get_world_level_text() -> String:
	var world_level_value: int = WorldLevel.get_world_level() if WorldLevel != null else 1
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "世界等級: %d" % world_level_value
	return "World Level: %d" % world_level_value


func update_kills_label(kills: int) -> void:
	kills_label.text = LocaleManager.L("kills") + ": %d" % kills if kills > 0 else ""


func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if _boss_bar_root == null:
		return
	_boss_max_hp = maxf(float(max_hp), 1.0)
	_boss_name_label.text = boss_name
	if _boss_hp_fill != null and _boss_hp_bg != null:
		_boss_hp_fill.size.x = _boss_hp_bg.size.x
	_boss_bar_root.visible = true
	_boss_bar_root.modulate.a = 0.0
	var tween: Tween = _boss_bar_root.create_tween()
	tween.tween_property(_boss_bar_root, "modulate:a", 1.0, 0.4)


func update_boss_bar(current_hp: int) -> void:
	if _boss_bar_root == null or _boss_hp_fill == null or _boss_hp_bg == null:
		return
	var ratio: float = clampf(float(current_hp) / _boss_max_hp, 0.0, 1.0)
	_boss_hp_fill.size.x = _boss_hp_bg.size.x * ratio


func hide_boss_bar() -> void:
	if _boss_bar_root == null or not _boss_bar_root.visible:
		return
	var tween: Tween = _boss_bar_root.create_tween()
	tween.tween_property(_boss_bar_root, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_boss_bar_root.visible = false
	)


func update_combo(count: int) -> void:
	if _combo_label == null:
		return
	if count <= 0:
		_combo_label.visible = false
		return
	_combo_label.visible = true
	_combo_label.text = "COMBO x" + str(count)
	if count >= 10:
		_combo_label.add_theme_font_size_override("font_size", 20)
		_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	else:
		_combo_label.add_theme_font_size_override("font_size", 14)
		_combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var tween: Tween = _combo_label.create_tween()
	_combo_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.15)


func _refresh_debug_label() -> void:
	if player == null:
		debug_label.visible = false
		return

	debug_label.visible = player.building_system.is_debug_mode_enabled()
	debug_label.text = LocaleManager.L("debug_label_hint") if debug_label.visible else LocaleManager.L("debug_label")
	debug_label.modulate.a = 0.5
	debug_label.add_theme_font_size_override("font_size", 10)


func set_connection_info(message: String) -> void:
	connection_label.text = message
	connection_label.visible = not message.is_empty()


func _on_crafting_requested(_facility) -> void:
	_close_all_menus()
	var recipe_filter: PackedStringArray = PackedStringArray()
	var menu_title: String = LocaleManager.L("crafting_title")
	if _facility != null and _facility.has_method("get_recipe_ids"):
		recipe_filter = _facility.get_recipe_ids()
	if _facility != null and _facility.has_method("get_menu_title"):
		menu_title = _facility.get_menu_title()
	crafting_menu.open_for_player(player, recipe_filter, menu_title, _facility)
	player.set_ui_blocked(true)


func _on_storage_requested(facility) -> void:
	_close_all_menus()
	storage_ui.open_for_storage(inventory, facility.inventory)
	player.set_ui_blocked(true)


func _on_repair_requested(_facility) -> void:
	_close_all_menus()
	repair_ui.open_for_player(player, _facility)
	player.set_ui_blocked(true)


func _on_talent_requested(_facility) -> void:
	_close_all_menus()
	talent_tree.open_for_player(player, _facility)
	player.set_ui_blocked(true)


func _on_tavern_requested(facility: Node) -> void:
	_close_all_menus()
	tavern_ui.open_for_player(player, facility)
	player.set_ui_blocked(true)


func _on_equipment_requested() -> void:
	_toggle_equipment_panel()


func _toggle_equipment_panel() -> void:
	if equipment_panel.visible:
		equipment_panel.close_menu()
		return
	_close_all_menus()
	equipment_panel.open_for_player(player)
	player.set_ui_blocked(true)


func _toggle_skill_equip_ui() -> void:
	if skill_equip_ui.visible:
		skill_equip_ui.close_menu()
		return
	_close_all_menus()
	skill_equip_ui.open_for_player(player)
	player.set_ui_blocked(true)


func _toggle_achievement_panel() -> void:
	if achievement_panel.visible:
		achievement_panel.close_panel()
		return
	_close_all_menus()
	achievement_panel.open_panel()
	player.set_ui_blocked(true)


func _toggle_help_panel() -> void:
	if _help_panel == null:
		_help_panel = KeybindHelpPanel.new()
		_help_panel.name = "KeybindHelpPanel"
		_help_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_help_panel)
	_help_panel.toggle()


func _toggle_codex_panel() -> void:
	if _codex_panel == null:
		return
	if _codex_panel.visible:
		_codex_panel.close_panel()
		return
	_close_all_menus()
	_codex_panel.open_panel()
	if player != null:
		player.set_ui_blocked(true)


func _close_all_menus() -> void:
	inventory_panel.visible = false
	crafting_menu.close_menu()
	storage_ui.close_menu()
	repair_ui.close_menu()
	talent_tree.close_menu()
	equipment_panel.close_menu()
	skill_equip_ui.close_menu()
	achievement_panel.close_panel()
	if quest_board_ui.has_method("close_menu"):
		quest_board_ui.call("close_menu")
	if tavern_ui.has_method("close_menu"):
		tavern_ui.call("close_menu")
	buff_select.close_menu()
	if settings_menu != null and settings_menu.visible:
		settings_menu.close_menu()
	if _codex_panel != null and _codex_panel.visible:
		_codex_panel.close_panel()
	_on_menu_closed()


func _on_menu_closed() -> void:
	get_tree().paused = false
	release_focus()
	if player != null:
		player.set_ui_blocked(false)


func _is_modal_open() -> bool:
	return crafting_menu.visible or storage_ui.visible or repair_ui.visible or talent_tree.visible or equipment_panel.visible or skill_equip_ui.visible or achievement_panel.visible or quest_board_ui.visible or tavern_ui.visible or buff_select.visible or (_blessing_panel != null and _blessing_panel.visible) or (settings_menu != null and settings_menu.visible) or (_codex_panel != null and _codex_panel.visible)


func queue_achievement_popup(achievement_name: String) -> void:
	if achievement_popup == null or not achievement_popup.has_method("show_achievement"):
		return
	var stub: Dictionary = {"name": achievement_name, "description": ""}
	achievement_popup.show_achievement(stub)


func _on_achievement_unlocked(id: String) -> void:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager == null:
		return
	var achievement: Dictionary = achievement_manager.get_achievement(id)
	if achievement_popup != null and achievement_popup.has_method("show_achievement"):
		achievement_popup.show_achievement(achievement)
	if achievement_panel != null and achievement_panel.visible and achievement_panel.has_method("rebuild"):
		achievement_panel.rebuild()


func _toggle_settings_menu() -> void:
	if settings_menu == null:
		return
	if settings_menu.visible:
		settings_menu.close_menu()
		return
	_close_all_menus()
	settings_menu.open_menu(get_viewport().get_camera_2d())
	if player != null:
		player.set_ui_blocked(true)


func _process(delta: float) -> void:
	_update_minimap(delta)
	_update_skill_cooldowns()


func _update_minimap(delta: float) -> void:
	if current_level == null or not current_level.has_method("get_minimap_snapshot"):
		minimap.visible = false
		return
	minimap.visible = true
	_minimap_force_timer += delta
	var needs_redraw: bool = false
	if player != null and is_instance_valid(player):
		var current_tile: Vector2i = Vector2i(
			int(player.global_position.x / 32.0),
			int(player.global_position.y / 32.0)
		)
		if current_tile != _last_minimap_player_tile:
			needs_redraw = true
			_last_minimap_player_tile = current_tile
	if _minimap_force_timer >= 0.5:
		needs_redraw = true
		_minimap_force_timer = 0.0
	if not needs_redraw:
		return
	var snap: Dictionary = current_level.get_minimap_snapshot()
	minimap.set_snapshot(snap)
	if fullscreen_map != null and fullscreen_map.visible:
		fullscreen_map.set_snapshot(snap)


func _update_skill_cooldowns() -> void:
	if _skill_system_cache == null or not is_instance_valid(_skill_system_cache):
		_skill_system_cache = get_node_or_null("/root/SkillSystem")
	if _skill_system_cache == null:
		return
	var skill_system: Node = _skill_system_cache
	var snapshots: Array = skill_system.get_equipped_skill_snapshots()
	const SLOT_W: float = 70.0
	const SLOT_H: float = 36.0
	for slot_index in range(3):
		var overlay: ColorRect = _skill_slot_overlays[slot_index] if slot_index < _skill_slot_overlays.size() else null
		var cd_label: Label = _skill_slot_cd_labels[slot_index] if slot_index < _skill_slot_cd_labels.size() else null
		var name_label: Label = _skill_slot_name_labels[slot_index] if slot_index < _skill_slot_name_labels.size() else null
		if overlay == null or not is_instance_valid(overlay):
			continue
		var slot: Dictionary = snapshots[slot_index] if slot_index < snapshots.size() else {}
		if slot.is_empty():
			continue
		var cooldown: float = float(slot.get("current_cooldown", 0.0))
		var max_cooldown: float = maxf(float(slot.get("cooldown", 1.0)), 0.001)
		if name_label != null and is_instance_valid(name_label):
			name_label.self_modulate = Color(0.65, 0.65, 0.65, 1.0) if cooldown > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
		if cooldown > 0.0:
			var ratio: float = clampf(cooldown / max_cooldown, 0.0, 1.0)
			overlay.position = Vector2(0.0, SLOT_H * (1.0 - ratio))
			overlay.size = Vector2(SLOT_W, SLOT_H * ratio)
			overlay.visible = true
			if cd_label != null and is_instance_valid(cd_label):
				cd_label.text = "%.1f" % cooldown
				cd_label.visible = true
		else:
			overlay.visible = false
			if cd_label != null and is_instance_valid(cd_label):
				cd_label.visible = false


func _toggle_fullscreen_map() -> void:
	if fullscreen_map == null:
		return
	if fullscreen_map.visible:
		fullscreen_map.visible = false
		if player != null:
			player.set_ui_blocked(false)
		return
	if current_level == null or not current_level.has_method("get_minimap_snapshot"):
		return
	var snap: Dictionary = current_level.get_minimap_snapshot()
	fullscreen_map.set_snapshot(snap)
	fullscreen_map.visible = true
	if player != null:
		player.set_ui_blocked(true)


func rebuild_inventory_grid() -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	if inventory == null:
		return

	var groups: Dictionary = {
		"resource": {"title": "inv_resources", "color": Color(0.62, 0.42, 0.22, 1.0)},
		"equipment": {"title": "inv_equipment", "color": Color(0.3, 0.55, 0.95, 1.0)},
		"consumable": {"title": "inv_consumables", "color": Color(0.32, 0.78, 0.42, 1.0)},
	}
	for type_id in ["resource", "equipment", "consumable"]:
		var section_items: Array[Dictionary] = []
		for stack in inventory.items:
			if str(stack.get("type", "")) == type_id:
				section_items.append(stack)
		if section_items.is_empty():
			continue
		var header: Label = Label.new()
		header.text = LocaleManager.L(str((groups[type_id] as Dictionary).get("title", type_id)))
		header.modulate = Color(0.95, 0.9, 0.7, 1.0)
		inventory_list.add_child(header)
		for stack in section_items:
			var item_color: Color = ITEM_DATABASE.get_item_color(str(stack.get("id", "")), str(stack.get("type", "")))
			inventory_list.add_child(_build_item_row(stack, item_color))


func _build_item_row(stack: Dictionary, _swatch_color: Color) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(200, 24)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_build_item_icon_holder(stack))
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	name_label.self_modulate = ITEM_DATABASE.get_stack_color(stack)
	row.add_child(name_label)
	var quantity_label: Label = Label.new()
	quantity_label.text = "x%d" % int(stack.get("quantity", 0))
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(quantity_label)
	return row


func _build_item_icon_holder(stack: Dictionary) -> Control:
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	if icon != null:
		var icon_tex: TextureRect = TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(16, 16)
		icon_tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_tex.texture = icon
		return icon_tex
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.color = ITEM_DATABASE.get_stack_color(stack)
	return swatch


func open_buff_selection(options: Array, level: Variant) -> void:
	# Legacy stub — old buff system removed, redirect to blessing
	open_blessing_selection(options, level)


func open_blessing_selection(options: Array, level: Variant) -> void:
	_blessing_reroll_count = 0
	if _blessing_panel != null:
		_blessing_panel.reset_reroll()
	current_level = level
	if player != null and is_instance_valid(player):
		player.set_ui_blocked(true)
		if "_is_charging" in player:
			player._is_charging = false
		if "_charge_bar_root" in player and player._charge_bar_root != null:
			player._charge_bar_root.visible = false
	if current_level != null and is_instance_valid(current_level) and current_level.has_method("set_gameplay_paused"):
		current_level.set_gameplay_paused(true)
	get_tree().paused = true
	var bs_node: Node = get_node_or_null("/root/BlessingSystem")
	if bs_node == null:
		_finish_blessing_flow()
		return
	if bs_node.has_method("has_empty_main_slot") and bs_node.has_empty_main_slot():
		_blessing_stage = 1
		_show_blessing_choices(bs_node.generate_theme_choices())
	else:
		_blessing_stage = 3
		_show_blessing_choices(bs_node.generate_sub_choices())


func _setup_blessing_panel() -> void:
	_blessing_panel = BlessingChoicePanel.new()
	_blessing_panel.name = "BlessingChoicePanel"
	_blessing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_blessing_panel)
	_status_panel = BlessingStatusPanel.new()
	_status_panel.name = "BlessingStatusPanel"
	add_child(_status_panel)


func toggle_status_panel() -> void:
	if _status_panel == null:
		return
	_status_panel.toggle(player)


func _get_reroll_choices() -> Array[Dictionary]:
	var bs_node: Node = get_node_or_null("/root/BlessingSystem")
	if bs_node == null:
		return []
	if _blessing_stage == 1:
		return bs_node.generate_theme_choices()
	if _blessing_stage == 3:
		if _blessing_pending_slot != "" and bs_node.has_method("generate_sub_choices_for_slot"):
			return bs_node.generate_sub_choices_for_slot(_blessing_pending_slot)
		return bs_node.generate_sub_choices()
	return []


func _show_blessing_choices(choices: Array[Dictionary]) -> void:
	if _blessing_panel == null:
		_finish_blessing_flow()
		return
	if choices.is_empty():
		_finish_blessing_flow()
		return
	# Disconnect any prior connection
	if _blessing_panel.blessing_chosen.is_connected(_on_blessing_panel_chosen):
		_blessing_panel.blessing_chosen.disconnect(_on_blessing_panel_chosen)
	# Enable reroll only for theme/sub-blessing stages, not slot assignment
	if _blessing_stage == 1 or _blessing_stage == 3:
		_blessing_panel.set_reroll_context(player, _get_reroll_choices, _blessing_reroll_count)
	else:
		_blessing_panel.set_reroll_context(null, Callable(), 0)
	_blessing_panel.open_with_choices(choices)
	_blessing_panel.blessing_chosen.connect(_on_blessing_panel_chosen, CONNECT_ONE_SHOT)


func _on_blessing_panel_chosen(chosen_id: String) -> void:
	if _blessing_panel != null:
		_blessing_reroll_count = int(_blessing_panel.get("_reroll_count"))
	if chosen_id == "":
		_finish_blessing_flow()
		return
	var bs_node: Node = get_node_or_null("/root/BlessingSystem")
	if bs_node == null:
		_finish_blessing_flow()
		return
	if _blessing_stage == 1:
		_blessing_pending_theme = chosen_id
		if bs_node.is_theme_assigned(chosen_id):
			# Theme already bound to a slot — go to sub blessings for that slot
			_blessing_pending_slot = bs_node.get_slot_for_theme(chosen_id)
			_blessing_stage = 3
			_show_blessing_choices(bs_node.generate_sub_choices_for_slot(_blessing_pending_slot))
			return
		var empty_slots: Array[String] = bs_node.get_empty_slots()
		if empty_slots.size() <= 1:
			# Only 1 empty slot — auto-assign, then sub blessings
			if not empty_slots.is_empty():
				bs_node.assign_main_slot(empty_slots[0], chosen_id)
				_blessing_pending_slot = empty_slots[0]
				_blessing_stage = 3
				_show_blessing_choices(bs_node.generate_sub_choices_for_slot(_blessing_pending_slot))
				return
			_finish_blessing_flow()
			return
		_blessing_stage = 2
		_show_blessing_choices(bs_node.generate_slot_choices(chosen_id))
		return
	if _blessing_stage == 2:
		# Chose a slot for the new theme
		bs_node.assign_main_slot(chosen_id, _blessing_pending_theme)
		_blessing_pending_slot = chosen_id
		_blessing_stage = 3
		_show_blessing_choices(bs_node.generate_sub_choices_for_slot(_blessing_pending_slot))
		return
	if _blessing_stage == 3:
		# Sub blessing chosen — add to the tracked slot
		if _blessing_pending_slot != "":
			bs_node.add_sub_blessing_to_slot(_blessing_pending_slot, chosen_id)
		else:
			bs_node.add_sub_blessing(chosen_id)
		_finish_blessing_flow()
		return
	_finish_blessing_flow()


func _finish_blessing_flow() -> void:
	_blessing_stage = 0
	_blessing_pending_theme = ""
	_blessing_pending_slot = ""
	if _blessing_panel != null:
		_blessing_panel.close_panel()
	if player != null and is_instance_valid(player):
		player.set_ui_blocked(false)
	if current_level != null and is_instance_valid(current_level) and current_level.has_method("set_gameplay_paused"):
		current_level.set_gameplay_paused(false)
	get_tree().paused = false


func _refresh_buff_icons(active_buffs: Array) -> void:
	for child in buff_row.get_children():
		child.queue_free()
	for buff in active_buffs:
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.color = buff.get("color", Color.WHITE)
		swatch.tooltip_text = LocaleManager.L(str(buff.get("name", "Buff")))
		buff_row.add_child(swatch)


func show_victory(stats: Dictionary) -> void:
	const VICTORY_SCREEN_SCRIPT: Script = preload("res://scripts/ui/victory_screen.gd")
	if _victory_screen != null and is_instance_valid(_victory_screen):
		_victory_screen.queue_free()
	_victory_screen = Control.new()
	_victory_screen.set_script(VICTORY_SCREEN_SCRIPT)
	_victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_victory_screen)
	_victory_screen.show_victory(stats)
	_victory_screen.return_to_surface_requested.connect(_on_victory_return_to_surface)
	_victory_screen.start_new_cycle_requested.connect(_on_victory_new_cycle)
	if player != null:
		player.set_ui_blocked(true)


func _on_victory_return_to_surface() -> void:
	if player != null:
		player.set_ui_blocked(false)
	if current_level != null and current_level.has_method("get"):
		if current_level.has_signal("return_to_surface_requested"):
			current_level.return_to_surface_requested.emit()


func _on_victory_new_cycle() -> void:
	if player != null:
		player.set_ui_blocked(false)
	if current_level != null and current_level.has_signal("floor_transition_requested"):
		current_level.floor_transition_requested.emit(1)


func show_death_screen(summary: Dictionary) -> void:
	for node: Node in _death_dynamic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_death_dynamic_nodes.clear()
	death_title_label.text = LocaleManager.L("death_title")
	death_title_label.add_theme_font_size_override("font_size", 36)
	death_title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	death_summary_label.visible = false

	var floor_num: int = int(summary.get("floor", 0))
	var kills_num: int = int(summary.get("kills", 0))
	var coins_gained: int = int(summary.get("coins_gained", 0))
	var coins_lost: int = int(summary.get("coins_lost", 0))
	var equips_gained: int = int(summary.get("equips_gained", 0))
	var play_time_secs: int = int(summary.get("play_time", 0.0))
	var time_minutes: int = play_time_secs / 60
	var time_seconds: int = play_time_secs % 60
	var time_str: String = "%02d:%02d" % [time_minutes, time_seconds]

	var top_separator: HSeparator = HSeparator.new()
	death_vbox.add_child(top_separator)
	_death_dynamic_nodes.append(top_separator)

	var exploration_stats: VBoxContainer = VBoxContainer.new()
	exploration_stats.add_theme_constant_override("separation", 6)
	exploration_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	death_vbox.add_child(exploration_stats)
	_death_dynamic_nodes.append(exploration_stats)
	exploration_stats.add_child(_make_death_stat_label(LocaleManager.L("death_floor") % floor_num, Color(1.0, 1.0, 1.0, 1.0), 16))
	exploration_stats.add_child(_make_death_stat_label(LocaleManager.L("death_kills") % kills_num, Color(1.0, 1.0, 1.0, 1.0), 16))
	exploration_stats.add_child(_make_death_stat_label(LocaleManager.L("death_coins_gained") % _format_currency_text(coins_gained), Color(1.0, 1.0, 1.0, 1.0), 16))
	exploration_stats.add_child(_make_death_stat_label(LocaleManager.L("death_equips") % equips_gained, Color(1.0, 1.0, 1.0, 1.0), 16))
	exploration_stats.add_child(_make_death_stat_label(LocaleManager.L("death_time") % time_str, Color(1.0, 1.0, 1.0, 1.0), 16))

	var middle_separator: HSeparator = HSeparator.new()
	death_vbox.add_child(middle_separator)
	_death_dynamic_nodes.append(middle_separator)

	var loss_stats: VBoxContainer = VBoxContainer.new()
	loss_stats.add_theme_constant_override("separation", 6)
	loss_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	death_vbox.add_child(loss_stats)
	_death_dynamic_nodes.append(loss_stats)
	loss_stats.add_child(_make_death_stat_label(LocaleManager.L("death_coins_lost") % _format_currency_text(coins_lost), Color(1.0, 0.35, 0.35, 1.0), 16))
	loss_stats.add_child(_make_death_stat_label(LocaleManager.L("death_durability_loss"), Color(1.0, 0.35, 0.35, 1.0), 16))

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	death_vbox.add_child(spacer)
	_death_dynamic_nodes.append(spacer)

	var button_center: CenterContainer = CenterContainer.new()
	button_center.custom_minimum_size = Vector2(500.0, 50.0)
	death_vbox.add_child(button_center)
	_death_dynamic_nodes.append(button_center)

	var return_btn: Button = Button.new()
	return_btn.text = LocaleManager.L("death_return_home")
	return_btn.custom_minimum_size = Vector2(200.0, 50.0)
	return_btn.add_theme_font_size_override("font_size", 15)
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.08, 0.08, 0.95)
	btn_style.border_color = Color(0.72, 0.18, 0.18, 1.0)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	return_btn.add_theme_stylebox_override("normal", btn_style)
	return_btn.add_theme_stylebox_override("hover", btn_style)
	return_btn.add_theme_stylebox_override("pressed", btn_style)
	return_btn.pressed.connect(_on_death_return_pressed)
	button_center.add_child(return_btn)

	death_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	death_overlay.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(death_overlay, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	return


func hide_death_screen() -> void:
	for node: Node in _death_dynamic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_death_dynamic_nodes.clear()
	death_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	death_overlay.visible = false


func _make_death_stat_label(text_value: String, text_color: Color, font_size: int) -> Label:
	var stat_label: Label = Label.new()
	stat_label.text = text_value
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", font_size)
	stat_label.add_theme_color_override("font_color", text_color)
	stat_label.add_theme_constant_override("outline_size", 2)
	stat_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	return stat_label


func _format_currency_text(copper_total: int) -> String:
	return ITEM_DATABASE.format_currency(maxi(copper_total, 0))


func _on_death_return_pressed() -> void:
	death_return_requested.emit()


func show_event_banner(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	event_banner.text = message
	event_banner.modulate = Color(color.r, color.g, color.b, 0.0)
	event_banner.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(event_banner, "modulate", color, 0.08)
	tween.tween_interval(duration)
	tween.tween_property(event_banner, "modulate", Color(color.r, color.g, color.b, 0.0), 0.3)
	tween.tween_callback(func() -> void: event_banner.visible = false)


func set_raid_countdown(message: String, color: Color = Color(1.0, 0.15, 0.15, 1.0), visible: bool = false) -> void:
	if raid_countdown_label == null:
		return
	raid_countdown_label.text = message
	raid_countdown_label.self_modulate = color
	raid_countdown_label.visible = visible and not message.is_empty()


func flash_border(color: Color) -> void:
	raid_border.color = Color(color.r, color.g, color.b, 0.0)
	raid_border.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(raid_border, "color", Color(color.r, color.g, color.b, 0.55), 0.08)
	tween.tween_property(raid_border, "color", Color(color.r, color.g, color.b, 0.0), 0.25)
	tween.tween_callback(func() -> void: raid_border.visible = false)


func show_status_message(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	status_label.text = message
	status_label.modulate = Color(color.r, color.g, color.b, 0.0)
	status_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(status_label, "modulate", color, 0.08)
	tween.tween_interval(duration)
	tween.tween_property(status_label, "modulate", Color(color.r, color.g, color.b, 0.0), 0.25)
	tween.tween_callback(func() -> void: status_label.visible = false)


func update_day_label(day_number: int) -> void:
	day_label.text = LocaleManager.L("days") + ": %d" % max(day_number, 1)
	day_label.visible = true


func _on_world_level_changed(_world_level: int, _deepest_floor_reached: int) -> void:
	refresh_meta_labels()


func _on_npc_roster_changed(recruited_count: int) -> void:
	_update_npc_count_label(recruited_count)


func _update_npc_count_label(recruited_count: int) -> void:
	if npc_count_label == null:
		return
	if str(LocaleManager.get_locale()).begins_with("zh"):
		npc_count_label.text = "已招募 NPC: %d" % max(recruited_count, 0)
	else:
		npc_count_label.text = "NPCs Recruited: %d" % max(recruited_count, 0)


func update_consumable_bar(slots: Array) -> void:
	if _consumable_slot_views.is_empty():
		return
	for slot_index in range(2):
		var slot: Dictionary = slots[slot_index] if slot_index < slots.size() else {}
		var slot_view: Dictionary = _consumable_slot_views[slot_index]
		var icon_rect: TextureRect = slot_view.get("icon", null) as TextureRect
		var quantity_label: Label = slot_view.get("quantity", null) as Label
		var dashed_overlay: Control = slot_view.get("dashed", null) as Control
		if slot.is_empty():
			if icon_rect != null:
				icon_rect.texture = null
				icon_rect.visible = false
			if quantity_label != null:
				quantity_label.text = ""
			if dashed_overlay != null:
				dashed_overlay.visible = true
			continue
		if icon_rect != null:
			icon_rect.texture = ITEM_DATABASE.get_stack_icon(slot)
			icon_rect.visible = icon_rect.texture != null
		if quantity_label != null:
			quantity_label.text = str(int(slot.get("quantity", 0)))
		if dashed_overlay != null:
			dashed_overlay.visible = false
	_layout_bottom_hud()


func _refresh_skill_slots() -> void:
	if skill_slot_row == null:
		return
	_skill_slot_overlays.clear()
	_skill_slot_cd_labels.clear()
	_skill_slot_name_labels.clear()
	_skill_hint_label = null
	for child in skill_slot_row.get_children():
		child.queue_free()
	var skill_system: Node = get_node_or_null("/root/SkillSystem")
	if skill_system == null:
		return
	var snapshots: Array = skill_system.get_equipped_skill_snapshots()
	const SLOT_W: float = 70.0
	const SLOT_H: float = 36.0
	const KEY_NAMES: Array[String] = ["Z", "X", "V"]
	for slot_index in range(3):
		var slot: Dictionary = snapshots[slot_index] if slot_index < snapshots.size() else {}
		var key_name: String = KEY_NAMES[slot_index]

		var container: Control = Control.new()
		container.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		container.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

		var bg_panel: Panel = Panel.new()
		bg_panel.position = Vector2.ZERO
		bg_panel.size = Vector2(SLOT_W, SLOT_H)
		var bg_style: StyleBoxFlat = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.88)
		bg_style.border_color = Color(0.25, 0.25, 0.3, 1.0)
		bg_style.border_width_left = 1
		bg_style.border_width_top = 1
		bg_style.border_width_right = 1
		bg_style.border_width_bottom = 1
		bg_style.corner_radius_top_left = 4
		bg_style.corner_radius_top_right = 4
		bg_style.corner_radius_bottom_left = 4
		bg_style.corner_radius_bottom_right = 4
		bg_panel.add_theme_stylebox_override("panel", bg_style)
		container.add_child(bg_panel)

		var skill_label: Label = Label.new()
		skill_label.position = Vector2.ZERO
		skill_label.size = Vector2(SLOT_W, SLOT_H)
		skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_label.add_theme_constant_override("outline_size", 2)
		skill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		skill_label.add_theme_font_size_override("font_size", 11)

		if slot.is_empty():
			skill_label.text = "[%s]\n%s" % [key_name, LocaleManager.L("empty")]
			skill_label.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
			container.add_child(skill_label)
			_skill_slot_name_labels.append(null)
			_skill_slot_overlays.append(null)
			_skill_slot_cd_labels.append(null)
		else:
			var short_name: String = LocaleManager.L(str(slot.get("short_name", "skill_name_fallback")))
			skill_label.text = "[%s]\n%s" % [key_name, short_name]
			skill_label.tooltip_text = LocaleManager.L(str(slot.get("name", "skill_name_fallback")))
			container.add_child(skill_label)
			_skill_slot_name_labels.append(skill_label)

			var overlay: ColorRect = ColorRect.new()
			overlay.position = Vector2.ZERO
			overlay.size = Vector2.ZERO
			overlay.color = Color(0.0, 0.0, 0.0, 0.62)
			overlay.visible = false
			container.add_child(overlay)
			_skill_slot_overlays.append(overlay)

			var cd_label: Label = Label.new()
			cd_label.position = Vector2.ZERO
			cd_label.size = Vector2(SLOT_W, SLOT_H)
			cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cd_label.add_theme_font_size_override("font_size", 12)
			cd_label.add_theme_constant_override("outline_size", 3)
			cd_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			cd_label.visible = false
			container.add_child(cd_label)
			_skill_slot_cd_labels.append(cd_label)

		skill_slot_row.add_child(container)

	var has_unequipped: bool = false
	for skill_id: Variant in skill_system.unlocked_skill_ids:
		var is_passive: bool = bool((skill_system.skills.get(skill_id, {}) as Dictionary).get("passive", false))
		if not is_passive and not skill_system.equipped_skill_ids.has(skill_id):
			has_unequipped = true
			break
	if has_unequipped:
		var hint: Label = Label.new()
		hint.text = LocaleManager.L("press_k_equip")
		hint.add_theme_constant_override("outline_size", 2)
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		skill_slot_row.add_child(hint)
		_skill_hint_label = hint
	_layout_bottom_hud.call_deferred()


func play_transition(message: String, overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.25, hold_duration: float = 0.0) -> void:
	transition_label.text = message
	transition_label.modulate = Color.WHITE
	transition_overlay.color = Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0)
	transition_overlay.visible = true
	var fade_in: Tween = create_tween()
	fade_in.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 1.0), fade_duration)
	await fade_in.finished
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	var fade_out: Tween = create_tween()
	fade_out.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0), fade_duration)
	await fade_out.finished
	transition_overlay.visible = false


func fade_to_black(message: String, overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.5) -> void:
	transition_label.text = message
	transition_label.modulate = Color.WHITE
	transition_overlay.color = Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0)
	transition_overlay.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 1.0), fade_duration)
	await tween.finished


func fade_from_black(overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.5) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0), fade_duration)
	await tween.finished
	transition_overlay.visible = false


func _ensure_home_arrow() -> void:
	if home_arrow != null:
		return
	home_arrow = HOME_ARROW_SCRIPT.new()
	home_arrow.name = "HomeArrow"
	add_child(home_arrow)


func _layout_static_hud() -> void:
	# Row 0: HP label text | HP bar | class label (all on same top line)
	var hp_y: float = HUD_TOP_MARGIN
	var hp_label_w: float = 160.0
	var hp_bar_x: float = HUD_LEFT_MARGIN + hp_label_w + 4.0
	var hp_penalty_x: float = hp_bar_x + HP_BAR_SIZE.x + 8.0
	var class_x: float = hp_penalty_x + 150.0
	_set_control_rect(hp_label, Vector2(HUD_LEFT_MARGIN, hp_y), Vector2(hp_label_w, HUD_LINE_HEIGHT))
	_set_control_rect(hp_bar_bg, Vector2(hp_bar_x, hp_y + 4.0), HP_BAR_SIZE)
	_set_control_rect(hp_penalty_label, Vector2(hp_penalty_x, hp_y), Vector2(146.0, HUD_LINE_HEIGHT))
	_set_control_rect(class_label, Vector2(class_x, hp_y), CLASS_LABEL_SIZE)
	hp_bar_fill.position = Vector2.ZERO
	hp_bar_fill.size = Vector2(HP_BAR_SIZE.x, HP_BAR_SIZE.y)

	# Info rows start below HP row — each on its own line, no overlap
	var info_y: float = hp_y + HUD_LINE_HEIGHT + 4.0
	_set_control_rect(bag_label, Vector2(HUD_LEFT_MARGIN, info_y), INFO_LABEL_SIZE)
	_set_control_rect(floor_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT), INFO_LABEL_SIZE)
	_set_control_rect(kills_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 2.0), INFO_LABEL_SIZE)
	_set_control_rect(day_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 3.0), INFO_LABEL_SIZE)
	_set_control_rect(currency_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 4.0), INFO_LABEL_SIZE)
	_set_control_rect(npc_count_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 5.0), INFO_LABEL_SIZE)
	_set_control_rect(buff_row, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 6.0), BUFF_ROW_SIZE)


func _set_control_rect(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = pos
	control.size = rect_size


func _center_skill_slot_row() -> void:
	if skill_slot_row == null:
		return
	var row_size: Vector2 = skill_slot_row.get_combined_minimum_size()
	row_size.x = maxf(row_size.x, 210.0)
	row_size.y = maxf(row_size.y, 36.0)
	skill_slot_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_slot_row.position = Vector2(-row_size.x * 0.5, -SKILL_ROW_BOTTOM_MARGIN - row_size.y)
	skill_slot_row.size = row_size


func _layout_bottom_hud() -> void:
	_center_skill_slot_row()
	if _consumable_slot_row != null:
		var row_size: Vector2 = Vector2(120.0, 56.0)
		_consumable_slot_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_consumable_slot_row.position = Vector2(-row_size.x * 0.5, -CONSUMABLE_BAR_BOTTOM_MARGIN - row_size.y)
		_consumable_slot_row.size = row_size
		if skill_slot_row != null:
			var skill_bottom: float = skill_slot_row.position.y + skill_slot_row.size.y
			var consumable_top: float = _consumable_slot_row.position.y
			if consumable_top < skill_bottom + BOTTOM_UI_GAP:
				_consumable_slot_row.position.y = skill_bottom + BOTTOM_UI_GAP
	if _set_bonus_panel != null and _set_bonus_panel.visible:
		var set_panel_size: Vector2 = _set_bonus_panel.get_combined_minimum_size()
		set_panel_size.x = maxf(set_panel_size.x, 220.0)
		_set_bonus_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_set_bonus_panel.position = Vector2(HUD_LEFT_MARGIN, -20.0 - set_panel_size.y)
		_set_bonus_panel.size = set_panel_size


func _on_hud_resized() -> void:
	_layout_bottom_hud.call_deferred()


func _register_ui_audio_target(target: Control) -> void:
	if target == null:
		return
	var callable: Callable = Callable(self, "_on_tracked_ui_visibility_changed").bind(target)
	var instance_id: int = target.get_instance_id()
	_tracked_ui_visibility[instance_id] = target.visible
	if not target.visibility_changed.is_connected(callable):
		target.visibility_changed.connect(callable)


func _on_tracked_ui_visibility_changed(target: Control) -> void:
	if target == null:
		return
	var instance_id: int = target.get_instance_id()
	var was_visible: bool = bool(_tracked_ui_visibility.get(instance_id, target.visible))
	var is_visible: bool = target.visible
	if was_visible == is_visible:
		return
	_tracked_ui_visibility[instance_id] = is_visible
	if is_visible:
		AudioManager.play_sfx("ui_open")
	else:
		AudioManager.play_sfx("ui_close")
