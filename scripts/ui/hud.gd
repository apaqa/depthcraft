extends Control

const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const HOME_ARROW_SCRIPT := preload("res://scripts/ui/home_arrow.gd")

@onready var hp_label: Label = $HPLabel
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar_fill: ColorRect = $HPBarBG/HPBarFill
@onready var bag_label: Label = $BagLabel
@onready var floor_label: Label = $FloorLabel
@onready var kills_label: Label = $KillsLabel
@onready var buff_row: HBoxContainer = $BuffRow
@onready var day_label: Label = $DayLabel
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
@onready var minimap: Control = $Minimap
@onready var buff_select: Control = $BuffSelect
@onready var death_overlay: Control = $DeathOverlay
@onready var death_summary_label: Label = $DeathOverlay/VBoxContainer/SummaryLabel
@onready var event_banner: Label = $EventBanner
@onready var raid_countdown_label: Label = $RaidCountdownLabel
@onready var raid_border: ColorRect = $RaidBorder
@onready var status_label: Label = $StatusLabel
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var transition_label: Label = $TransitionOverlay/TransitionLabel
@onready var consumable_bar: Label = $ConsumableBar
@onready var skill_slot_row: HBoxContainer = $SkillSlotRow

const HUD_LEFT_MARGIN := 8.0
const HUD_TOP_MARGIN := 8.0
const HUD_LINE_HEIGHT := 18.0
const HP_BAR_SIZE := Vector2(120.0, 10.0)
const HP_LABEL_SIZE := Vector2(120.0, 18.0)
const CLASS_LABEL_SIZE := Vector2(140.0, 18.0)
const INFO_LABEL_SIZE := Vector2(220.0, 18.0)
const BUFF_ROW_SIZE := Vector2(220.0, 24.0)
const SKILL_ROW_BOTTOM_MARGIN := 56.0
const CONSUMABLE_BAR_BOTTOM_MARGIN := 24.0
const BOTTOM_UI_GAP := 10.0

var player = null
var inventory = null
var current_level = null
var current_level_id: String = ""
var settings_menu: SettingsMenu = null
var currency_label: Label = null
var class_label: Label = null
var home_arrow: Control = null


func _ready() -> void:
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
	var _cs := get_node_or_null("/root/ClassSystem")
	class_label.text = _cs.get_class_display_name() if _cs != null else ""
	add_child(class_label)
	_layout_static_hud()
	_layout_bottom_hud()

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
	if buff_select.has_signal("buff_chosen") and not buff_select.buff_chosen.is_connected(_on_buff_chosen):
		buff_select.buff_chosen.connect(_on_buff_chosen)
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and not achievement_manager.achievement_unlocked.is_connected(_on_achievement_unlocked):
		achievement_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	set_process(true)
	settings_menu = SettingsMenu.new()
	settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_menu)
	if not settings_menu.close_requested.is_connected(_on_menu_closed):
		settings_menu.close_requested.connect(_on_menu_closed)
	_ensure_home_arrow()


func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "%s: %d/%d" % [LocaleManager.L("hp"), current, max_hp]
	var ratio = float(current) / float(max(max_hp, 1))
	hp_bar_fill.size.x = HP_BAR_SIZE.x * clampf(ratio, 0.0, 1.0)
	hp_bar_fill.color = Color(0.85, 0.15, 0.15, 1.0) if ratio > 0.25 else Color(1.0, 0.1, 0.1, 1.0)


func bind_player(new_player) -> void:
	var skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system != null and skill_system.skills_changed.is_connected(_refresh_skill_slots):
		skill_system.skills_changed.disconnect(_refresh_skill_slots)

	player = new_player
	inventory = player.inventory
	player.interaction_prompt_changed.connect(show_interaction_prompt)
	player.interaction_prompt_cleared.connect(hide_interaction_prompt)
	player.hp_changed.connect(update_hp)
	inventory.inventory_changed.connect(_on_inventory_changed)
	player.equipment_system.equipment_changed.connect(_on_equipment_changed)
	player.building_system.build_state_changed.connect(_refresh_debug_label)
	player.crafting_requested.connect(_on_crafting_requested)
	player.storage_requested.connect(_on_storage_requested)
	player.repair_requested.connect(_on_repair_requested)
	player.talent_requested.connect(_on_talent_requested)
	player.equipment_panel_requested.connect(_on_equipment_requested)
	player.buffs_changed.connect(_refresh_buff_icons)
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
	_refresh_skill_slots()


func bind_level(level, level_id: String) -> void:
	current_level = level
	current_level_id = level_id
	minimap.visible = level_id == "dungeon"
	if level_id != "overworld":
		set_raid_countdown("", Color(1.0, 0.15, 0.15, 1.0), false)


func _unhandled_input(event: InputEvent) -> void:
	if _is_modal_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("toggle_equipment") or event.is_action_pressed("toggle_skills"):
			_close_all_menus()
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
		var _g := inventory.get_item_count("gold")
		var _s := inventory.get_item_count("silver")
		var _c := inventory.get_item_count("copper")
		currency_label.text = "%dG %dS %dC" % [_g, _s, _c]
	if player != null and player.has_method("get_consumable_slots"):
		update_consumable_bar(player.get_consumable_slots())
	_sync_achievement_equipment_state()
	rebuild_inventory_grid()


func _on_equipment_changed() -> void:
	_sync_achievement_equipment_state()


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
	floor_label.text = LocaleManager.L("floor") + ": %d" % current_floor if current_floor > 0 else ""
	day_label.visible = current_floor <= 0


func update_kills_label(kills: int) -> void:
	kills_label.text = LocaleManager.L("kills") + ": %d" % kills if kills > 0 else ""


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
	var recipe_filter := PackedStringArray()
	var menu_title := LocaleManager.L("crafting_title")
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


func _close_all_menus() -> void:
	inventory_panel.visible = false
	crafting_menu.close_menu()
	storage_ui.close_menu()
	repair_ui.close_menu()
	talent_tree.close_menu()
	equipment_panel.close_menu()
	skill_equip_ui.close_menu()
	achievement_panel.close_panel()
	buff_select.close_menu()
	if settings_menu != null and settings_menu.visible:
		settings_menu.close_menu()
	_on_menu_closed()


func _on_menu_closed() -> void:
	get_tree().paused = false
	release_focus()
	if player != null:
		player.set_ui_blocked(false)


func _is_modal_open() -> bool:
	return crafting_menu.visible or storage_ui.visible or repair_ui.visible or talent_tree.visible or equipment_panel.visible or skill_equip_ui.visible or achievement_panel.visible or buff_select.visible or (settings_menu != null and settings_menu.visible)


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


func _process(_delta: float) -> void:
	if current_level_id == "dungeon" and current_level != null and current_level.has_method("get_minimap_snapshot"):
		minimap.visible = true
		minimap.set_snapshot(current_level.get_minimap_snapshot())
	else:
		minimap.visible = false
	_refresh_skill_slots()


func rebuild_inventory_grid() -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	if inventory == null:
		return

	var groups := {
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
		var header := Label.new()
		header.text = LocaleManager.L(str((groups[type_id] as Dictionary).get("title", type_id)))
		header.modulate = Color(0.95, 0.9, 0.7, 1.0)
		inventory_list.add_child(header)
		for stack in section_items:
			var item_color := ITEM_DATABASE.get_item_color(str(stack.get("id", "")), str(stack.get("type", "")))
			inventory_list.add_child(_build_item_row(stack, item_color))


func _build_item_row(stack: Dictionary, _swatch_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(200, 24)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_build_item_icon_holder(stack))
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	name_label.self_modulate = ITEM_DATABASE.get_stack_color(stack)
	row.add_child(name_label)
	var quantity_label := Label.new()
	quantity_label.text = "x%d" % int(stack.get("quantity", 0))
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(quantity_label)
	return row


func _build_item_icon_holder(stack: Dictionary) -> Control:
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	if icon != null:
		var icon_tex := TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(16, 16)
		icon_tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_tex.texture = icon
		return icon_tex
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.color = ITEM_DATABASE.get_stack_color(stack)
	return swatch


func open_buff_selection(options: Array, level) -> void:
	current_level = level
	buff_select.open_with_options(options)
	if player != null:
		player.set_ui_blocked(true)
	if current_level != null and current_level.has_method("set_gameplay_paused"):
		current_level.set_gameplay_paused(true)


func _on_buff_chosen(buff_id: String) -> void:
	if player != null:
		player.apply_buff(buff_id)
		player.set_ui_blocked(false)
	if current_level != null and current_level.has_method("set_gameplay_paused"):
		current_level.set_gameplay_paused(false)


func _refresh_buff_icons(active_buffs: Array) -> void:
	for child in buff_row.get_children():
		child.queue_free()
	for buff in active_buffs:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.color = buff.get("color", Color.WHITE)
		swatch.tooltip_text = LocaleManager.L(str(buff.get("name", "Buff")))
		buff_row.add_child(swatch)


func show_death_screen(summary: Dictionary) -> void:
	death_overlay.visible = true
	death_summary_label.text = LocaleManager.L("death_summary") % [
		int(summary.get("floor", 0)),
		int(summary.get("kills", 0)),
	]


func hide_death_screen() -> void:
	death_overlay.visible = false


func show_event_banner(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	event_banner.text = message
	event_banner.modulate = Color(color.r, color.g, color.b, 0.0)
	event_banner.visible = true
	var tween := create_tween()
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
	var tween := create_tween()
	tween.tween_property(raid_border, "color", Color(color.r, color.g, color.b, 0.55), 0.08)
	tween.tween_property(raid_border, "color", Color(color.r, color.g, color.b, 0.0), 0.25)
	tween.tween_callback(func() -> void: raid_border.visible = false)


func show_status_message(message: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	status_label.text = message
	status_label.modulate = Color(color.r, color.g, color.b, 0.0)
	status_label.visible = true
	var tween := create_tween()
	tween.tween_property(status_label, "modulate", color, 0.08)
	tween.tween_interval(duration)
	tween.tween_property(status_label, "modulate", Color(color.r, color.g, color.b, 0.0), 0.25)
	tween.tween_callback(func() -> void: status_label.visible = false)


func update_day_label(day_number: int) -> void:
	day_label.text = LocaleManager.L("days") + ": %d" % max(day_number, 1)
	day_label.visible = true


func update_consumable_bar(slots: Array) -> void:
	var labels: Array[String] = []
	for slot_index in range(2):
		var slot: Dictionary = slots[slot_index] if slot_index < slots.size() else {}
		var key_name = "Q" if slot_index == 0 else "R"
		if slot.is_empty():
			labels.append(LocaleManager.L("consumable_empty") % key_name)
			continue
		labels.append("[%s] %s x%d" % [key_name, ITEM_DATABASE.get_stack_display_name(slot), int(slot.get("quantity", 0))])
	consumable_bar.text = " | ".join(labels)
	_layout_bottom_hud()


func _refresh_skill_slots() -> void:
	if skill_slot_row == null:
		return
	for child in skill_slot_row.get_children():
		child.queue_free()
	var skill_system = get_node_or_null("/root/SkillSystem")
	if skill_system == null:
		return
	var snapshots = skill_system.get_equipped_skill_snapshots()
	const SLOT_W := 70.0
	const SLOT_H := 36.0
	const KEY_NAMES := ["Z", "X", "V"]
	for slot_index in range(3):
		var slot: Dictionary = snapshots[slot_index] if slot_index < snapshots.size() else {}
		var key_name: String = KEY_NAMES[slot_index]

		var container := Control.new()
		container.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		container.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

		var bg := ColorRect.new()
		bg.position = Vector2.ZERO
		bg.size = Vector2(SLOT_W, SLOT_H)
		bg.color = Color(0.08, 0.08, 0.1, 0.88)
		container.add_child(bg)

		var skill_label := Label.new()
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
		else:
			var cooldown := float(slot.get("current_cooldown", 0.0))
			var max_cooldown := maxf(float(slot.get("cooldown", 1.0)), 0.001)
			var short_name := LocaleManager.L(str(slot.get("short_name", "skill_name_fallback")))
			skill_label.text = "[%s]\n%s" % [key_name, short_name]
			skill_label.self_modulate = Color(0.65, 0.65, 0.65, 1.0) if cooldown > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
			skill_label.tooltip_text = LocaleManager.L(str(slot.get("name", "skill_name_fallback")))
			container.add_child(skill_label)

			if cooldown > 0.0:
				var ratio := clampf(cooldown / max_cooldown, 0.0, 1.0)
				var overlay := ColorRect.new()
				overlay.position = Vector2.ZERO
				overlay.size = Vector2(SLOT_W, SLOT_H * ratio)
				overlay.color = Color(0.0, 0.0, 0.0, 0.62)
				container.add_child(overlay)

				var cd_label := Label.new()
				cd_label.position = Vector2.ZERO
				cd_label.size = Vector2(SLOT_W, SLOT_H)
				cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cd_label.text = "%.1f" % cooldown
				cd_label.add_theme_font_size_override("font_size", 12)
				cd_label.add_theme_constant_override("outline_size", 3)
				cd_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
				cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
				container.add_child(cd_label)

		skill_slot_row.add_child(container)

	var has_unequipped := false
	for skill_id in skill_system.unlocked_skill_ids:
		var is_passive := bool((skill_system.skills.get(skill_id, {}) as Dictionary).get("passive", false))
		if not is_passive and not skill_system.equipped_skill_ids.has(skill_id):
			has_unequipped = true
			break
	if has_unequipped:
		var hint := Label.new()
		hint.text = LocaleManager.L("press_k_equip")
		hint.add_theme_constant_override("outline_size", 2)
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		skill_slot_row.add_child(hint)
	_layout_bottom_hud.call_deferred()


func play_transition(message: String, overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.25, hold_duration: float = 0.0) -> void:
	transition_label.text = message
	transition_label.modulate = Color.WHITE
	transition_overlay.color = Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0)
	transition_overlay.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 1.0), fade_duration)
	await fade_in.finished
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	var fade_out := create_tween()
	fade_out.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0), fade_duration)
	await fade_out.finished
	transition_overlay.visible = false


func fade_to_black(message: String, overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.5) -> void:
	transition_label.text = message
	transition_label.modulate = Color.WHITE
	transition_overlay.color = Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0)
	transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color", Color(overlay_color.r, overlay_color.g, overlay_color.b, 1.0), fade_duration)
	await tween.finished


func fade_from_black(overlay_color: Color = Color(0, 0, 0, 1), fade_duration: float = 0.5) -> void:
	var tween := create_tween()
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
	var hp_y := HUD_TOP_MARGIN
	var hp_label_w := 160.0
	var hp_bar_x := HUD_LEFT_MARGIN + hp_label_w + 4.0
	var class_x := hp_bar_x + HP_BAR_SIZE.x + 6.0
	_set_control_rect(hp_label, Vector2(HUD_LEFT_MARGIN, hp_y), Vector2(hp_label_w, HUD_LINE_HEIGHT))
	_set_control_rect(hp_bar_bg, Vector2(hp_bar_x, hp_y + 4.0), HP_BAR_SIZE)
	_set_control_rect(class_label, Vector2(class_x, hp_y), CLASS_LABEL_SIZE)
	hp_bar_fill.position = Vector2.ZERO
	hp_bar_fill.size = Vector2(HP_BAR_SIZE.x, HP_BAR_SIZE.y)

	# Info rows start below HP row — each on its own line, no overlap
	var info_y := hp_y + HUD_LINE_HEIGHT + 4.0
	_set_control_rect(bag_label, Vector2(HUD_LEFT_MARGIN, info_y), INFO_LABEL_SIZE)
	_set_control_rect(floor_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT), INFO_LABEL_SIZE)
	_set_control_rect(kills_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 2.0), INFO_LABEL_SIZE)
	_set_control_rect(day_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 3.0), INFO_LABEL_SIZE)
	_set_control_rect(currency_label, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 4.0), INFO_LABEL_SIZE)
	_set_control_rect(buff_row, Vector2(HUD_LEFT_MARGIN, info_y + HUD_LINE_HEIGHT * 5.0), BUFF_ROW_SIZE)


func _set_control_rect(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = pos
	control.size = rect_size


func _center_skill_slot_row() -> void:
	if skill_slot_row == null:
		return
	var row_size := skill_slot_row.get_combined_minimum_size()
	row_size.x = maxf(row_size.x, 210.0)
	row_size.y = maxf(row_size.y, 36.0)
	skill_slot_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_slot_row.position = Vector2(-row_size.x * 0.5, -SKILL_ROW_BOTTOM_MARGIN - row_size.y)
	skill_slot_row.size = row_size


func _layout_bottom_hud() -> void:
	_center_skill_slot_row()
	if consumable_bar == null:
		return
	var bar_size := consumable_bar.get_combined_minimum_size()
	bar_size.x = maxf(bar_size.x, 220.0)
	bar_size.y = maxf(bar_size.y, 24.0)
	consumable_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	consumable_bar.position = Vector2(-bar_size.x * 0.5, -CONSUMABLE_BAR_BOTTOM_MARGIN - bar_size.y)
	consumable_bar.size = bar_size
	if skill_slot_row != null:
		var skill_bottom := skill_slot_row.position.y + skill_slot_row.size.y
		var consumable_top := consumable_bar.position.y
		if consumable_top < skill_bottom + BOTTOM_UI_GAP:
			consumable_bar.position.y = skill_bottom + BOTTOM_UI_GAP


func _on_hud_resized() -> void:
	_layout_bottom_hud.call_deferred()
