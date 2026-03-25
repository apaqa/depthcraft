extends Control

signal close_requested

@onready var equipment_list: ItemList = $PanelContainer/MarginContainer/VBoxContainer/EquipmentList
@onready var detail_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DetailLabel
@onready var repair_button: Button = $PanelContainer/MarginContainer/VBoxContainer/RepairButton

var player = null
var _repairable_slots: Array[String] = []
var _selected_slot: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_list.item_selected.connect(_on_item_selected)
	repair_button.pressed.connect(_on_repair_pressed)


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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	equipment_list.clear()
	_repairable_slots.clear()
	_selected_slot = ""
	repair_button.disabled = true
	if player == null:
		detail_label.text = "No repair target."
		return
	for slot_name in player.equipment_system.get_repairable_slots():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		equipment_list.add_item("%s (%d/%d)" % [
			str(item.get("name", slot_name)),
			int(item.get("durability", 0)),
			int(item.get("max_durability", 0)),
		])
		_repairable_slots.append(slot_name)
	if _repairable_slots.is_empty():
		detail_label.text = "Everything is fully repaired."
		return
	equipment_list.select(0)
	_on_item_selected(0)


func _on_item_selected(index: int) -> void:
	if player == null or index < 0 or index >= _repairable_slots.size():
		return
	_selected_slot = _repairable_slots[index]
	var item: Dictionary = player.equipment_system.get_equipped(_selected_slot)
	var cost: Dictionary = player.equipment_system.get_repair_cost(_selected_slot)
	var cost_parts: PackedStringArray = []
	for resource_id in cost.keys():
		cost_parts.append("%d %s" % [int(cost[resource_id]), resource_id.replace("_", " ")])
	detail_label.text = "%s\nRepair Cost: %s" % [str(item.get("name", _selected_slot)), ", ".join(cost_parts)]
	repair_button.disabled = false


func _on_repair_pressed() -> void:
	if player == null or _selected_slot == "":
		return
	if player.equipment_system.repair_slot(_selected_slot, player.inventory):
		_refresh()
