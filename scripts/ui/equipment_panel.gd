extends Control

signal close_requested

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const LOOT_DROP_SCENE = preload("res://scenes/dungeon/loot_drop.tscn")

@onready var slot_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotList
@onready var inventory_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryScroll/InventoryListContainer
@onready var stat_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatLabel
@onready var comparison_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ComparisonLabel
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var slot_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotTitle
@onready var inventory_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryTitle

var player: Variant = null
var _eq_indices: Array[int] = []
var _cons_indices: Array[int] = []
var _hovered_eq_index: int = -1
var _hovered_consumable_index: int = -1
var _context_menu: PopupMenu = null
var _context_inv_index: int = -1
var _context_inv_type: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	title_label.text = LocaleManager.L("equipment")
	slot_title.text = LocaleManager.L("wearing")
	inventory_title.text = LocaleManager.L("backpack_equipment")


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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_equipment"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child: Node in slot_list.get_children():
		child.queue_free()
	for child: Node in inventory_list_container.get_children():
		child.queue_free()
	_eq_indices.clear()
	_cons_indices.clear()
	_hovered_eq_index = -1
	_hovered_consumable_index = -1

	if player == null:
		return

	for slot_name in player.equipment_system.get_slot_order():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		var slot_button: Button = _build_slot_row(slot_name, item)
		slot_list.add_child(slot_button)

	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		var eq_index: int = _eq_indices.size()
		_eq_indices.append(index)
		inventory_list_container.add_child(_build_eq_row(stack, eq_index))

	var q_id: String = str(player.get("consumable_q_id")) if player != null else ""
	var r_id: String = str(player.get("consumable_r_id")) if player != null else ""
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "consumable":
			continue
		var cons_index: int = _cons_indices.size()
		_cons_indices.append(index)
		inventory_list_container.add_child(_build_cons_row(stack, cons_index, q_id, r_id))

	var has_materials: bool = false
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		var item_type: String = str(stack.get("type", ""))
		var item_id: String = str(stack.get("id", ""))
		if item_type != "resource":
			continue
		if item_id == "copper" or item_id == "silver" or item_id == "gold":
			continue
		if not has_materials:
			has_materials = true
			inventory_list_container.add_child(HSeparator.new())
			var mat_header: Label = Label.new()
			mat_header.text = LocaleManager.L("materials_section")
			mat_header.modulate = Color(0.85, 0.75, 0.45, 1.0)
			mat_header.add_theme_font_size_override("font_size", 12)
			inventory_list_container.add_child(mat_header)
		inventory_list_container.add_child(_build_material_row(stack))

	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		LocaleManager.L("atk"), int(summary.get("attack", 0)),
		LocaleManager.L("def"), int(summary.get("defense", 0)),
		LocaleManager.L("hp"), int(summary.get("max_hp", 0)),
		LocaleManager.L("spd"), int(summary.get("speed", 0)),
	]
	comparison_label.text = LocaleManager.L("hover_to_compare")


func _build_slot_row(slot_name: String, item: Dictionary) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 56)

	if not item.is_empty():
		_apply_rarity_style(button, _get_rarity_border_color(item))

	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon_source: Dictionary = item if not item.is_empty() else {}
	var slot_icon: Texture2D = ITEM_DATABASE.get_stack_icon(icon_source)
	if slot_icon == null:
		slot_icon = ITEM_DATABASE.get_default_equipment_icon(slot_name)
	content.add_child(_make_icon_ctrl(slot_icon, ITEM_DATABASE.get_stack_color(icon_source), 32))

	var info_column: VBoxContainer = VBoxContainer.new()
	info_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 2)

	var name_label: Label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	if item.is_empty():
		name_label.text = "[%s] %s" % [_translate_slot(slot_name), LocaleManager.L("empty")]
		name_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		name_label.text = "[%s] %s" % [_translate_slot(slot_name), _get_item_display_name(item)]
		name_label.self_modulate = player.equipment_system.get_item_display_color(item)
	info_column.add_child(name_label)

	if not item.is_empty():
		var durability: int = int(item.get("durability", 0))
		var max_durability: int = int(item.get("max_durability", 0))
		var durability_label: Label = Label.new()
		durability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		durability_label.text = LocaleManager.L("slot_durability") % [durability, max_durability]
		durability_label.add_theme_font_size_override("font_size", 10)
		durability_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
		info_column.add_child(durability_label)

	content.add_child(info_column)
	button.add_child(content)
	button.pressed.connect(_on_slot_pressed.bind(slot_name))
	return button


func _build_eq_row(stack: Dictionary, eq_idx: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 64)

	var rarity_color: Color = _get_rarity_border_color(stack)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.14, 0.96)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var row_one: HBoxContainer = HBoxContainer.new()
	row_one.add_theme_constant_override("separation", 6)
	row_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_texture: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	row_one.add_child(_make_icon_ctrl(icon_texture, ITEM_DATABASE.get_stack_color(stack), 22))
	var text_color: Color = ITEM_DATABASE.get_stack_color(stack)
	var name_label: Label = Label.new()
	name_label.text = _get_item_display_name(stack)
	name_label.self_modulate = text_color
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row_one.add_child(name_label)
	content.add_child(row_one)

	var row_two: HBoxContainer = HBoxContainer.new()
	row_two.add_theme_constant_override("separation", 8)
	row_two.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rarity_label: Label = Label.new()
	rarity_label.text = _translate_rarity(str(stack.get("rarity", "Common")))
	rarity_label.self_modulate = rarity_color
	rarity_label.add_theme_font_size_override("font_size", 10)
	row_two.add_child(rarity_label)

	var slot_label: Label = Label.new()
	slot_label.text = _translate_slot(str(stack.get("slot", "")))
	slot_label.add_theme_font_size_override("font_size", 10)
	slot_label.modulate = Color(0.72, 0.72, 0.76, 1.0)
	row_two.add_child(slot_label)

	var durability: int = int(stack.get("durability", 0))
	var max_durability: int = int(stack.get("max_durability", 0))
	var durability_label: Label = Label.new()
	durability_label.text = LocaleManager.L("slot_durability") % [durability, max_durability]
	durability_label.add_theme_font_size_override("font_size", 10)
	durability_label.modulate = Color(0.72, 0.72, 0.76, 1.0)
	durability_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	durability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row_two.add_child(durability_label)
	content.add_child(row_two)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_eq_inv_pressed(eq_idx)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var resolved_index: int = _eq_indices[eq_idx] if eq_idx < _eq_indices.size() else -1
				if resolved_index < 0:
					return
				_context_inv_index = resolved_index
				_context_inv_type = "equipment"
				_context_menu.clear()
				_context_menu.add_item(LocaleManager.L("ctx_discard"), 0)
				_context_menu.position = Vector2i(get_global_mouse_position())
				_context_menu.reset_size()
				_context_menu.popup()
	)
	panel.mouse_entered.connect(func() -> void:
		_hovered_eq_index = eq_idx
		_hovered_consumable_index = -1
		_update_comparison_label()
	)
	panel.mouse_exited.connect(func() -> void:
		_hovered_eq_index = -1
		_update_comparison_label()
	)
	_apply_panel_rarity_style(panel, rarity_color)
	return panel


func _build_cons_row(stack: Dictionary, cons_idx: int, q_id: String, r_id: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 40)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.10, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.30, 0.75, 0.35, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var icon_texture: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	row.add_child(_make_icon_ctrl(icon_texture, ITEM_DATABASE.get_stack_color(stack), 20))

	var item_id: String = str(stack.get("id", ""))
	var label_text: String = ITEM_DATABASE.get_stack_display_name(stack)
	var quantity: int = int(stack.get("quantity", 0))
	var tag: String = ""
	if item_id == q_id:
		tag = " [Q]"
	elif item_id == r_id:
		tag = " [R]"

	var label: Label = Label.new()
	label.text = "%s x%d%s" % [label_text, quantity, tag]
	label.self_modulate = Color(0.32, 0.78, 0.42, 1.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			var resolved_index: int = _cons_indices[cons_idx] if cons_idx < _cons_indices.size() else -1
			if resolved_index < 0:
				return
			_context_inv_index = resolved_index
			_context_inv_type = "consumable"
			_context_menu.clear()
			_context_menu.add_item(LocaleManager.L("ctx_set_q"), 1)
			_context_menu.add_item(LocaleManager.L("ctx_set_r"), 2)
			_context_menu.position = Vector2i(get_global_mouse_position())
			_context_menu.reset_size()
			_context_menu.popup()
	)
	panel.mouse_entered.connect(func() -> void:
		_hovered_consumable_index = cons_idx
		_hovered_eq_index = -1
		_update_comparison_label()
	)
	panel.mouse_exited.connect(func() -> void:
		_hovered_consumable_index = -1
		_update_comparison_label()
	)
	return panel


func _build_material_row(stack: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_texture: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	row.add_child(_make_icon_ctrl(icon_texture, ITEM_DATABASE.get_stack_color(stack), 20))
	var label: Label = Label.new()
	var label_text: String = ITEM_DATABASE.get_stack_display_name(stack)
	var quantity: int = int(stack.get("quantity", 0))
	label.text = "%s x%d" % [label_text, quantity]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	return row


func _make_icon_ctrl(icon: Texture2D, fallback_color: Color, size: int) -> Control:
	if icon != null:
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.custom_minimum_size = Vector2(size, size)
		texture_rect.size = Vector2(size, size)
		texture_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.texture = icon
		return texture_rect
	var swatch: ColorRect = ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(size, size)
	swatch.color = fallback_color
	return swatch


func _apply_rarity_style(node: Control, base_color: Color) -> void:
	for child: Node in node.get_children():
		if child.name == "RarityBorder":
			child.queue_free()
	var border_drawer: Control = Control.new()
	border_drawer.name = "RarityBorder"
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.draw.connect(func() -> void:
		var rect: Rect2 = border_drawer.get_rect().grow(-2.0)
		border_drawer.draw_rect(rect.grow(2), base_color.darkened(0.4), false, 2.0)
		border_drawer.draw_rect(rect, base_color, false, 2.0)
		border_drawer.draw_rect(rect.grow(-2), base_color.lightened(0.4), false, 1.0)
	)
	border_drawer.resized.connect(border_drawer.queue_redraw)
	node.add_child(border_drawer)
	var background_style: StyleBoxFlat = StyleBoxFlat.new()
	background_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	node.add_theme_stylebox_override("normal", background_style)
	node.add_theme_stylebox_override("hover", background_style.duplicate())
	node.add_theme_stylebox_override("pressed", background_style.duplicate())
	node.add_theme_stylebox_override("focus", background_style.duplicate())


func _apply_panel_rarity_style(panel: PanelContainer, base_color: Color) -> void:
	for child: Node in panel.get_children():
		if child.name == "RarityBorder":
			child.queue_free()
	var border_drawer: Control = Control.new()
	border_drawer.name = "RarityBorder"
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.draw.connect(func() -> void:
		var rect: Rect2 = border_drawer.get_rect().grow(-2.0)
		border_drawer.draw_rect(rect.grow(2), base_color.darkened(0.4), false, 2.0)
		border_drawer.draw_rect(rect, base_color, false, 2.0)
		border_drawer.draw_rect(rect.grow(-2), base_color.lightened(0.4), false, 1.0)
	)
	border_drawer.resized.connect(border_drawer.queue_redraw)
	panel.add_child(border_drawer)


func _get_rarity_border_color(item: Dictionary) -> Color:
	if item.is_empty():
		return ITEM_DATABASE.get_equipment_rarity_color("Common")
	return ITEM_DATABASE.get_equipment_rarity_color(str(item.get("rarity", "Common")))


func _get_item_display_name(item_data: Dictionary) -> String:
	if item_data.is_empty():
		return ""
	var base_name: String = str(item_data.get("name", ITEM_DATABASE.get_stack_display_name(item_data)))
	if player != null:
		var slot_name: String = str(item_data.get("slot", ""))
		var equipped_item: Dictionary = player.equipment_system.get_equipped(slot_name)
		if player.equipment_system.is_broken(slot_name) and equipped_item.get("id", "") == item_data.get("id", ""):
			return LocaleManager.L("broken_item_fmt") % base_name
	var durability: int = int(item_data.get("durability", 0))
	var max_durability: int = int(item_data.get("max_durability", 0))
	if max_durability > 0 and durability <= 0:
		return LocaleManager.L("broken_item_fmt") % base_name
	return base_name


func _translate_slot(slot_name: String) -> String:
	match slot_name:
		"weapon":
			return LocaleManager.L("weapon")
		"helmet":
			return LocaleManager.L("helmet")
		"chest_armor":
			return LocaleManager.L("chest_armor")
		"boots":
			return LocaleManager.L("boots")
		"accessory":
			return LocaleManager.L("accessory")
		"offhand":
			return LocaleManager.L("offhand")
		"tool":
			return LocaleManager.L("tool")
	return slot_name.replace("_", " ").capitalize()


func _translate_rarity(rarity: String) -> String:
	var normalized: String = rarity.strip_edges()
	if normalized == "":
		normalized = "Common"
	var normalized_lower: String = normalized.to_lower()
	match normalized_lower:
		"common":
			return "Common"
		"uncommon":
			return "Uncommon"
		"rare":
			return "Rare"
		"epic":
			return "Epic"
		"legendary":
			return "Legendary"
	return normalized.capitalize()


func _on_slot_pressed(slot_name: String) -> void:
	if player == null:
		return
	player.equipment_system.unequip(slot_name, player.inventory)
	_refresh()


func _on_eq_inv_pressed(eq_idx: int) -> void:
	if player == null or eq_idx < 0 or eq_idx >= _eq_indices.size():
		return
	player.equipment_system.equip_from_inventory(player.inventory, _eq_indices[eq_idx])
	_refresh()


func _on_context_id_pressed(id: int) -> void:
	match id:
		0:
			if _context_inv_type == "equipment":
				_discard_item(_context_inv_index)
		1:
			if _context_inv_type == "consumable":
				_set_quickslot(_context_inv_index, 0)
		2:
			if _context_inv_type == "consumable":
				_set_quickslot(_context_inv_index, 1)


func _discard_item(inv_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var stack: Dictionary = player.inventory.items[inv_index].duplicate(true)
	if not player.inventory.remove_item(str(stack.get("id", "")), 1):
		return
	var drop: Variant = LOOT_DROP_SCENE.instantiate()
	drop.global_position = player.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	drop.setup_discard(stack)
	player.get_parent().add_child(drop)
	_refresh()


func _set_quickslot(inv_index: int, slot_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var item_id: String = str(player.inventory.items[inv_index].get("id", ""))
	if player.has_method("set_consumable_slot"):
		player.set_consumable_slot(slot_index, item_id)
	_refresh()


func _update_comparison_label() -> void:
	if comparison_label == null or player == null:
		return
	if _hovered_eq_index >= 0 and _hovered_eq_index < _eq_indices.size():
		var stack_index: int = _eq_indices[_hovered_eq_index]
		if stack_index < 0 or stack_index >= player.inventory.items.size():
			comparison_label.text = LocaleManager.L("hover_to_compare")
			return
		var item: Dictionary = player.inventory.items[stack_index]
		var current_summary: Dictionary = player.get_stats_summary()
		var preview_summary: Dictionary = player.get_stats_summary_for_item(item)
		var lines: PackedStringArray = player.equipment_system.get_comparison_lines(current_summary, preview_summary)
		var localized_lines: Array[String] = []
		for line in lines:
			var translated: String = line.replace("ATK", LocaleManager.L("atk")).replace("DEF", LocaleManager.L("def")).replace("HP", LocaleManager.L("hp")).replace("SPD", LocaleManager.L("spd"))
			localized_lines.append(translated)
		comparison_label.text = "\n".join(localized_lines)
		return
	if _hovered_consumable_index >= 0 and _hovered_consumable_index < _cons_indices.size():
		comparison_label.text = LocaleManager.L("consumable_quickslot_hint")
		return
	comparison_label.text = LocaleManager.L("hover_to_compare")
