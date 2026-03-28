extends Control

signal close_requested

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const LOOT_DROP_SCENE = preload("res://scenes/dungeon/loot_drop.tscn")

@onready var slot_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotList
@onready var eq_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/EqScroll/EqListContainer
@onready var mat_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/MatScroll/MatListContainer
@onready var eq_scroll: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/EqScroll
@onready var mat_scroll: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/MatScroll
@onready var eq_tab_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/TabBar/EqTabBtn
@onready var mat_tab_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/TabBar/MatTabBtn
@onready var stat_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatLabel
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var slot_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotTitle
@onready var inventory_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryTitle

var player: Variant = null
var _active_tab: String = "equipment"
var _eq_indices: Array[int] = []
var _cons_indices: Array[int] = []
var _hovered_eq_index: int = -1
var _hovered_consumable_index: int = -1
var _context_menu: PopupMenu = null
var _context_inv_index: int = -1
var _context_inv_type: String = ""
var _tooltip_panel: PanelContainer = null
var _tooltip_vbox: VBoxContainer = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	title_label.text = LocaleManager.L("equipment")
	title_label.add_theme_font_size_override("font_size", 22)
	slot_title.text = LocaleManager.L("wearing")
	inventory_title.text = LocaleManager.L("backpack_equipment")
	var ep_panel: PanelContainer = $PanelContainer
	var ep_style: StyleBoxFlat = StyleBoxFlat.new()
	ep_style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	ep_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	ep_style.border_width_left = 1
	ep_style.border_width_top = 1
	ep_style.border_width_right = 1
	ep_style.border_width_bottom = 1
	ep_panel.add_theme_stylebox_override("panel", ep_style)
	stat_label.add_theme_font_size_override("font_size", 16)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 10
	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.08, 0.08, 0.10, 0.93)
	tooltip_style.border_color = Color(0.35, 0.35, 0.42, 1.0)
	tooltip_style.border_width_left = 1
	tooltip_style.border_width_top = 1
	tooltip_style.border_width_right = 1
	tooltip_style.border_width_bottom = 1
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	_tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	var tooltip_margin: MarginContainer = MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 10)
	tooltip_margin.add_theme_constant_override("margin_top", 8)
	tooltip_margin.add_theme_constant_override("margin_right", 10)
	tooltip_margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(tooltip_margin)
	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.add_theme_constant_override("separation", 4)
	tooltip_margin.add_child(_tooltip_vbox)
	add_child(_tooltip_panel)

	eq_tab_btn.pressed.connect(func() -> void: _switch_tab("equipment"))
	mat_tab_btn.pressed.connect(func() -> void: _switch_tab("materials"))
	_apply_tab_styles()


func _switch_tab(tab: String) -> void:
	_active_tab = tab
	eq_scroll.visible = tab == "equipment"
	mat_scroll.visible = tab == "materials"
	_apply_tab_styles()


func _apply_tab_styles() -> void:
	eq_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if _active_tab == "equipment" else Color(0.55, 0.55, 0.55, 1.0)
	mat_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if _active_tab == "materials" else Color(0.55, 0.55, 0.55, 1.0)


func open_for_player(target_player) -> void:
	player = target_player
	visible = true
	_refresh()


func _process(_delta: float) -> void:
	if not visible or _tooltip_panel == null or not _tooltip_panel.visible:
		return
	var mouse_pos: Vector2 = get_local_mouse_position()
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = _tooltip_panel.size
	var tx: float = mouse_pos.x + 16.0
	var ty: float = mouse_pos.y + 16.0
	if tx + panel_size.x > viewport_size.x - 4.0:
		tx = mouse_pos.x - panel_size.x - 8.0
	if ty + panel_size.y > viewport_size.y - 4.0:
		ty = mouse_pos.y - panel_size.y - 8.0
	_tooltip_panel.position = Vector2(tx, ty)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	_hide_tooltip()
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_equipment"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_hide_tooltip()
	for child: Node in slot_list.get_children():
		child.queue_free()
	for child: Node in eq_list_container.get_children():
		child.queue_free()
	for child: Node in mat_list_container.get_children():
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
		eq_list_container.add_child(_build_eq_row(stack, eq_index))

	var q_id: String = str(player.get("consumable_q_id")) if player != null else ""
	var r_id: String = str(player.get("consumable_r_id")) if player != null else ""
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "consumable":
			continue
		var cons_index: int = _cons_indices.size()
		_cons_indices.append(index)
		eq_list_container.add_child(_build_cons_row(stack, cons_index, q_id, r_id))

	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		var item_type: String = str(stack.get("type", ""))
		var item_id: String = str(stack.get("id", ""))
		if item_type != "resource":
			continue
		if item_id == "copper" or item_id == "silver" or item_id == "gold":
			continue
		mat_list_container.add_child(_build_material_row(stack))

	eq_scroll.visible = _active_tab == "equipment"
	mat_scroll.visible = _active_tab == "materials"

	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		LocaleManager.L("atk"), int(summary.get("attack", 0)),
		LocaleManager.L("def"), int(summary.get("defense", 0)),
		LocaleManager.L("hp"), int(summary.get("max_hp", 0)),
		LocaleManager.L("spd"), int(summary.get("speed", 0)),
	]


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
		slot_icon = ITEM_DATABASE.get_equipment_icon(slot_name, "Common")
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
		_show_tooltip(stack)
	)
	panel.mouse_exited.connect(func() -> void:
		_hovered_eq_index = -1
		_hide_tooltip()
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
		_show_tooltip(stack)
	)
	panel.mouse_exited.connect(func() -> void:
		_hovered_consumable_index = -1
		_hide_tooltip()
	)
	return panel


func _build_material_row(stack: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 24)
	var icon_texture: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	row.add_child(_make_icon_ctrl(icon_texture, ITEM_DATABASE.get_stack_color(stack), 20))
	var label: Label = Label.new()
	var label_text: String = ITEM_DATABASE.get_stack_display_name(stack)
	var quantity: int = int(stack.get("quantity", 0))
	label.text = "%s x%d" % [label_text, quantity]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	row.mouse_entered.connect(func() -> void:
		_show_tooltip(stack)
	)
	row.mouse_exited.connect(func() -> void:
		_hide_tooltip()
	)
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


func _show_tooltip(stack: Dictionary) -> void:
	if _tooltip_panel == null or _tooltip_vbox == null or stack.is_empty():
		return
	for child: Node in _tooltip_vbox.get_children():
		child.free()
	var item_type: String = str(stack.get("type", ""))
	if item_type == "equipment":
		_fill_equipment_tooltip(_tooltip_vbox, stack)
	elif item_type == "consumable":
		_fill_consumable_tooltip(_tooltip_vbox, stack)
	elif item_type == "resource":
		_fill_material_tooltip(_tooltip_vbox, stack)
	else:
		var fallback_label: Label = Label.new()
		fallback_label.text = ITEM_DATABASE.get_stack_display_name(stack)
		_tooltip_vbox.add_child(fallback_label)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()


func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false


func _fill_equipment_tooltip(container: VBoxContainer, stack: Dictionary) -> void:
	var name_label: Label = Label.new()
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	name_label.self_modulate = ITEM_DATABASE.get_stack_color(stack)
	name_label.add_theme_font_size_override("font_size", 14)
	container.add_child(name_label)

	var rarity_slot_label: Label = Label.new()
	var rarity_str: String = _translate_rarity(str(stack.get("rarity", "Common")))
	var slot_str: String = _translate_slot(str(stack.get("slot", "")))
	rarity_slot_label.text = "%s  |  %s" % [rarity_str, slot_str]
	rarity_slot_label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	rarity_slot_label.add_theme_font_size_override("font_size", 11)
	container.add_child(rarity_slot_label)

	container.add_child(HSeparator.new())

	if player != null and player.has_method("get_stats_summary") and player.has_method("get_stats_summary_for_item"):
		var current_summary: Dictionary = player.get_stats_summary()
		var preview_summary: Dictionary = player.get_stats_summary_for_item(stack)
		var stat_display_names: Dictionary = {
			"attack": LocaleManager.L("atk"),
			"defense": LocaleManager.L("def"),
			"max_hp": LocaleManager.L("hp"),
			"speed": LocaleManager.L("spd"),
		}
		for stat_key in ["attack", "defense", "max_hp", "speed"]:
			var before_val: float = float(current_summary.get(stat_key, 0.0))
			var after_val: float = float(preview_summary.get(stat_key, 0.0))
			var delta: float = after_val - before_val
			var stat_row: HBoxContainer = HBoxContainer.new()
			stat_row.add_theme_constant_override("separation", 6)
			var stat_name_label: Label = Label.new()
			stat_name_label.text = str(stat_display_names.get(stat_key, stat_key)) + ":"
			stat_name_label.custom_minimum_size = Vector2(36, 0)
			stat_name_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
			stat_name_label.add_theme_font_size_override("font_size", 11)
			stat_row.add_child(stat_name_label)
			var val_label: Label = Label.new()
			val_label.text = "%d -> %d" % [int(round(before_val)), int(round(after_val))]
			val_label.add_theme_font_size_override("font_size", 11)
			stat_row.add_child(val_label)
			var delta_label: Label = Label.new()
			delta_label.text = "(%+d)" % int(round(delta))
			delta_label.add_theme_font_size_override("font_size", 11)
			if delta > 0.5:
				delta_label.self_modulate = Color(0.3, 0.9, 0.4, 1.0)
			elif delta < -0.5:
				delta_label.self_modulate = Color(0.9, 0.3, 0.3, 1.0)
			else:
				delta_label.self_modulate = Color(0.65, 0.65, 0.65, 1.0)
			stat_row.add_child(delta_label)
			container.add_child(stat_row)

	var durability: int = int(stack.get("durability", 0))
	var max_durability: int = int(stack.get("max_durability", 0))
	if max_durability > 0:
		var dur_label: Label = Label.new()
		dur_label.text = LocaleManager.L("slot_durability") % [durability, max_durability]
		dur_label.add_theme_font_size_override("font_size", 11)
		if durability <= 0:
			dur_label.self_modulate = Color(0.9, 0.3, 0.3, 1.0)
		else:
			dur_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
		container.add_child(dur_label)


func _fill_consumable_tooltip(container: VBoxContainer, stack: Dictionary) -> void:
	var name_label: Label = Label.new()
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	name_label.self_modulate = Color(0.32, 0.78, 0.42, 1.0)
	name_label.add_theme_font_size_override("font_size", 14)
	container.add_child(name_label)

	var quantity: int = int(stack.get("quantity", 1))
	var qty_label: Label = Label.new()
	qty_label.text = "x%d" % quantity
	qty_label.add_theme_font_size_override("font_size", 11)
	qty_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	container.add_child(qty_label)

	var effect: String = str(stack.get("effect", stack.get("description", "")))
	if effect != "":
		container.add_child(HSeparator.new())
		var effect_label: Label = Label.new()
		effect_label.text = effect
		effect_label.add_theme_font_size_override("font_size", 11)
		effect_label.modulate = Color(0.8, 0.85, 0.8, 1.0)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.custom_minimum_size = Vector2(180, 0)
		container.add_child(effect_label)


func _fill_material_tooltip(container: VBoxContainer, stack: Dictionary) -> void:
	var name_label: Label = Label.new()
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.modulate = Color(0.85, 0.75, 0.45, 1.0)
	container.add_child(name_label)

	var quantity: int = int(stack.get("quantity", 1))
	var qty_label: Label = Label.new()
	qty_label.text = "x%d" % quantity
	qty_label.add_theme_font_size_override("font_size", 11)
	qty_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	container.add_child(qty_label)

	var description: String = str(stack.get("description", ""))
	if description != "":
		container.add_child(HSeparator.new())
		var desc_label: Label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(180, 0)
		container.add_child(desc_label)
