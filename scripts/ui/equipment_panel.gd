extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@onready var slot_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotList
@onready var inventory_list: ItemList = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryList
@onready var stat_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatLabel
@onready var comparison_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ComparisonLabel

var player = null
var _inventory_indices: Array[int] = []
var _hovered_inventory_index: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_list.item_selected.connect(_on_inventory_selected)
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
	_inventory_indices.clear()
	_hovered_inventory_index = -1
	if player == null:
		return
	for slot_name in player.equipment_system.get_slot_order():
		var button := Button.new()
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		button.text = _build_slot_text(slot_name, item)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not item.is_empty():
			button.modulate = player.equipment_system.get_item_display_color(item)
		button.pressed.connect(_on_slot_pressed.bind(String(slot_name)))
		slot_list.add_child(button)
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		var display_name = player.equipment_system.get_item_display_name(stack)
		var slot_name := str(stack.get("slot", ""))
		inventory_list.add_item("%s [%s]" % [display_name, _translate_slot(slot_name)])
		inventory_list.set_item_custom_fg_color(inventory_list.get_item_count() - 1, ITEM_DATABASE.get_stack_color(stack))
		_inventory_indices.append(index)
	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "攻擊: %d   防禦: %d   血量: %d   速度: %d" % [
		int(summary.get("attack", 0)),
		int(summary.get("defense", 0)),
		int(summary.get("max_hp", 0)),
		int(summary.get("speed", 0)),
	]
	comparison_label.text = "滑鼠移至背包裝備可比較。"


func _build_slot_text(slot_name: String, item: Dictionary) -> String:
	var label := "[%s] " % _translate_slot(slot_name)
	if item.is_empty():
		return label + "空"
	var durability := int(item.get("durability", 0))
	var max_durability := int(item.get("max_durability", 0))
	return "%s%s  耐久: %d/%d" % [label, player.equipment_system.get_item_display_name(item), durability, max_durability]


func _translate_slot(slot_name: String) -> String:
	match slot_name:
		"weapon": return "武器"
		"helmet": return "頭盔"
		"chest_armor": return "胸甲"
		"boots": return "鞋子"
		"accessory": return "飾品"
		"offhand": return "副手"
		"tool": return "工具"
	return slot_name.replace("_", " ").capitalize()


func _on_inventory_selected(index: int) -> void:
	if player == null or index < 0 or index >= _inventory_indices.size():
		return
	player.equipment_system.equip_from_inventory(player.inventory, _inventory_indices[index])
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
		comparison_label.text = "滑鼠移至背包裝備可比較。"
		return
	var stack_index: int = _inventory_indices[_hovered_inventory_index]
	if stack_index < 0 or stack_index >= player.inventory.items.size():
		comparison_label.text = "滑鼠移至背包裝備可比較。"
		return
	var item: Dictionary = player.inventory.items[stack_index]
	var current_summary: Dictionary = player.get_stats_summary()
	var preview_summary: Dictionary = player.get_stats_summary_for_item(item)
	var lines = player.equipment_system.get_comparison_lines(current_summary, preview_summary)
	var chinese_lines: Array[String] = []
	for line in lines:
		var translated = line.replace("ATK", "攻擊").replace("DEF", "防禦").replace("HP", "血量").replace("SPD", "速度")
		chinese_lines.append(translated)
	comparison_label.text = "\n".join(chinese_lines)
