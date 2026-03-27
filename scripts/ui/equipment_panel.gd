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
# Equipment rows (VBoxContainer-based 2-row layout)
var _inv_scroll: ScrollContainer = null
var _inv_vbox: VBoxContainer = null
var _eq_indices: Array[int] = []
var _hovered_eq_index: int = -1
# Consumable entries in ItemList
var _inventory_indices: Array[int] = []
var _hovered_inventory_index: int = -1
var _context_menu: PopupMenu = null
var _context_inv_index: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_list.item_selected.connect(_on_inventory_selected)
	inventory_list.item_clicked.connect(_on_inventory_item_clicked)
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id_pressed)

	# Build equipment VBoxContainer (2-row layout) before InventoryList
	var panel_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer
	_inv_scroll = ScrollContainer.new()
	_inv_scroll.custom_minimum_size = Vector2(200, 180)
	_inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_vbox = VBoxContainer.new()
	_inv_vbox.add_theme_constant_override("separation", 4)
	_inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_scroll.add_child(_inv_vbox)
	panel_vbox.add_child(_inv_scroll)
	panel_vbox.move_child(_inv_scroll, 1)  # After InventoryTitle

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
	# --- Equipped slots ---
	for child in slot_list.get_children():
		child.queue_free()

	# --- Equipment inventory (2-row VBoxContainer) ---
	for child in _inv_vbox.get_children():
		child.queue_free()
	_eq_indices.clear()
	_hovered_eq_index = -1

	# --- Consumables (ItemList) ---
	inventory_list.clear()
	inventory_list.fixed_icon_size = Vector2i(32, 32)
	_inventory_indices.clear()
	_hovered_inventory_index = -1

	if player == null:
		return

	# Build equipped slot buttons
	for slot_name in player.equipment_system.get_slot_order():
		var button := Button.new()
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		button.text = _build_slot_text(slot_name, item)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		var slot_icon: Texture2D = ITEM_DATABASE.get_stack_icon(item)
		if slot_icon == null:
			slot_icon = ITEM_DATABASE.get_default_equipment_icon(str(slot_name))
		button.icon = slot_icon
		if not item.is_empty():
			var color = player.equipment_system.get_item_display_color(item)
			_apply_rarity_style(button, color)
		button.pressed.connect(_on_slot_pressed.bind(String(slot_name)))
		slot_list.add_child(button)

	# Build equipment inventory rows (2-row layout)
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		var eq_list_index := _eq_indices.size()
		_eq_indices.append(index)
		_inv_vbox.add_child(_build_equipment_row(stack, eq_list_index))

	# Build consumable entries in ItemList
	var q_id: String = str(player.get("consumable_q_id")) if player != null else ""
	var r_id: String = str(player.get("consumable_r_id")) if player != null else ""
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "consumable":
			continue
		var id := str(stack.get("id", ""))
		var label := ITEM_DATABASE.get_stack_display_name(stack)
		var qty := int(stack.get("quantity", 0))
		var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
		var tag := ""
		if id == q_id:
			tag = " [Q]"
		elif id == r_id:
			tag = " [R]"
		inventory_list.add_item("%s x%d%s  %s" % [label, qty, tag, LocaleManager.L("hint_right_click_quickslot")], icon)
		inventory_list.set_item_custom_fg_color(inventory_list.get_item_count() - 1, Color(0.32, 0.78, 0.42, 1.0))
		_inventory_indices.append(index)

	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		LocaleManager.L("atk"), int(summary.get("attack", 0)),
		LocaleManager.L("def"), int(summary.get("defense", 0)),
		LocaleManager.L("hp"), int(summary.get("max_hp", 0)),
		LocaleManager.L("spd"), int(summary.get("speed", 0)),
	]
	comparison_label.text = LocaleManager.L("hover_to_compare")


func _build_equipment_row(stack: Dictionary, eq_list_index: int) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	if not stack.is_empty():
		_apply_rarity_style(btn, player.equipment_system.get_item_display_color(stack))

	# Row content as VBoxContainer inside button
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Row 1: 48×48 icon + item name (color-coded)
	var row1 := HBoxContainer.new()
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", 6)
	var icon_ctrl := _build_icon_control(stack, 48)
	row1.add_child(icon_ctrl)
	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = _get_item_display_name(stack)
	name_lbl.self_modulate = player.equipment_system.get_item_display_color(stack)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row1.add_child(name_lbl)
	content.add_child(row1)

	# Row 2: quality tag + slot type + durability (smaller gray text)
	var slot_name := str(stack.get("slot", ""))
	var dur := int(stack.get("durability", 0))
	var max_dur := int(stack.get("max_durability", 0))
	var rarity := str(stack.get("rarity", ""))
	var rarity_tag := _translate_rarity(rarity)
	var row2_text := ""
	if rarity_tag != "":
		row2_text = "[%s] %s  %d/%d" % [rarity_tag, _translate_slot(slot_name), dur, max_dur]
	else:
		row2_text = "%s  %d/%d" % [_translate_slot(slot_name), dur, max_dur]
	var info_lbl := Label.new()
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_lbl.text = row2_text
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.modulate = Color(0.7, 0.7, 0.7, 1.0)
	content.add_child(info_lbl)

	btn.add_child(content)

	btn.pressed.connect(_on_eq_inv_pressed.bind(eq_list_index))
	btn.mouse_entered.connect(func():
		_hovered_eq_index = eq_list_index
		_update_comparison_label()
	)
	btn.mouse_exited.connect(func():
		_hovered_eq_index = -1
		_update_comparison_label()
	)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_context_inv_index = _eq_indices[eq_list_index] if eq_list_index < _eq_indices.size() else -1
			if _context_inv_index < 0:
				return
			_context_menu.clear()
			_context_menu.add_item(LocaleManager.L("ctx_discard"), 0)
			_context_menu.position = Vector2i(get_global_mouse_position())
			_context_menu.reset_size()
			_context_menu.popup()
	)
	return btn


func _build_icon_control(stack: Dictionary, size: int) -> Control:
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.custom_minimum_size = Vector2(size, size)
		icon_rect.size = Vector2(size, size)
		icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.texture = icon
		return icon_rect
	var swatch := ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(size, size)
	swatch.color = ITEM_DATABASE.get_stack_color(stack)
	return swatch


func _apply_rarity_style(node: Control, base_color: Color) -> void:
	# Clean up previous border decorations
	for child in node.get_children():
		if child.name == "RarityBorder":
			child.queue_free()

	var border_drawer := Control.new()
	border_drawer.name = "RarityBorder"
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.draw.connect(func():
		var r := border_drawer.get_rect()
		# Triple-layer border: Outer(2px darkened), Middle(2px original), Inner(1px lightened)
		border_drawer.draw_rect(r.grow(2), base_color.darkened(0.4), false, 2.0)
		border_drawer.draw_rect(r, base_color, false, 2.0)
		border_drawer.draw_rect(r.grow(-2), base_color.lightened(0.4), false, 1.0)
	)
	node.add_child(border_drawer)

	# Apply a dark background via StyleBox
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	node.add_theme_stylebox_override("normal", bg_style)
	node.add_theme_stylebox_override("hover", bg_style.duplicate())
	node.add_theme_stylebox_override("pressed", bg_style.duplicate())


func _build_slot_text(slot_name: String, item: Dictionary) -> String:
	var label := "[%s] " % _translate_slot(slot_name)
	if item.is_empty():
		return label + LocaleManager.L("empty")
	var durability := int(item.get("durability", 0))
	var max_durability := int(item.get("max_durability", 0))
	return "%s%s  %s" % [label, _get_item_display_name(item), LocaleManager.L("slot_durability") % [durability, max_durability]]


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


func _translate_rarity(rarity: String) -> String:
	match rarity:
		"common": return LocaleManager.L("rarity_common")
		"uncommon": return LocaleManager.L("rarity_uncommon")
		"rare": return LocaleManager.L("rarity_rare")
		"epic": return LocaleManager.L("rarity_epic")
		"legendary": return LocaleManager.L("rarity_legendary")
	return ""


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


func _on_inventory_selected(index: int) -> void:
	# ItemList now contains only consumables; selecting does nothing
	pass


func _on_inventory_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	if index < 0 or index >= _inventory_indices.size():
		return
	_context_inv_index = _inventory_indices[index]
	_context_menu.clear()
	_context_menu.add_item(LocaleManager.L("ctx_set_q"), 1)
	_context_menu.add_item(LocaleManager.L("ctx_set_r"), 2)
	if _context_menu.item_count > 0:
		_context_menu.position = Vector2i(get_global_mouse_position())
		_context_menu.reset_size()
		_context_menu.popup()


func _on_context_id_pressed(id: int) -> void:
	match id:
		0: _discard_item(_context_inv_index)
		1: _set_quickslot(_context_inv_index, 0)
		2: _set_quickslot(_context_inv_index, 1)


func _on_eq_inv_pressed(eq_list_index: int) -> void:
	if player == null or eq_list_index < 0 or eq_list_index >= _eq_indices.size():
		return
	player.equipment_system.equip_from_inventory(player.inventory, _eq_indices[eq_list_index])
	_refresh()


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


func _on_slot_pressed(slot_name: String) -> void:
	if player == null:
		return
	player.equipment_system.unequip(slot_name, player.inventory)
	_refresh()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	# Track consumable hover in ItemList
	var local_position := inventory_list.get_local_mouse_position()
	var hovered := inventory_list.get_item_at_position(local_position, true)
	if hovered != _hovered_inventory_index:
		_hovered_inventory_index = hovered
		if _hovered_eq_index < 0:
			_update_comparison_label()


func _update_comparison_label() -> void:
	if comparison_label == null or player == null:
		return
	# Equipment hover takes priority — show stat comparison
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
	# Consumable hover
	if _hovered_inventory_index >= 0 and _hovered_inventory_index < _inventory_indices.size():
		comparison_label.text = LocaleManager.L("consumable_quickslot_hint")
		return
	comparison_label.text = LocaleManager.L("hover_to_compare")
