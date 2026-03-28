extends Control

const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal close_requested

@onready var panel_container: PanelContainer = $PanelContainer

@onready var recipe_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/MainColumns/RecipeVBox/RecipeScroll/RecipeListContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleRow/TitleLabel
@onready var detail_text: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/MainColumns/DetailVBox/DetailText
@onready var materials_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/MainColumns/DetailVBox/MaterialsContainer
@onready var craft_button: Button = $PanelContainer/MarginContainer/VBoxContainer/MainColumns/DetailVBox/CraftButton
@onready var flash_rect: ColorRect = $FlashRect
@onready var detail_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/MainColumns/DetailVBox

var player_inventory = null
var player = null
var facility = null
var recipe_ids: PackedStringArray = []
var selected_recipe_id: String = ""
var filtered_recipe_ids: PackedStringArray = []
var menu_title: String = ""
var recipe_buttons: Dictionary = {}
var upgrade_label: Label = null
var upgrade_button: Button = null
var _current_category: String = "all"
var _category_tab_buttons: Dictionary = {}
var _tabs_built: bool = false
var _repair_selected_slot: String = ""
var _repair_selected_inv_index: int = -1
var _repair_placeholder: Label = null
var _repair_name_lbl: Label = null
var _repair_dur_bg: ColorRect = null
var _repair_dur_fill: ColorRect = null
var _repair_dur_lbl: Label = null
var _repair_cost_lbl: Label = null
var _repair_action_btn: Button = null
var _repair_widgets_built: bool = false

const CATEGORY_KEY_MAP = {
	"Armor": "cat_armor",
	"Weapons": "cat_weapons",
	"Consumables": "cat_consumables",
	"Cooking": "cat_cooking",
	"Tools": "cat_tools"
}

const STAT_KEY_MAP = {
	"Defense": "stat_defense_name",
	"Attack": "stat_attack_name",
	"Slot": "stat_slot",
	"Head": "stat_head",
	"Body": "stat_body",
	"Hands": "stat_hands",
	"Feet": "stat_feet",
	"Main Hand": "stat_main_hand",
	"Off Hand": "stat_off_hand",
	"Heal": "stat_heal"
}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_button.pressed.connect(_on_craft_pressed)
	craft_button.text = LocaleManager.L("craft")
	_ensure_close_button()
	_ensure_upgrade_controls()
	var cm_style: StyleBoxFlat = StyleBoxFlat.new()
	cm_style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	cm_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	cm_style.border_width_left = 1
	cm_style.border_width_top = 1
	cm_style.border_width_right = 1
	cm_style.border_width_bottom = 1
	panel_container.add_theme_stylebox_override("panel", cm_style)


func open_for_player(target_player, available_recipe_ids: PackedStringArray = PackedStringArray(), title: String = "", target_facility = null) -> void:
	player = target_player
	player_inventory = player.inventory if player != null else null
	facility = target_facility
	filtered_recipe_ids = available_recipe_ids
	menu_title = title if title != "" else LocaleManager.L("crafting_title")
	_current_category = "all"
	_tabs_built = false
	_category_tab_buttons.clear()
	visible = true
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	_build_category_tabs()
	_rebuild_recipe_list()
	if not recipe_ids.is_empty():
		_on_recipe_button_pressed(recipe_ids[0])
	else:
		_refresh_upgrade_controls()


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


func _rebuild_recipe_list() -> void:
	for child in recipe_list_container.get_children():
		child.queue_free()
	recipe_ids.clear()
	recipe_buttons.clear()
	title_label.text = menu_title
	title_label.add_theme_font_size_override("font_size", 22)
	if _current_category == "repair":
		_apply_repair_mode_layout(true)
		_ensure_repair_widgets()
		_build_repair_list()
		_refresh_category_tab_visuals()
		return
	_apply_repair_mode_layout(false)
	var recipes: Array[Dictionary] = CRAFTING_SYSTEM.get_available_recipes_for_ids(filtered_recipe_ids) if not filtered_recipe_ids.is_empty() else CRAFTING_SYSTEM.get_available_recipes()
	var grouped: Dictionary = {}
	for recipe in recipes:
		var category: String = str(recipe.get("category", "Crafting"))
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(recipe)
	var category_names: Array = grouped.keys()
	category_names.sort()
	for category_name in category_names:
		# Skip categories not matching the active tab (unless "all" is selected)
		if _current_category != "all" and str(category_name) != _current_category:
			continue
		var header: Label = Label.new()
		var translated_name: String = _translate_category(str(category_name))
		header.text = LocaleManager.L("crafting_category_header") % translated_name
		header.modulate = Color(0.95, 0.9, 0.65, 1.0)
		recipe_list_container.add_child(header)
		for recipe in grouped[category_name]:
			var recipe_id: String = str(recipe["id"])
			recipe_ids.append(recipe_id)
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var icon_holder: Control = _build_item_icon_holder(ITEM_DATABASE.get_item(str(recipe.get("result_item_id", ""))))
			row.add_child(icon_holder)
			var button: Button = Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.text = "%s (%s)" % [str(recipe["name"]), _format_cost_summary(recipe_id)]
			button.pressed.connect(_on_recipe_button_pressed.bind(recipe_id))
			recipe_buttons[recipe_id] = button
			row.add_child(button)
			recipe_list_container.add_child(row)
	_refresh_category_tab_visuals()


func _on_recipe_button_pressed(recipe_id: String) -> void:
	selected_recipe_id = recipe_id
	_refresh_recipe_button_states()
	_refresh_details()


func _refresh_details() -> void:
	if selected_recipe_id == "" or player_inventory == null:
		detail_text.text = ""
		_clear_material_rows()
		craft_button.disabled = true
		return

	var recipe: Dictionary = CRAFTING_SYSTEM.get_recipe(selected_recipe_id)
	var cost_multiplier: float = player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0
	var cost := CRAFTING_SYSTEM.get_recipe_cost(selected_recipe_id, cost_multiplier)
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % str(recipe.get("name", selected_recipe_id)))
	if recipe.get("result_type", "") == "equipment":
		for stat_id in recipe.get("stats", {}).keys():
			lines.append("%s: +%s" % [_pretty_name(stat_id), str(recipe["stats"][stat_id])])
		if recipe.has("max_durability"):
			lines.append(LocaleManager.L("durability_label") % [int(recipe.get("durability", recipe.get("max_durability", 0))), int(recipe.get("max_durability", 0))])
		if recipe.has("slot"):
			lines.append(LocaleManager.L("slot_label") % _pretty_name(str(recipe.get("slot", ""))))
	else:
		for effect_id in recipe.get("effect", {}).keys():
			lines.append("%s: %s" % [_pretty_name(effect_id), str(recipe["effect"][effect_id])])
	lines.append("")
	lines.append(LocaleManager.L("materials_header"))
	for resource_id in cost.keys():
		var required: int = int(cost[resource_id])
		var owned: int = player_inventory.get_item_count(resource_id)
		lines.append("%s" % _pretty_name(resource_id))

	detail_text.bbcode_enabled = true
	detail_text.text = "\n".join(lines)
	_rebuild_material_rows(cost)
	craft_button.disabled = not CRAFTING_SYSTEM.can_craft(selected_recipe_id, player_inventory, cost_multiplier)
	craft_button.modulate = Color(0.45, 0.95, 0.45, 1.0) if not craft_button.disabled else Color(0.55, 0.55, 0.55, 1.0)
	_refresh_recipe_button_states()
	_refresh_upgrade_controls()


func _on_craft_pressed() -> void:
	if selected_recipe_id == "" or player_inventory == null:
		return
	var cost_multiplier: float = player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0
	if CRAFTING_SYSTEM.craft(selected_recipe_id, player_inventory, cost_multiplier):
		_refresh_details()
		_play_flash()


func _on_upgrade_pressed() -> void:
	if facility == null or player == null or not facility.has_method("try_upgrade"):
		return
	if facility.try_upgrade(player):
		_rebuild_recipe_list()
		if recipe_ids.is_empty():
			_refresh_details()
			return
		var next_recipe := selected_recipe_id if recipe_ids.has(selected_recipe_id) else recipe_ids[0]
		_on_recipe_button_pressed(next_recipe)
		_play_flash()


func _play_flash() -> void:
	flash_rect.color = Color(1, 1, 0.8, 0.0)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1, 1, 0.8, 0.25), 0.08)
	tween.tween_property(flash_rect, "color", Color(1, 1, 0.8, 0.0), 0.18)


func _translate_category(category_name: String) -> String:
	var key: String = CATEGORY_KEY_MAP.get(category_name, "")
	if key != "":
		return LocaleManager.L(key)
	return category_name


func _translate_stat(stat_name: String) -> String:
	var key: String = STAT_KEY_MAP.get(stat_name, "")
	if key != "":
		return LocaleManager.L(key)
	return stat_name


func _pretty_name(value: String) -> String:
	var display_name: String = ITEM_DATABASE.get_display_name(value)
	if display_name != value:
		return display_name
	var capitalized: String = value.replace("_", " ").capitalize()
	return _translate_stat(capitalized)


func _format_cost_summary(recipe_id: String) -> String:
	var cost := CRAFTING_SYSTEM.get_recipe_cost(recipe_id, player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0)
	var parts: PackedStringArray = []
	for resource_id in cost.keys():
		parts.append("%d %s" % [int(cost[resource_id]), _pretty_name(str(resource_id))])
	return ", ".join(parts)


func _refresh_recipe_button_states() -> void:
	for recipe_id in recipe_buttons.keys():
		var button: Button = recipe_buttons[recipe_id]
		var can_make := player_inventory != null and CRAFTING_SYSTEM.can_craft(str(recipe_id), player_inventory, player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0)
		button.modulate = Color(0.45, 1.0, 0.45, 1.0) if can_make else Color(0.7, 0.7, 0.7, 1.0)
		if str(recipe_id) == selected_recipe_id:
			button.modulate = Color(1.0, 0.95, 0.55, 1.0)


func _rebuild_material_rows(cost: Dictionary) -> void:
	_clear_material_rows()
	for resource_id in cost.keys():
		var required: int = int(cost[resource_id])
		var owned: int = player_inventory.get_item_count(str(resource_id))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var mat_data := ITEM_DATABASE.get_item(str(resource_id))
		row.add_child(_build_item_icon_holder(mat_data))
		var label := Label.new()
		var suffix := LocaleManager.L("crafting_material_ok") if owned >= required else ""
		label.text = LocaleManager.L("crafting_material_progress") % [_pretty_name(str(resource_id)), owned, required, suffix]
		label.modulate = Color(0.45, 1.0, 0.45, 1.0) if owned >= required else Color(1.0, 0.45, 0.45, 1.0)
		row.add_child(label)
		materials_container.add_child(row)


func _clear_material_rows() -> void:
	for child in materials_container.get_children():
		child.queue_free()


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
	swatch.color = ITEM_DATABASE.get_stack_color(stack) if not stack.is_empty() else Color(0.22, 0.22, 0.22, 1.0)
	return swatch


func _ensure_close_button() -> void:
	var title_row: HBoxContainer = panel_container.get_node_or_null("MarginContainer/VBoxContainer/TitleRow") as HBoxContainer
	if title_row == null or title_row.get_node_or_null("CloseButton") != null:
		return
	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(close_menu)
	var cb_normal: StyleBoxFlat = StyleBoxFlat.new()
	cb_normal.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	cb_normal.border_color = Color(0.3, 0.3, 0.35, 1.0)
	cb_normal.border_width_left = 1
	cb_normal.border_width_top = 1
	cb_normal.border_width_right = 1
	cb_normal.border_width_bottom = 1
	var cb_hover: StyleBoxFlat = cb_normal.duplicate()
	cb_hover.bg_color = Color(0.28, 0.28, 0.34, 0.95)
	close_button.add_theme_stylebox_override("normal", cb_normal)
	close_button.add_theme_stylebox_override("hover", cb_hover)
	title_row.add_child(close_button)


func _ensure_upgrade_controls() -> void:
	if detail_vbox == null or upgrade_label != null:
		return
	upgrade_label = Label.new()
	upgrade_label.visible = false
	upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(upgrade_label)
	detail_vbox.move_child(upgrade_label, detail_vbox.get_child_count() - 1)

	upgrade_button = Button.new()
	upgrade_button.visible = false
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	detail_vbox.add_child(upgrade_button)
	detail_vbox.move_child(upgrade_button, detail_vbox.get_child_count() - 1)


func _refresh_upgrade_controls() -> void:
	if upgrade_label == null or upgrade_button == null:
		return
	if facility == null or not facility.has_method("can_upgrade") or not facility.can_upgrade():
		upgrade_label.visible = false
		upgrade_button.visible = false
		return
	var cost: Dictionary = facility.get_upgrade_cost() if facility.has_method("get_upgrade_cost") else {}
	var parts: PackedStringArray = []
	var can_afford: bool = true
	for resource_id in cost.keys():
		var required: int = int(cost[resource_id])
		var owned: int = player_inventory.get_item_count(str(resource_id)) if player_inventory != null else 0
		parts.append("%s %d/%d" % [_pretty_name(str(resource_id)), owned, required])
		if owned < required:
			can_afford = false
	upgrade_label.text = "%s\n%s: %s" % [facility.get_upgrade_summary() if facility.has_method("get_upgrade_summary") else "", LocaleManager.L("upgrade_cost"), ", ".join(parts)]
	upgrade_label.visible = true
	upgrade_button.text = facility.get_upgrade_button_text() if facility.has_method("get_upgrade_button_text") else LocaleManager.L("upgrade_to_lv") % 2
	upgrade_button.disabled = not can_afford
	upgrade_button.visible = true


# ---------------------------------------------------------------------------
# Category tab bar
# ---------------------------------------------------------------------------
func _build_category_tabs() -> void:
	var category_vbox: VBoxContainer = panel_container.get_node_or_null(
			"MarginContainer/VBoxContainer/MainColumns/CategoryVBox") as VBoxContainer
	if category_vbox == null:
		return
	for child: Node in category_vbox.get_children():
		child.queue_free()
	_category_tab_buttons.clear()
	_tabs_built = true

	var cat_keys: Array[String] = []
	if facility != null and facility is CookingBenchFacility:
		cat_keys = ["all", "Cooking"]
	else:
		cat_keys = ["all", "Weapons", "Armor", "Consumables", "Tools", "repair"]
	for cat_key: String in cat_keys:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn_text: String = "All"
		if cat_key != "all":
			if cat_key == "repair":
				btn_text = LocaleManager.L("repair")
			else:
				btn_text = _translate_category(cat_key)
		btn.text = btn_text
		btn.pressed.connect(_on_category_tab_pressed.bind(cat_key))
		_category_tab_buttons[cat_key] = btn
		category_vbox.add_child(btn)
	_refresh_category_tab_visuals()


func _on_category_tab_pressed(category: String) -> void:
	_current_category = category
	_rebuild_recipe_list()
	if not recipe_ids.is_empty():
		_on_recipe_button_pressed(recipe_ids[0])
	else:
		selected_recipe_id = ""
		_refresh_details()


func _refresh_category_tab_visuals() -> void:
	for cat_key in _category_tab_buttons.keys():
		var btn: Button = _category_tab_buttons[cat_key] as Button
		if btn == null:
			continue
		if str(cat_key) == _current_category:
			btn.modulate = Color(1.0, 0.85, 0.2, 1.0)
		else:
			btn.modulate = Color(0.75, 0.75, 0.75, 1.0)


# ---------------------------------------------------------------------------
# Repair tab
# ---------------------------------------------------------------------------
func _apply_repair_mode_layout(is_repair: bool) -> void:
	detail_text.visible = not is_repair
	materials_container.visible = not is_repair
	craft_button.visible = not is_repair
	if upgrade_label != null:
		upgrade_label.visible = false
	if upgrade_button != null:
		upgrade_button.visible = false
	if not _repair_widgets_built:
		return
	_repair_placeholder.visible = is_repair
	_repair_name_lbl.visible = false
	_repair_dur_bg.visible = false
	_repair_dur_lbl.visible = false
	_repair_cost_lbl.visible = false
	_repair_action_btn.visible = false


func _ensure_repair_widgets() -> void:
	if _repair_widgets_built:
		return
	_repair_placeholder = Label.new()
	_repair_placeholder.text = LocaleManager.L("repair_prompt")
	_repair_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repair_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_repair_placeholder)

	_repair_name_lbl = Label.new()
	_repair_name_lbl.visible = false
	_repair_name_lbl.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(_repair_name_lbl)

	_repair_dur_bg = ColorRect.new()
	_repair_dur_bg.visible = false
	_repair_dur_bg.custom_minimum_size = Vector2(0, 14)
	_repair_dur_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair_dur_bg.color = Color(0.18, 0.18, 0.2, 1.0)
	_repair_dur_fill = ColorRect.new()
	_repair_dur_fill.anchor_top = 0.0
	_repair_dur_fill.anchor_bottom = 1.0
	_repair_dur_fill.anchor_left = 0.0
	_repair_dur_fill.anchor_right = 0.0
	_repair_dur_fill.color = Color(0.45, 1.0, 0.45, 1.0)
	_repair_dur_bg.add_child(_repair_dur_fill)
	detail_vbox.add_child(_repair_dur_bg)

	_repair_dur_lbl = Label.new()
	_repair_dur_lbl.visible = false
	_repair_dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(_repair_dur_lbl)

	_repair_cost_lbl = Label.new()
	_repair_cost_lbl.visible = false
	_repair_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(_repair_cost_lbl)

	_repair_action_btn = Button.new()
	_repair_action_btn.visible = false
	_repair_action_btn.text = LocaleManager.L("repair")
	_repair_action_btn.pressed.connect(_on_repair_detail_pressed)
	detail_vbox.add_child(_repair_action_btn)

	_repair_widgets_built = true


func _build_repair_list() -> void:
	if player == null:
		_populate_repair_detail()
		return
	for slot_name: String in player.equipment_system.get_slot_order():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		if item.is_empty():
			continue
		recipe_list_container.add_child(_build_repair_row(item, slot_name, -1))
	for index: int in range(player.inventory.items.size()):
		var item: Dictionary = player.inventory.items[index]
		if str(item.get("type", "")) != "equipment":
			continue
		if int(item.get("max_durability", 0)) <= 0:
			continue
		recipe_list_container.add_child(_build_repair_row(item, "", index))
	_populate_repair_detail()


func _build_repair_row(item: Dictionary, slot_name: String, inv_idx: int) -> Button:
	var row_btn: Button = Button.new()
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.flat = true

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_build_item_icon_holder(item))

	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 4)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label_text: String = _repair_get_display_name(item)
	if slot_name != "":
		label_text = "%s [%s]" % [label_text, _repair_translate_slot(slot_name)]
	else:
		label_text = "%s [%s]" % [label_text, LocaleManager.L("inventory_short")]
	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.self_modulate = player.equipment_system.get_item_display_color(item)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.add_child(name_lbl)

	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var dur_ratio: float = clampf(float(dur) / float(maxi(max_dur, 1)), 0.0, 1.0)
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.18, 0.18, 0.2, 1.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_fill: ColorRect = ColorRect.new()
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = dur_ratio
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dur <= 0:
		bar_fill.color = Color(1.0, 0.3, 0.3, 1.0)
	elif dur >= max_dur:
		bar_fill.color = Color(0.45, 1.0, 0.45, 1.0)
	else:
		bar_fill.color = Color(1.0, 0.75, 0.3, 1.0)
	bar_bg.add_child(bar_fill)
	info_col.add_child(bar_bg)
	hbox.add_child(info_col)
	row_btn.add_child(hbox)

	if slot_name != "":
		var sn: String = slot_name
		row_btn.pressed.connect(func() -> void: _set_repair_selection(sn, -1))
	else:
		var idx: int = inv_idx
		row_btn.pressed.connect(func() -> void: _set_repair_selection("", idx))
	return row_btn


func _set_repair_selection(slot: String, inv_idx: int) -> void:
	_repair_selected_slot = slot
	_repair_selected_inv_index = inv_idx
	_populate_repair_detail()


func _populate_repair_detail() -> void:
	if not _repair_widgets_built:
		return
	var has_selection: bool = _repair_selected_slot != "" or _repair_selected_inv_index >= 0
	if not has_selection or player == null:
		_repair_placeholder.text = LocaleManager.L("repair_prompt")
		_repair_placeholder.visible = true
		_repair_name_lbl.visible = false
		_repair_dur_bg.visible = false
		_repair_dur_lbl.visible = false
		_repair_cost_lbl.visible = false
		_repair_action_btn.visible = false
		return

	var item: Dictionary = {}
	var slot_label: String = ""
	var repair_cost_multiplier: float = _get_repair_cost_multiplier()

	if _repair_selected_slot != "":
		item = player.equipment_system.get_equipped(_repair_selected_slot)
		slot_label = _repair_translate_slot(_repair_selected_slot)
	elif _repair_selected_inv_index >= 0 and _repair_selected_inv_index < player.inventory.items.size():
		item = player.inventory.items[_repair_selected_inv_index]
		slot_label = LocaleManager.L("inventory_short")

	if item.is_empty():
		_repair_selected_slot = ""
		_repair_selected_inv_index = -1
		_populate_repair_detail()
		return

	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var dur_ratio: float = clampf(float(dur) / float(maxi(max_dur, 1)), 0.0, 1.0)

	_repair_placeholder.visible = false
	_repair_name_lbl.text = "%s [%s]" % [_repair_get_display_name(item), slot_label]
	_repair_name_lbl.self_modulate = player.equipment_system.get_item_display_color(item)
	_repair_name_lbl.visible = true
	_repair_dur_fill.anchor_right = dur_ratio
	if dur <= 0:
		_repair_dur_fill.color = Color(1.0, 0.3, 0.3, 1.0)
	elif dur >= max_dur:
		_repair_dur_fill.color = Color(0.45, 1.0, 0.45, 1.0)
	else:
		_repair_dur_fill.color = Color(1.0, 0.75, 0.3, 1.0)
	_repair_dur_bg.visible = true
	_repair_dur_lbl.text = LocaleManager.L("durability_label") % [dur, max_dur]
	_repair_dur_lbl.visible = true

	if _repair_selected_slot != "":
		var cost: Dictionary = player.equipment_system.get_repair_cost(_repair_selected_slot).duplicate()
		for k: String in cost.keys():
			cost[k] = maxi(int(ceil(float(cost[k]) * repair_cost_multiplier)), 1)
		if not cost.is_empty():
			var cost_parts: PackedStringArray = []
			var can_afford: bool = true
			for resource_id: String in cost.keys():
				cost_parts.append("%d %s" % [int(cost[resource_id]), ITEM_DATABASE.get_display_name(str(resource_id))])
				if player.inventory.get_item_count(str(resource_id)) < int(cost[resource_id]):
					can_afford = false
			_repair_cost_lbl.text = LocaleManager.L("repair_cost_fmt") % ", ".join(cost_parts)
			_repair_cost_lbl.visible = true
			_repair_action_btn.disabled = not can_afford
			_repair_action_btn.visible = dur < max_dur
		else:
			_repair_cost_lbl.visible = false
			_repair_action_btn.visible = false
	else:
		var lost: int = maxi(max_dur - dur, 0)
		if lost > 0:
			var material: String = str(player.equipment_system.get_repair_material("", item))
			var cost_amount: int = maxi(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
			var can_afford: bool = player.inventory.get_item_count(material) >= cost_amount
			_repair_cost_lbl.text = LocaleManager.L("repair_cost_single_fmt") % [cost_amount, ITEM_DATABASE.get_display_name(material)]
			_repair_cost_lbl.visible = true
			_repair_action_btn.disabled = not can_afford
			_repair_action_btn.visible = true
		else:
			_repair_cost_lbl.visible = false
			_repair_action_btn.visible = false


func _on_repair_detail_pressed() -> void:
	if _repair_selected_slot != "":
		if player != null and player.equipment_system.repair_slot(_repair_selected_slot, player.inventory):
			_repair_selected_slot = ""
			_repair_selected_inv_index = -1
			_build_repair_list_refresh()
	elif _repair_selected_inv_index >= 0:
		_do_repair_inventory_item(_repair_selected_inv_index)
		_repair_selected_slot = ""
		_repair_selected_inv_index = -1
		_build_repair_list_refresh()


func _build_repair_list_refresh() -> void:
	for child: Node in recipe_list_container.get_children():
		child.queue_free()
	_build_repair_list()


func _do_repair_inventory_item(inv_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var item: Dictionary = player.inventory.items[inv_index]
	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var lost: int = maxi(max_dur - dur, 0)
	if lost <= 0:
		return
	var material: String = str(player.equipment_system.get_repair_material("", item))
	var repair_cost_multiplier: float = _get_repair_cost_multiplier()
	var cost_amount: int = maxi(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
	if player.inventory.get_item_count(material) < cost_amount:
		return
	player.inventory.remove_item(material, cost_amount)
	item["durability"] = max_dur
	player.inventory.inventory_changed.emit()


func _get_repair_cost_multiplier() -> float:
	var facility_multiplier: float = facility.get_repair_cost_multiplier() \
		if facility != null and facility.has_method("get_repair_cost_multiplier") else 1.0
	var npc_multiplier: float = NpcManager.get_repair_cost_multiplier() if NpcManager != null else 1.0
	return facility_multiplier * npc_multiplier


func _repair_get_display_name(item: Dictionary) -> String:
	var raw_name: String = str(item.get("name", ""))
	if raw_name != "":
		return raw_name
	var item_id: String = str(item.get("id", str(item.get("item_id", ""))))
	var db_name: String = ITEM_DATABASE.get_display_name(item_id)
	if db_name != "" and db_name != item_id:
		return db_name
	return item_id.replace("_", " ").capitalize()


func _repair_translate_slot(slot_name: String) -> String:
	match slot_name:
		"weapon":
			return LocaleManager.L("slot_weapon")
		"helmet":
			return LocaleManager.L("slot_helmet")
		"chest_armor":
			return LocaleManager.L("slot_chest_armor")
		"boots":
			return LocaleManager.L("slot_boots")
		"accessory":
			return LocaleManager.L("slot_accessory")
		"offhand":
			return LocaleManager.L("slot_offhand")
		"tool":
			return LocaleManager.L("slot_tool")
	return slot_name.replace("_", " ").capitalize()
