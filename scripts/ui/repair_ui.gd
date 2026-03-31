extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/BodyHBox/LeftPanel/ListScroll/ListContainer
@onready var detail_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/BodyHBox/RightPanel/DetailVBox
@onready var content_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

var player = null
var facility = null
var upgrade_label: Label = null
var upgrade_button: Button = null

var _selected_slot: String = ""
var _selected_inv_index: int = -1
var _detail_placeholder: Label = null
var _detail_name_lbl: Label = null
var _detail_dur_bg: ColorRect = null
var _detail_dur_fill: ColorRect = null
var _detail_dur_lbl: Label = null
var _detail_cost_lbl: Label = null
var _detail_repair_btn: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = LocaleManager.L("repair_bench")
	title_label.add_theme_font_size_override("font_size", 22)
	_ensure_close_button()
	_ensure_upgrade_controls()
	var ru_style: StyleBoxFlat = StyleBoxFlat.new()
	ru_style.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	ru_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	ru_style.border_width_left = 1
	ru_style.border_width_top = 1
	ru_style.border_width_right = 1
	ru_style.border_width_bottom = 1
	panel_container.add_theme_stylebox_override("panel", ru_style)
	_build_detail_panel()


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
		_selected_slot = ""
		_selected_inv_index = -1
		_populate_detail()
		return

	for slot_name in player.equipment_system.get_slot_order():
		var item: Dictionary = player.equipment_system.get_equipped(slot_name)
		if item.is_empty():
			continue
		list_container.add_child(_build_repair_row(item, slot_name, -1))

	for index in range(player.inventory.items.size()):
		var item: Dictionary = player.inventory.items[index]
		if str(item.get("type", "")) != "equipment":
			continue
		if int(item.get("max_durability", 0)) <= 0:
			continue
		list_container.add_child(_build_repair_row(item, "", index))

	_populate_detail()
	_refresh_upgrade_controls()


func _build_repair_row(item: Dictionary, slot_name: String, inv_idx: int) -> Button:
	var row_btn: Button = Button.new()
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.flat = true

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(_build_item_icon(item))

	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 4)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label_text: String = _get_display_name(item)
	if slot_name != "":
		label_text = "%s [%s]" % [label_text, _translate_slot_name(slot_name)]
	else:
		label_text = "%s [%s]" % [label_text, LocaleManager.L("inventory_short")]
	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.self_modulate = player.equipment_system.get_item_display_color(item)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.add_child(name_lbl)

	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var dur_ratio: float = clampf(float(dur) / float(maxi(max_dur, 1)), 0.0, 1.0)
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.18, 0.18, 0.2, 1.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_fill: ColorRect = ColorRect.new()
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = dur_ratio
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.color = Color(1.0, 0.3, 0.3, 1.0) if dur <= 0 else \
		(Color(0.45, 1.0, 0.45, 1.0) if dur >= max_dur else Color(1.0, 0.75, 0.3, 1.0))
	bar_bg.add_child(bar_fill)
	info_col.add_child(bar_bg)

	hbox.add_child(info_col)
	row_btn.add_child(hbox)

	if slot_name != "":
		var sn: String = slot_name
		row_btn.pressed.connect(func() -> void: _set_selection(sn, -1))
	else:
		var idx: int = inv_idx
		row_btn.pressed.connect(func() -> void: _set_selection("", idx))

	return row_btn


func _set_selection(slot: String, inv_idx: int) -> void:
	_selected_slot = slot
	_selected_inv_index = inv_idx
	_populate_detail()


func _build_detail_panel() -> void:
	_detail_placeholder = Label.new()
	_detail_placeholder.text = LocaleManager.L("repair_prompt")
	_detail_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_detail_placeholder)

	_detail_name_lbl = Label.new()
	_detail_name_lbl.visible = false
	_detail_name_lbl.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(_detail_name_lbl)

	_detail_dur_bg = ColorRect.new()
	_detail_dur_bg.visible = false
	_detail_dur_bg.custom_minimum_size = Vector2(0, 14)
	_detail_dur_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_dur_bg.color = Color(0.18, 0.18, 0.2, 1.0)
	_detail_dur_fill = ColorRect.new()
	_detail_dur_fill.anchor_top = 0.0
	_detail_dur_fill.anchor_bottom = 1.0
	_detail_dur_fill.anchor_left = 0.0
	_detail_dur_fill.anchor_right = 0.0
	_detail_dur_fill.color = Color(0.45, 1.0, 0.45, 1.0)
	_detail_dur_bg.add_child(_detail_dur_fill)
	detail_vbox.add_child(_detail_dur_bg)

	_detail_dur_lbl = Label.new()
	_detail_dur_lbl.visible = false
	_detail_dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(_detail_dur_lbl)

	_detail_cost_lbl = Label.new()
	_detail_cost_lbl.visible = false
	_detail_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(_detail_cost_lbl)

	_detail_repair_btn = Button.new()
	_detail_repair_btn.visible = false
	_detail_repair_btn.text = LocaleManager.L("repair")
	_detail_repair_btn.pressed.connect(_on_detail_repair_pressed)
	detail_vbox.add_child(_detail_repair_btn)


func _populate_detail() -> void:
	if _detail_placeholder == null:
		return
	var has_selection: bool = _selected_slot != "" or _selected_inv_index >= 0

	if not has_selection or player == null:
		var msg: String = LocaleManager.L("repair_prompt")
		if player == null:
			msg = LocaleManager.L("repair_no_player")
		elif list_container.get_child_count() == 0:
			msg = LocaleManager.L("repair_none_equipped")
		_detail_placeholder.text = msg
		_detail_placeholder.visible = true
		_detail_name_lbl.visible = false
		_detail_dur_bg.visible = false
		_detail_dur_lbl.visible = false
		_detail_cost_lbl.visible = false
		_detail_repair_btn.visible = false
		return

	var item: Dictionary = {}
	var slot_label: String = ""
	var repair_cost_multiplier: float = _get_total_repair_cost_multiplier()

	if _selected_slot != "":
		item = player.equipment_system.get_equipped(_selected_slot)
		slot_label = _translate_slot_name(_selected_slot)
	elif _selected_inv_index >= 0 and _selected_inv_index < player.inventory.items.size():
		item = player.inventory.items[_selected_inv_index]
		slot_label = LocaleManager.L("inventory_short")

	if item.is_empty():
		_selected_slot = ""
		_selected_inv_index = -1
		_populate_detail()
		return

	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var dur_ratio: float = clampf(float(dur) / float(maxi(max_dur, 1)), 0.0, 1.0)

	_detail_placeholder.visible = false
	_detail_name_lbl.text = "%s [%s]" % [_get_display_name(item), slot_label]
	_detail_name_lbl.self_modulate = player.equipment_system.get_item_display_color(item)
	_detail_name_lbl.visible = true
	_detail_dur_fill.anchor_right = dur_ratio
	_detail_dur_fill.color = Color(1.0, 0.3, 0.3, 1.0) if dur <= 0 else \
		(Color(0.45, 1.0, 0.45, 1.0) if dur >= max_dur else Color(1.0, 0.75, 0.3, 1.0))
	_detail_dur_bg.visible = true
	_detail_dur_lbl.text = LocaleManager.L("durability_label") % [dur, max_dur]
	_detail_dur_lbl.visible = true

	var can_afford: bool = false
	if _selected_slot != "":
		var cost: Dictionary = player.equipment_system.get_repair_cost(_selected_slot).duplicate()
		for k in cost.keys():
			cost[k] = maxi(int(ceil(float(cost[k]) * repair_cost_multiplier)), 1)
		if not cost.is_empty():
			var cost_parts: PackedStringArray = []
			can_afford = true
			for resource_id in cost.keys():
				cost_parts.append("%d %s" % [int(cost[resource_id]), ITEM_DATABASE.get_display_name(str(resource_id))])
				if player.inventory.get_item_count(str(resource_id)) < int(cost[resource_id]):
					can_afford = false
			_detail_cost_lbl.text = LocaleManager.L("repair_cost_fmt") % ", ".join(cost_parts)
			_detail_cost_lbl.visible = true
			_detail_repair_btn.disabled = not can_afford
			_detail_repair_btn.visible = dur < max_dur
		else:
			_detail_cost_lbl.visible = false
			_detail_repair_btn.visible = false
	else:
		var lost: int = maxi(max_dur - dur, 0)
		if lost > 0:
			var material: String = str(player.equipment_system.get_repair_material("", item))
			var cost_amount: int = maxi(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
			can_afford = player.inventory.get_item_count(material) >= cost_amount
			_detail_cost_lbl.text = LocaleManager.L("repair_cost_single_fmt") % [cost_amount, ITEM_DATABASE.get_display_name(material)]
			_detail_cost_lbl.visible = true
			_detail_repair_btn.disabled = not can_afford
			_detail_repair_btn.visible = true
		else:
			_detail_cost_lbl.visible = false
			_detail_repair_btn.visible = false


func _on_detail_repair_pressed() -> void:
	if _selected_slot != "":
		_on_repair_pressed(_selected_slot)
	elif _selected_inv_index >= 0:
		_on_repair_inventory_pressed(_selected_inv_index)
	_selected_slot = ""
	_selected_inv_index = -1


func _on_repair_pressed(slot_name: String) -> void:
	if player == null:
		return
	if player.equipment_system.repair_slot(slot_name, player.inventory):
		_refresh()


func _on_repair_inventory_pressed(inv_index: int) -> void:
	if player == null or inv_index < 0 or inv_index >= player.inventory.items.size():
		return
	var item: Dictionary = player.inventory.items[inv_index]
	var max_dur: int = int(item.get("max_durability", 0))
	var dur: int = int(item.get("durability", max_dur))
	var lost: int = maxi(max_dur - dur, 0)
	if lost <= 0:
		return
	var material: String = str(player.equipment_system.get_repair_material("", item))
	var repair_cost_multiplier: float = _get_total_repair_cost_multiplier()
	var cost_amount: int = maxi(int(ceil(float(lost) / 10.0 * repair_cost_multiplier)), 1)
	if player.inventory.get_item_count(material) < cost_amount:
		return
	player.inventory.remove_item(material, cost_amount)
	item["durability"] = max_dur
	player.inventory.mark_dirty()
	_refresh()


func _get_display_name(item: Dictionary) -> String:
	var raw_name: String = str(item.get("name", ""))
	if raw_name != "":
		return raw_name
	var item_id: String = str(item.get("id", str(item.get("item_id", ""))))
	var db_name: String = ITEM_DATABASE.get_display_name(item_id)
	if db_name != "" and db_name != item_id:
		return db_name
	return item_id.replace("_", " ").capitalize()


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


func _build_item_icon(item: Dictionary) -> Control:
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(item)
	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.size = Vector2(16, 16)
		icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.texture = icon
		return icon_rect
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.color = ITEM_DATABASE.get_stack_color(item)
	return swatch


func _ensure_close_button() -> void:
	if panel_container.get_node_or_null("CloseButton") != null:
		return
	var close_btn: Button = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.size = Vector2(32, 32)
	close_btn.position = Vector2(8.0, 8.0)
	close_btn.z_index = 100
	close_btn.pressed.connect(close_menu)
	var cb_normal: StyleBoxFlat = StyleBoxFlat.new()
	cb_normal.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	cb_normal.border_color = Color(0.3, 0.3, 0.35, 1.0)
	cb_normal.border_width_left = 1
	cb_normal.border_width_top = 1
	cb_normal.border_width_right = 1
	cb_normal.border_width_bottom = 1
	var cb_hover: StyleBoxFlat = cb_normal.duplicate()
	cb_hover.bg_color = Color(0.28, 0.28, 0.34, 0.95)
	close_btn.add_theme_stylebox_override("normal", cb_normal)
	close_btn.add_theme_stylebox_override("hover", cb_hover)
	panel_container.add_child(close_btn)


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
	var can_afford: bool = true
	for resource_id in cost.keys():
		var need: int = int(cost[resource_id])
		var have: int = player.inventory.get_item_count(str(resource_id)) if player != null and player.inventory != null else 0
		parts.append("%s %d/%d" % [ITEM_DATABASE.get_display_name(str(resource_id)), have, need])
		if have < need:
			can_afford = false
	upgrade_label.text = "%s\n%s: %s" % [facility.get_upgrade_summary() if facility.has_method("get_upgrade_summary") else "", LocaleManager.L("upgrade_cost"), ", ".join(parts)]
	upgrade_label.visible = true
	upgrade_button.text = facility.get_upgrade_button_text() if facility.has_method("get_upgrade_button_text") else LocaleManager.L("upgrade_to_lv") % 2
	upgrade_button.disabled = not can_afford
	upgrade_button.visible = true


func _on_upgrade_pressed() -> void:
	if facility == null or player == null or not facility.has_method("try_upgrade"):
		return
	if facility.try_upgrade(player):
		_refresh()


func _get_total_repair_cost_multiplier() -> float:
	var facility_multiplier: float = facility.get_repair_cost_multiplier() \
		if facility != null and facility.has_method("get_repair_cost_multiplier") else 1.0
	var npc_multiplier: float = NpcManager.get_repair_cost_multiplier() if NpcManager != null else 1.0
	return facility_multiplier * npc_multiplier
