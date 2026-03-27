extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@onready var panel_container: PanelContainer = $PanelContainer

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var detail_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DetailLabel
@onready var content_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

var player = null
var facility = null
var upgrade_label: Label = null
var upgrade_button: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = LocaleManager.L("repair_bench")
	_resize_panel()
	_ensure_close_button()
	_ensure_upgrade_controls()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_panel()


func open_for_player(target_player, target_facility = null) -> void:
	player = target_player
	facility = target_facility
	visible = true
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	_refresh()


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


func _refresh() -> void:
	for child in list_container.get_children():
		child.queue_free()
	if player == null:
		detail_label.text = LocaleManager.L("repair_no_player")
		return
	var repair_cost_multiplier: float = facility.get_repair_cost_multiplier() if facility != null and facility.has_method("get_repair_cost_multiplier") else 1.0
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
		title.text = LocaleManager.L("repair_equipped_item_fmt") % [player.equipment_system.get_item_display_name(item), _translate_slot_name(slot_name)]
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
		info.text = LocaleManager.L("durability_label") % [durability, max_durability]
		row.add_child(info)
		var cost: Dictionary = player.equipment_system.get_repair_cost(slot_name, repair_cost_multiplier)
		if not cost.is_empty():
			repairable_any = true
			var cost_parts: PackedStringArray = []
			var can_afford := true
			for resource_id in cost.keys():
				cost_parts.append("%d %s" % [int(cost[resource_id]), ITEM_DATABASE.get_display_name(str(resource_id))])
				if player.inventory.get_item_count(str(resource_id)) < int(cost[resource_id]):
					can_afford = false
			var cost_label := Label.new()
			cost_label.text = LocaleManager.L("repair_cost_fmt") % ", ".join(cost_parts)
			row.add_child(cost_label)
			var button := Button.new()
			button.text = LocaleManager.L("repair")
			button.disabled = not can_afford
			button.pressed.connect(_on_repair_pressed.bind(slot_name))
			row.add_child(button)
		list_container.add_child(row)
	# Inventory (unequipped) equipment
	for index in range(player.inventory.items.size()):
		var item: Dictionary = player.inventory.items[index]
		if str(item.get("type", "")) != "equipment":
			continue
		var durability := int(item.get("durability", 0))
		var max_durability := int(item.get("max_durability", 0))
		if max_durability <= 0:
			continue
		equipped_any = true
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.text = LocaleManager.L("repair_inventory_item_fmt") % [player.equipment_system.get_item_display_name(item), LocaleManager.L("inventory_short")]
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
		info.text = LocaleManager.L("durability_label") % [durability, max_durability]
		row.add_child(info)
		var lost = max(max_durability - durability, 0)
		if lost > 0:
			repairable_any = true
			var material = player.equipment_system.get_repair_material("", item)
			var cost_amount = max(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
			var can_afford = player.inventory.get_item_count(material) >= cost_amount
			var cost_label := Label.new()
			cost_label.text = LocaleManager.L("repair_cost_single_fmt") % [cost_amount, ITEM_DATABASE.get_display_name(material)]
			row.add_child(cost_label)
			var button := Button.new()
			button.text = LocaleManager.L("repair")
			button.disabled = not can_afford
			button.pressed.connect(_on_repair_inventory_pressed.bind(index))
			row.add_child(button)
		list_container.add_child(row)
	if not equipped_any:
		detail_label.text = LocaleManager.L("repair_none_equipped")
		return
	if not repairable_any:
		detail_label.text = LocaleManager.L("repair_all_full")
	else:
		detail_label.text = LocaleManager.L("repair_prompt")
	_refresh_upgrade_controls()


func _on_repair_pressed(slot_name: String) -> void:
	if player == null:
		return
	var repair_cost_multiplier: float = facility.get_repair_cost_multiplier() if facility != null and facility.has_method("get_repair_cost_multiplier") else 1.0
	if player.equipment_system.repair_slot(slot_name, player.inventory, repair_cost_multiplier):
		_refresh()


func _on_repair_inventory_pressed(inv_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var item: Dictionary = player.inventory.items[inv_index]
	var max_dur := int(item.get("max_durability", 0))
	var dur := int(item.get("durability", max_dur))
	var lost = max(max_dur - dur, 0)
	if lost <= 0:
		return
	var material = player.equipment_system.get_repair_material("", item)
	var repair_cost_multiplier: float = facility.get_repair_cost_multiplier() if facility != null and facility.has_method("get_repair_cost_multiplier") else 1.0
	var cost_amount = max(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
	if player.inventory.get_item_count(material) < cost_amount:
		return
	player.inventory.remove_item(material, cost_amount)
	item["durability"] = max_dur
	player.inventory.inventory_changed.emit()
	_refresh()


func _translate_slot_name(slot_name: String) -> String:
	match slot_name:
		"weapon":
			return LocaleManager.L("slot_weapon")
		"helmet":
			return LocaleManager.L("slot_helmet")
		"chest_armor":
			return LocaleManager.L("slot_chest_armor")
		"boots":
			return LocaleManager.L("slot_boots")
		"accessory":
			return LocaleManager.L("slot_accessory")
		"offhand":
			return LocaleManager.L("slot_offhand")
		"tool":
			return LocaleManager.L("slot_tool")
	return slot_name.replace("_", " ").capitalize()


func _resize_panel() -> void:
	if panel_container == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_height: float = maxf(500.0, viewport_size.y * 0.7)
	var panel_width: float = maxf(440.0, viewport_size.x * 0.36)
	panel_container.offset_top = maxf(24.0, (viewport_size.y - panel_height) * 0.5)
	panel_container.offset_bottom = panel_container.offset_top + panel_height
	if viewport_size.x > 0.0:
		panel_container.offset_left = maxf(8.0, (viewport_size.x - panel_width) * 0.5)
		panel_container.offset_right = panel_container.offset_left + panel_width
	var close_btn := get_node_or_null("CloseButton") as Button
	if close_btn != null:
		close_btn.position = panel_container.position + Vector2(8, 8)


func _ensure_close_button() -> void:
	if get_node_or_null("CloseButton") != null:
		return
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.size = Vector2(32, 32)
	close_btn.position = panel_container.position + Vector2(8, 8)
	close_btn.z_index = 100
	close_btn.pressed.connect(close_menu)
	add_child(close_btn)


func _ensure_upgrade_controls() -> void:
	if content_vbox == null or upgrade_label != null:
		return
	upgrade_label = Label.new()
	upgrade_label.visible = false
	upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(upgrade_label)

	upgrade_button = Button.new()
	upgrade_button.visible = false
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	content_vbox.add_child(upgrade_button)


func _refresh_upgrade_controls() -> void:
	if upgrade_label == null or upgrade_button == null:
		return
	if facility == null or not facility.has_method("can_upgrade") or not facility.can_upgrade():
		upgrade_label.visible = false
		upgrade_button.visible = false
		return
	var cost: Dictionary = facility.get_upgrade_cost() if facility.has_method("get_upgrade_cost") else {}
	var parts: PackedStringArray = []
	var can_afford := true
	for resource_id in cost.keys():
		var need := int(cost[resource_id])
		var have: int = player.inventory.get_item_count(str(resource_id)) if player != null and player.inventory != null else 0
		parts.append("%s %d/%d" % [ITEM_DATABASE.get_display_name(str(resource_id)), have, need])
		if have < need:
			can_afford = false
	upgrade_label.text = "%s\nUpgrade Cost: %s" % [facility.get_upgrade_summary() if facility.has_method("get_upgrade_summary") else "", ", ".join(parts)]
	upgrade_label.visible = true
	upgrade_button.text = facility.get_upgrade_button_text() if facility.has_method("get_upgrade_button_text") else "Upgrade"
	upgrade_button.disabled = not can_afford
	upgrade_button.visible = true


func _on_upgrade_pressed() -> void:
	if facility == null or player == null or not facility.has_method("try_upgrade"):
		return
	if facility.try_upgrade(player):
		_refresh()
