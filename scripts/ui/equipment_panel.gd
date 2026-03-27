extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")

@onready var slot_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotList
@onready var inventory_list: ItemList = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryList
@onready var stat_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatLabel
@onready var comparison_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ComparisonLabel
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var slot_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotTitle
@onready var inventory_title: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryTitle

var player = null

# Right-panel scroll+vbox (replaces ItemList)
var _inv_scroll: ScrollContainer = null
var _inv_vbox: VBoxContainer = null

# Index tracking
var _eq_indices: Array[int] = []    # inventory indices of equipment items
var _cons_indices: Array[int] = []  # inventory indices of consumable items
var _hovered_eq_index: int = -1

# Context menu
var _context_menu: PopupMenu = null
var _context_inv_index: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Hide the ItemList — replaced by _inv_vbox below
	inventory_list.visible = false

	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id_pressed)

	# Build right-panel scroll container
	var inv_panel_vbox: VBoxContainer = inventory_list.get_parent()
	_inv_scroll = ScrollContainer.new()
	_inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_vbox = VBoxContainer.new()
	_inv_vbox.add_theme_constant_override("separation", 4)
	_inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_scroll.add_child(_inv_vbox)
	inv_panel_vbox.add_child(_inv_scroll)

	title_label.text = LocaleManager.L("equipment")
	slot_title.text = LocaleManager.L("wearing")
	inventory_title.text = LocaleManager.L("backpack_equipment")

	set_process(true)


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
	# --- Clear left panel (wearing) ---
	for child in slot_list.get_children():
		child.queue_free()

	# --- Clear right panel (inventory) ---
	for child in _inv_vbox.get_children():
		child.queue_free()
	_eq_indices.clear()
	_cons_indices.clear()
	_hovered_eq_index = -1

	if player == null:
		return

	# --- Left panel: equipped slots (2-row per slot) ---
	for slot_name in player.equipment_system.get_slot_order():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		var btn := _build_slot_row(slot_name, item)
		slot_list.add_child(btn)

	# --- Right panel: equipment items (2-row PanelContainer) ---
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		var eq_idx := _eq_indices.size()
		_eq_indices.append(index)
		_inv_vbox.add_child(_build_eq_row(stack, eq_idx))

	# --- Right panel: consumable items (1-row PanelContainer) ---
	var q_id: String = str(player.get("consumable_q_id")) if player != null else ""
	var r_id: String = str(player.get("consumable_r_id")) if player != null else ""
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "consumable":
			continue
		var cons_idx := _cons_indices.size()
		_cons_indices.append(index)
		_inv_vbox.add_child(_build_cons_row(stack, cons_idx, q_id, r_id))

	# --- Stats ---
	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		LocaleManager.L("atk"), int(summary.get("attack", 0)),
		LocaleManager.L("def"), int(summary.get("defense", 0)),
		LocaleManager.L("hp"), int(summary.get("max_hp", 0)),
		LocaleManager.L("spd"), int(summary.get("speed", 0)),
	]
	comparison_label.text = LocaleManager.L("hover_to_compare")


# ---- Left panel: equipped slot row ----

func _build_slot_row(slot_name: String, item: Dictionary) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)

	if not item.is_empty():
		_apply_rarity_style(btn, player.equipment_system.get_item_display_color(item))

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Icon
	var icon_src: Dictionary = item if not item.is_empty() else {}
	var slot_icon: Texture2D = ITEM_DATABASE.get_stack_icon(icon_src)
	if slot_icon == null:
		slot_icon = ITEM_DATABASE.get_default_equipment_icon(str(slot_name))
	var icon_ctrl := _make_icon_ctrl(slot_icon, ITEM_DATABASE.get_stack_color(icon_src), 32)
	content.add_child(icon_ctrl)

	# Text column
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var lbl1 := Label.new()
	lbl1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl1.clip_text = true
	if item.is_empty():
		lbl1.text = "[%s] %s" % [_translate_slot(slot_name), LocaleManager.L("empty")]
		lbl1.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		lbl1.text = "[%s] %s" % [_translate_slot(slot_name), _get_item_display_name(item)]
		lbl1.self_modulate = player.equipment_system.get_item_display_color(item)
	info.add_child(lbl1)

	if not item.is_empty():
		var dur := int(item.get("durability", 0))
		var max_dur := int(item.get("max_durability", 0))
		var lbl2 := Label.new()
		lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl2.text = LocaleManager.L("slot_durability") % [dur, max_dur]
		lbl2.add_theme_font_size_override("font_size", 10)
		lbl2.modulate = Color(0.7, 0.7, 0.7, 1.0)
		info.add_child(lbl2)

	content.add_child(info)
	btn.add_child(content)
	btn.pressed.connect(_on_slot_pressed.bind(String(slot_name)))
	return btn


# ---- Right panel: equipment inventory row ----

func _build_eq_row(stack: Dictionary, eq_idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 64)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	var rarity_color: Color = player.equipment_system.get_item_display_color(stack)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 48×48 icon
	var icon_tex: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	hbox.add_child(_make_icon_ctrl(icon_tex, ITEM_DATABASE.get_stack_color(stack), 48))

	# Text column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var lbl_name := Label.new()
	lbl_name.text = _get_item_display_name(stack)
	lbl_name.self_modulate = rarity_color
	lbl_name.clip_text = true
	info.add_child(lbl_name)

	var slot_name := str(stack.get("slot", ""))
	var dur := int(stack.get("durability", 0))
	var max_dur := int(stack.get("max_durability", 0))
	var rarity := str(stack.get("rarity", ""))
	var rarity_tag := _translate_rarity(rarity)
	var line2 := ""
	if rarity_tag != "":
		line2 = "[%s] %s  %d/%d" % [rarity_tag, _translate_slot(slot_name), dur, max_dur]
	else:
		line2 = "%s  %d/%d" % [_translate_slot(slot_name), dur, max_dur]
	var lbl_info := Label.new()
	lbl_info.text = line2
	lbl_info.add_theme_font_size_override("font_size", 10)
	lbl_info.modulate = Color(0.7, 0.7, 0.7, 1.0)
	lbl_info.clip_text = true
	info.add_child(lbl_info)

	hbox.add_child(info)
	panel.add_child(hbox)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_eq_inv_pressed(eq_idx)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_context_inv_index = _eq_indices[eq_idx] if eq_idx < _eq_indices.size() else -1
				if _context_inv_index < 0:
					return
				_context_menu.clear()
				_context_menu.add_item(LocaleManager.L("ctx_discard"), 0)
				_context_menu.position = Vector2i(get_global_mouse_position())
				_context_menu.reset_size()
				_context_menu.popup()
	)
	panel.mouse_entered.connect(func():
		_hovered_eq_index = eq_idx
		_update_comparison_label()
	)
	panel.mouse_exited.connect(func():
		_hovered_eq_index = -1
		_update_comparison_label()
	)
	return panel


# ---- Right panel: consumable inventory row ----

func _build_cons_row(stack: Dictionary, cons_idx: int, q_id: String, r_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 40)

	var style := StyleBoxFlat.new()
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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_tex: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	hbox.add_child(_make_icon_ctrl(icon_tex, ITEM_DATABASE.get_stack_color(stack), 32))

	var id := str(stack.get("id", ""))
	var label := ITEM_DATABASE.get_stack_display_name(stack)
	var qty := int(stack.get("quantity", 0))
	var tag := ""
	if id == q_id:
		tag = " [Q]"
	elif id == r_id:
		tag = " [R]"

	var lbl := Label.new()
	lbl.text = "%s x%d%s" % [label, qty, tag]
	lbl.self_modulate = Color(0.32, 0.78, 0.42, 1.0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)
	panel.add_child(hbox)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_context_inv_index = _cons_indices[cons_idx] if cons_idx < _cons_indices.size() else -1
			if _context_inv_index < 0:
				return
			_context_menu.clear()
			_context_menu.add_item(LocaleManager.L("ctx_set_q"), 1)
			_context_menu.add_item(LocaleManager.L("ctx_set_r"), 2)
			_context_menu.position = Vector2i(get_global_mouse_position())
			_context_menu.reset_size()
			_context_menu.popup()
	)
	return panel


# ---- Helpers ----

func _make_icon_ctrl(icon: Texture2D, fallback_color: Color, size: int) -> Control:
	if icon != null:
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.custom_minimum_size = Vector2(size, size)
		tr.size = Vector2(size, size)
		tr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture = icon
		return tr
	var cr := ColorRect.new()
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.custom_minimum_size = Vector2(size, size)
	cr.color = fallback_color
	return cr


func _apply_rarity_style(node: Control, base_color: Color) -> void:
	for child in node.get_children():
		if child.name == "RarityBorder":
			child.queue_free()
	var border_drawer := Control.new()
	border_drawer.name = "RarityBorder"
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.draw.connect(func():
		var r := border_drawer.get_rect()
		border_drawer.draw_rect(r.grow(2), base_color.darkened(0.4), false, 2.0)
		border_drawer.draw_rect(r, base_color, false, 2.0)
		border_drawer.draw_rect(r.grow(-2), base_color.lightened(0.4), false, 1.0)
	)
	node.add_child(border_drawer)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	node.add_theme_stylebox_override("normal", bg_style)
	node.add_theme_stylebox_override("hover", bg_style.duplicate())
	node.add_theme_stylebox_override("pressed", bg_style.duplicate())


func _get_item_display_name(item_data: Dictionary) -> String:
	if item_data.is_empty():
		return ""
	var base_name := str(item_data.get("name", item_data.get("id", "")))
	if player != null and player.equipment_system.is_broken(str(item_data.get("slot", ""))) and player.equipment_system.get_equipped(str(item_data.get("slot", ""))).get("id", "") == item_data.get("id", ""):
		return LocaleManager.L("broken_item_fmt") % base_name
	var durability := int(item_data.get("durability", 0))
	var max_durability := int(item_data.get("max_durability", 0))
	if max_durability > 0 and durability <= 0:
		return LocaleManager.L("broken_item_fmt") % base_name
	return base_name


func _translate_slot(slot_name: String) -> String:
	match slot_name:
		"weapon": return LocaleManager.L("weapon")
		"helmet": return LocaleManager.L("helmet")
		"chest_armor": return LocaleManager.L("chest_armor")
		"boots": return LocaleManager.L("boots")
		"accessory": return LocaleManager.L("accessory")
		"offhand": return LocaleManager.L("offhand")
		"tool": return LocaleManager.L("tool")
	return slot_name.replace("_", " ").capitalize()


func _translate_rarity(rarity: String) -> String:
	match rarity:
		"common": return LocaleManager.L("rarity_common")
		"uncommon": return LocaleManager.L("rarity_uncommon")
		"rare": return LocaleManager.L("rarity_rare")
		"epic": return LocaleManager.L("rarity_epic")
		"legendary": return LocaleManager.L("rarity_legendary")
	return ""


# ---- Event handlers ----

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
		0: _discard_item(_context_inv_index)
		1: _set_quickslot(_context_inv_index, 0)
		2: _set_quickslot(_context_inv_index, 1)


func _discard_item(inv_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var stack: Dictionary = player.inventory.items[inv_index].duplicate(true)
	if not player.inventory.remove_item(str(stack.get("id", "")), 1):
		return
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.global_position = player.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	drop.setup_discard(stack)
	player.get_parent().add_child(drop)
	_refresh()


func _set_quickslot(inv_index: int, slot_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var item_id := str(player.inventory.items[inv_index].get("id", ""))
	if player.has_method("set_consumable_slot"):
		player.set_consumable_slot(slot_index, item_id)
	_refresh()


# ---- Comparison hover ----

func _process(_delta: float) -> void:
	pass


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
		var lines = player.equipment_system.get_comparison_lines(current_summary, preview_summary)
		var localized_lines: Array[String] = []
		for line in lines:
			var translated = line.replace("ATK", LocaleManager.L("atk")).replace("DEF", LocaleManager.L("def")).replace("HP", LocaleManager.L("hp")).replace("SPD", LocaleManager.L("spd"))
			localized_lines.append(translated)
		comparison_label.text = "\n".join(localized_lines)
		return
	comparison_label.text = LocaleManager.L("hover_to_compare")
