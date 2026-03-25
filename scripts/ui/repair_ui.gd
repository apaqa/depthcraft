extends Control

signal close_requested

@onready var list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var detail_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DetailLabel

var player = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	for child in list_container.get_children():
		child.queue_free()
	if player == null:
		detail_label.text = "無修理對象"
		return
	var equipped_any := false
	var repairable_any := false
	for slot_name in player.equipment_system.get_slot_order():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		if item.is_empty():
			continue
		equipped_any = true
		var durability := int(item.get("durability", 0))
		var max_durability := int(item.get("max_durability", 0))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.text = "%s (%s)" % [player.equipment_system.get_item_display_name(item), slot_name.replace("_", " ").capitalize()]
		title.self_modulate = player.equipment_system.get_item_display_color(item)
		row.add_child(title)
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(280, 10)
		bar_bg.color = Color(0.18, 0.18, 0.2, 1.0)
		var bar_fill := ColorRect.new()
		bar_fill.custom_minimum_size = Vector2(280.0 * clampf(float(durability) / float(max(max_durability, 1)), 0.0, 1.0), 10)
		bar_fill.color = Color(1.0, 0.3, 0.3, 1.0) if durability <= 0 else (Color(0.45, 1.0, 0.45, 1.0) if durability >= max_durability else Color(1.0, 0.75, 0.3, 1.0))
		bar_bg.add_child(bar_fill)
		row.add_child(bar_bg)
		var info := Label.new()
		info.text = "耐久: %d/%d" % [durability, max_durability]
		row.add_child(info)
		var cost: Dictionary = player.equipment_system.get_repair_cost(slot_name)
		if not cost.is_empty():
			repairable_any = true
			var cost_parts: PackedStringArray = []
			var can_afford := true
			for resource_id in cost.keys():
				cost_parts.append("%d %s" % [int(cost[resource_id]), resource_id.replace("_", " ").capitalize()])
				if player.inventory.get_item_count(str(resource_id)) < int(cost[resource_id]):
					can_afford = false
			var cost_label := Label.new()
			cost_label.text = "Cost: %s" % ", ".join(cost_parts)
			row.add_child(cost_label)
			var button := Button.new()
			button.text = "[Repair]"
			button.disabled = not can_afford
			button.pressed.connect(_on_repair_pressed.bind(slot_name))
			row.add_child(button)
		list_container.add_child(row)
	if not equipped_any:
		detail_label.text = "沒有需要修理的裝備。請先裝備物品"
		return
	if not repairable_any:
		detail_label.text = "所有裝備耐久已滿"
	else:
		detail_label.text = "點選需要修理的物品進行修理"


func _on_repair_pressed(slot_name: String) -> void:
	if player == null:
		return
	if player.equipment_system.repair_slot(slot_name, player.inventory):
		_refresh()
