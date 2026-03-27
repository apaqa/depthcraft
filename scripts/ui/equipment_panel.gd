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
var _inventory_indices: Array[int] = []
var _inventory_types: Array[String] = []
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
	for child in slot_list.get_children():
		child.queue_free()
	inventory_list.clear()
	inventory_list.fixed_icon_size = Vector2i(32, 32)
	_inventory_indices.clear()
	_inventory_types.clear()
	_hovered_inventory_index = -1
	if player == null:
		return
	for slot_name in player.equipment_system.get_slot_order():
		var button := Button.new()
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		button.text = _build_slot_text(slot_name, item)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		if not item.is_empty():
			var color = player.equipment_system.get_item_display_color(item)
			_apply_rarity_style(button, color)
			var icon = item.get("icon")
			if icon is Texture2D:
				button.icon = icon
		button.pressed.connect(_on_slot_pressed.bind(String(slot_name)))
		slot_list.add_child(button)

	# Equipment in inventory
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		var slot_name := str(stack.get("slot", ""))
		var icon = stack.get("icon")
		if not icon is Texture2D:
			icon = null
		inventory_list.add_item(_translate_slot(slot_name), icon)
		var item_index := inventory_list.get_item_count() - 1
		inventory_list.set_item_icon_mode(item_index, ItemList.ICON_MODE_TOP)
		inventory_list.set_item_text_alignment(item_index, HORIZONTAL_ALIGNMENT_CENTER)
		inventory_list.set_item_tooltip(item_index, "%s\n%s" % [_get_item_display_name(stack), LocaleManager.L("hint_right_click_discard")])
		inventory_list.set_item_custom_fg_color(item_index, player.equipment_system.get_item_display_color(stack))
		_inventory_indices.append(index)
		_inventory_types.append("equipment")
	# Consumables in inventory (for Q/R quickslot assignment)
	var q_id: String = str(player.get("consumable_q_id")) if player != null else ""
	var r_id: String = str(player.get("consumable_r_id")) if player != null else ""
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "consumable":
			continue
		var id := str(stack.get("id", ""))
		var label := ITEM_DATABASE.get_stack_display_name(stack)
		var qty := int(stack.get("quantity", 0))
		var tag := ""
		if id == q_id:
			tag = " [Q]"
		elif id == r_id:
			tag = " [R]"
		inventory_list.add_item("%s x%d%s  %s" % [label, qty, tag, LocaleManager.L("hint_right_click_quickslot")])
		inventory_list.set_item_custom_fg_color(inventory_list.get_item_count() - 1, Color(0.32, 0.78, 0.42, 1.0))
		_inventory_indices.append(index)
		_inventory_types.append("consumable")
	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		LocaleManager.L("atk"), int(summary.get("attack", 0)),
		LocaleManager.L("def"), int(summary.get("defense", 0)),
		LocaleManager.L("hp"), int(summary.get("max_hp", 0)),
		LocaleManager.L("spd"), int(summary.get("speed", 0)),
	]
	comparison_label.text = LocaleManager.L("hover_to_compare")


func _apply_rarity_style(node: Control, base_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8) # Dark background
	
	# Middle Layer: Original color border (2px)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	
	# Outer Layer: Darkened color via shadow (2px size, 0 offset)
	style.shadow_color = base_color.darkened(0.4)
	style.shadow_size = 2
	
	node.add_theme_stylebox_override("normal", style)
	node.add_theme_stylebox_override("hover", style.duplicate())
	node.add_theme_stylebox_override("pressed", style.duplicate())
	
	# Inner Layer: Lightened color (1px) via a child decoration
	var inner_border := ReferenceRect.new()
	inner_border.name = "InnerBorder"
	inner_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_border.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inner_border.grow_vertical = Control.GROW_DIRECTION_BOTH
	inner_border.offset_left = 2
	inner_border.offset_top = 2
	inner_border.offset_right = -2
	inner_border.offset_bottom = -2
	inner_border.border_color = base_color.lightened(0.4)
	inner_border.border_width = 1.0
	inner_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(inner_border)


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
	if player == null or index < 0 or index >= _inventory_indices.size():
		return
	if index < _inventory_types.size() and _inventory_types[index] == "consumable":
		return
	player.equipment_system.equip_from_inventory(player.inventory, _inventory_indices[index])
	_refresh()


func _on_inventory_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	if index < 0 or index >= _inventory_indices.size():
		return
	_context_inv_index = _inventory_indices[index]
	var item_type := _inventory_types[index] if index < _inventory_types.size() else ""
	_context_menu.clear()
	if item_type == "equipment":
		_context_menu.add_item(LocaleManager.L("ctx_discard"), 0)
	elif item_type == "consumable":
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
	var local_position := inventory_list.get_local_mouse_position()
	var hovered := inventory_list.get_item_at_position(local_position, true)
	if hovered == _hovered_inventory_index:
		return
	_hovered_inventory_index = hovered
	_update_comparison_label()


func _update_comparison_label() -> void:
	if comparison_label == null or player == null:
		return
	if _hovered_inventory_index < 0 or _hovered_inventory_index >= _inventory_indices.size():
		comparison_label.text = LocaleManager.L("hover_to_compare")
		return
	if _hovered_inventory_index < _inventory_types.size() and _inventory_types[_hovered_inventory_index] == "consumable":
		comparison_label.text = LocaleManager.L("consumable_quickslot_hint")
		return
	var stack_index: int = _inventory_indices[_hovered_inventory_index]
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
