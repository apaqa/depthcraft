extends Control

const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

signal close_requested

@onready var panel_container: PanelContainer = $PanelContainer

@onready var recipe_list_container: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RecipePanel/RecipeScroll/RecipeListContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/TitleLabel
@onready var detail_text: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/DetailText
@onready var materials_container: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/MaterialsContainer
@onready var craft_button: Button = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/CraftButton
@onready var flash_rect: ColorRect = $FlashRect
@onready var detail_vbox: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer

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
	if _tabs_built:
		_refresh_category_tab_visuals()
		return
	var recipe_scroll: ScrollContainer = recipe_list_container.get_parent() as ScrollContainer
	if recipe_scroll == null:
		return
	var recipe_panel: Control = recipe_scroll.get_parent() as Control
	if recipe_panel == null:
		return

	var old_bar: Node = recipe_panel.get_node_or_null("CategoryTabs")
	if old_bar != null:
		old_bar.free()

	_tabs_built = true

	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.name = "CategoryTabs"
	tab_bar.add_theme_constant_override("separation", 4)

	var cat_keys: Array = []
	if facility != null and facility is CookingBenchFacility:
		cat_keys = ["all", "Cooking"]
	else:
		cat_keys = ["all", "Weapons", "Armor", "Consumables", "Tools"]
	for cat_key: Variant in cat_keys:
		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cat_key == "all":
			btn.text = "All"
		else:
			btn.text = _translate_category(str(cat_key))
		btn.pressed.connect(_on_category_tab_pressed.bind(str(cat_key)))
		_category_tab_buttons[str(cat_key)] = btn
		tab_bar.add_child(btn)

	recipe_panel.add_child(tab_bar)
	recipe_panel.move_child(tab_bar, 0)
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
