extends Control

signal close_requested

@onready var slot_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SlotPanel/VBoxContainer/SlotList
@onready var inventory_list: ItemList = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/InventoryPanel/VBoxContainer/InventoryList
@onready var stat_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatLabel

var player = null
var _inventory_indices: Array[int] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_list.item_selected.connect(_on_inventory_selected)


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
	if player == null:
		return
	for slot_name in player.equipment_system.get_slot_order():
		var button := Button.new()
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		button.text = _build_slot_text(slot_name, item)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_slot_pressed.bind(String(slot_name)))
		slot_list.add_child(button)
	for index in range(player.inventory.items.size()):
		var stack: Dictionary = player.inventory.items[index]
		if str(stack.get("type", "")) != "equipment":
			continue
		inventory_list.add_item("%s [%s]" % [str(stack.get("name", stack.get("id", ""))), str(stack.get("slot", ""))])
		_inventory_indices.append(index)
	var summary: Dictionary = player.get_stats_summary()
	stat_label.text = "ATK: %d   DEF: %d   HP: %d   SPD: %d" % [
		int(summary.get("attack", 0)),
		int(summary.get("defense", 0)),
		int(summary.get("max_hp", 0)),
		int(summary.get("speed", 0)),
	]


func _build_slot_text(slot_name: String, item: Dictionary) -> String:
	var label := "[%s] " % slot_name.replace("_", " ").capitalize()
	if item.is_empty():
		return label + "Empty"
	var durability := int(item.get("durability", 0))
	var max_durability := int(item.get("max_durability", 0))
	var broken_suffix := " (Broken)" if max_durability > 0 and durability <= 0 else ""
	return "%s%s%s  Dur: %d/%d" % [label, str(item.get("name", item.get("id", ""))), broken_suffix, durability, max_durability]


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
