extends Area2D
class_name DungeonMerchant

const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const GIFT_BOX_SYSTEM = preload("res://scripts/dungeon/gift_box_system.gd")
const MERCHANT_TEXTURE = preload("res://assets/npc_merchant_2.png")
const UI_AUDIO_CLICK_HOOK = preload("res://scripts/ui/ui_audio_click_hook.gd")
const SHOP_CONSUMABLES: Array[Dictionary] = [
	{"id": "bandage", "quantity": 1, "price": 5, "desc_key": "item_bandage_desc"},
	{"id": "bread", "quantity": 1, "price": 5, "desc_key": "item_bread_desc"},
	{"id": "torch", "quantity": 3, "price": 6, "desc_key": "item_torch_desc"},
]
const SHOP_EQUIPMENT: Array[Dictionary] = [
	{"id": "gift_copper", "quantity": 1, "price": 50, "desc_key": "gift_copper_desc"},
	{"id": "gift_silver", "quantity": 1, "price": 500, "desc_key": "gift_silver_desc"},
	{"id": "gift_gold", "quantity": 1, "price": 20000, "desc_key": "gift_gold_desc"},
	{"id": "giftbox_bronze", "quantity": 1, "price": 80, "desc_key": "giftbox_bronze_desc"},
	{"id": "giftbox_silver", "quantity": 1, "price": 500, "desc_key": "giftbox_silver_desc"},
]
const SHOP_SPECIAL: Array[Dictionary] = [
	{"id": "mystery_blessing", "quantity": 1, "price": 100, "desc_key": "mystery_blessing_desc"},
]
# Legacy compat
const SHOP_ITEMS: Array[Dictionary] = [
	{"id": "bandage", "quantity": 1, "price": 5},
	{"id": "bread", "quantity": 1, "price": 5},
	{"id": "torch", "quantity": 3, "price": 6},
	{"id": "mystery_blessing", "quantity": 1, "price": 100},
	{"id": "gift_copper", "quantity": 1, "price": 50},
	{"id": "gift_silver", "quantity": 1, "price": 500},
	{"id": "gift_gold", "quantity": 1, "price": 20000},
]

const GIFT_ICONS: Dictionary = {
	"gift_copper": preload("res://assets/icons/kyrise/gift_01a.png"),
	"gift_silver": preload("res://assets/icons/kyrise/gift_01b.png"),
	"gift_gold": preload("res://assets/icons/kyrise/gift_01e.png"),
	"giftbox_bronze": preload("res://assets/icons/kyrise/gift_01a.png"),
	"giftbox_silver": preload("res://assets/icons/kyrise/gift_01b.png"),
}
const GIFT_NAMES: Dictionary = {
	"gift_copper": "gift_copper_name",
	"gift_silver": "gift_silver_name",
	"gift_gold": "gift_gold_name",
	"giftbox_bronze": "giftbox_bronze_name",
	"giftbox_silver": "giftbox_silver_name",
}
const GIFT_RARITY_WEIGHTS: Dictionary = {
	"gift_copper": [["Common", 60], ["Uncommon", 30], ["Rare", 10]],
	"gift_silver": [["Common", 60], ["Uncommon", 30], ["Rare", 7], ["Epic", 3]],
	"gift_gold": [["Common", 60], ["Uncommon", 30], ["Rare", 6], ["Epic", 3], ["Legendary", 1]],
}

var _shop_canvas: CanvasLayer = null
var _shop_root: Control = null
var _purchased_gifts: Dictionary = {}
var _current_player: Variant = null
var _gold_label: Label = null
var _message_label: Label = null
var _equipment_icon: TextureRect = null
var _equipment_label: Label = null
var _equipment_button: Button = null
var _equipment_offer: Dictionary = {}
var _equipment_price: int = 0
var _floor_number: int = 1
var override_items: Array = []
var override_title: String = ""
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_price: Label = null
var _detail_buy_btn: Button = null
var _detail_placeholder: Label = null
var _item_list_container: VBoxContainer = null
var _active_tab: int = 0
var _tab_buttons: Array[Button] = []


func setup(floor_number: int, rng: RandomNumberGenerator = null) -> void:
	_floor_number = max(floor_number, 1)
	_equipment_offer = DUNGEON_LOOT.generate_dungeon_equipment(_floor_number + 1, rng)
	_equipment_price = _calculate_equipment_price(_floor_number, _equipment_offer)


func _ready() -> void:
	_ensure_visuals()
	if _equipment_offer.is_empty():
		setup(_floor_number)


func _exit_tree() -> void:
	_close_shop()


func get_interaction_prompt() -> String:
	return LocaleManager.L("merchant_interact")


func interact(player) -> void:
	if _shop_canvas != null:
		return
	_current_player = player
	_open_shop()
	if player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	if "in_menu" in player:
		player.in_menu = true


func _input(event: InputEvent) -> void:
	if _shop_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_shop()
		get_viewport().set_input_as_handled()


func _ensure_visuals() -> void:
	if get_node_or_null("Sprite2D") == null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = MERCHANT_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color(1.0, 0.92, 0.78, 1.0)
		add_child(sprite)
	if get_node_or_null("CollisionShape2D") == null:
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 14.0
		collision.shape = shape
		add_child(collision)
	var marker: Variant = get_node_or_null("TradeMarker")
	if marker == null:
		marker = Polygon2D.new()
		marker.name = "TradeMarker"
		marker.color = Color(0.9, 0.72, 0.24, 0.8)
		marker.polygon = PackedVector2Array([
			Vector2(-10.0, 13.0),
			Vector2(10.0, 13.0),
			Vector2(8.0, 17.0),
			Vector2(-8.0, 17.0),
		])
		add_child(marker)


func _open_shop() -> void:
	_shop_canvas = CanvasLayer.new()
	_shop_canvas.layer = 10
	add_child(_shop_canvas)

	_shop_root = Control.new()
	_shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_canvas.add_child(_shop_root)

	# Backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_root.add_child(backdrop)

	# Main panel 80% screen
	var panel: Panel = Panel.new()
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.13, 0.97)
	panel_style.border_color = Color(0.4, 0.35, 0.25, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	_shop_root.add_child(panel)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(outer_margin)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	outer_margin.add_child(outer_vbox)

	# Title
	var title: Label = Label.new()
	title.text = override_title if override_title != "" else LocaleManager.L("boss_merchant_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	outer_vbox.add_child(title)
	outer_vbox.add_child(HSeparator.new())

	# Main content: left (items) + right (detail)
	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(content_hbox)

	# Left side (60%)
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.5
	left_panel.add_theme_constant_override("separation", 6)
	content_hbox.add_child(left_panel)

	# Tabs (only show if not override_items / has multiple categories)
	var is_dungeon_shop: bool = override_items.is_empty()
	if is_dungeon_shop:
		var tab_row: HBoxContainer = HBoxContainer.new()
		tab_row.add_theme_constant_override("separation", 4)
		left_panel.add_child(tab_row)
		_tab_buttons.clear()
		var tab_names: Array[String] = [
			LocaleManager.L("shop_tab_consumables"),
			LocaleManager.L("shop_tab_equipment"),
			LocaleManager.L("shop_tab_special"),
		]
		for i: int in range(tab_names.size()):
			var tab_btn: Button = Button.new()
			tab_btn.text = tab_names[i]
			tab_btn.custom_minimum_size = Vector2(80, 28)
			tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab_btn.pressed.connect(_switch_tab.bind(i))
			tab_row.add_child(tab_btn)
			_tab_buttons.append(tab_btn)

	# Item list (scrollable)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	_item_list_container = VBoxContainer.new()
	_item_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_item_list_container)

	# Right side (40%): detail panel
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.add_theme_constant_override("separation", 10)
	content_hbox.add_child(right_panel)
	_build_detail_panel(right_panel)

	outer_vbox.add_child(HSeparator.new())

	# Footer
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(footer)
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	footer.add_child(_gold_label)
	_message_label = Label.new()
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
	footer.add_child(_message_label)
	var close_btn: Button = Button.new()
	close_btn.text = LocaleManager.L("close_button")
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(_close_shop)
	footer.add_child(close_btn)

	# Populate
	if is_dungeon_shop:
		_switch_tab(0)
	else:
		_populate_item_list(override_items)
	_update_gold_label()
	UI_AUDIO_CLICK_HOOK.attach(_shop_root)
	AudioManager.play_sfx("ui_open")


func _build_detail_panel(parent: VBoxContainer) -> void:
	_detail_placeholder = Label.new()
	_detail_placeholder.text = LocaleManager.L("shop_select_item")
	_detail_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_placeholder.modulate = Color(0.5, 0.5, 0.55, 1.0)
	_detail_placeholder.add_theme_font_size_override("font_size", 14)
	parent.add_child(_detail_placeholder)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(48, 48)
	_detail_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.visible = false
	parent.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	_detail_name.visible = false
	parent.add_child(_detail_name)
	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 13)
	_detail_desc.modulate = Color(0.75, 0.78, 0.85, 1.0)
	_detail_desc.visible = false
	parent.add_child(_detail_desc)
	_detail_price = Label.new()
	_detail_price.add_theme_font_size_override("font_size", 14)
	_detail_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_detail_price.visible = false
	parent.add_child(_detail_price)
	_detail_buy_btn = Button.new()
	_detail_buy_btn.text = LocaleManager.L("buy")
	_detail_buy_btn.custom_minimum_size = Vector2(120, 36)
	_detail_buy_btn.visible = false
	parent.add_child(_detail_buy_btn)


func _switch_tab(tab_index: int) -> void:
	_active_tab = tab_index
	for i: int in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1.0, 0.9, 0.5, 1.0) if i == tab_index else Color(0.7, 0.7, 0.7, 1.0)
	var items: Array[Dictionary] = []
	match tab_index:
		0:
			items = SHOP_CONSUMABLES
		1:
			items = SHOP_EQUIPMENT
		2:
			items = SHOP_SPECIAL
	_populate_item_list(items)


func _populate_item_list(items: Array) -> void:
	if _item_list_container == null:
		return
	for child: Node in _item_list_container.get_children():
		child.queue_free()
	# Equipment offer row for equipment tab
	if _active_tab == 1 and override_items.is_empty():
		_add_equipment_row(_item_list_container)
		_refresh_equipment_offer_row()
	for item_offer: Variant in items:
		if item_offer is Dictionary:
			_add_item_row(_item_list_container, item_offer as Dictionary)
	_clear_detail()


func _add_item_row(parent: Control, item_offer: Dictionary) -> void:
	var offer_id: String = str(item_offer.get("id", ""))
	if _purchased_gifts.has(offer_id):
		return
	var item_data: Dictionary = ITEM_DATABASE.get_item(offer_id)
	var quantity: int = int(item_offer.get("quantity", 1))
	var display_name: String = str(item_data.get("name", ITEM_DATABASE.get_display_name(offer_id)))
	if offer_id == "mystery_blessing":
		display_name = LocaleManager.L("mystery_blessing_name")
	elif GIFT_NAMES.has(offer_id):
		display_name = LocaleManager.L(str(GIFT_NAMES[offer_id]))
	if quantity > 1:
		display_name = "%s x%d" % [display_name, quantity]
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(item_data)
	if offer_id == "mystery_blessing" and icon == null:
		var theme_icons: Array[Texture2D] = [
			preload("res://assets/icons/kyrise/crystal_01b.png"),
			preload("res://assets/icons/kyrise/crystal_01a.png"),
			preload("res://assets/icons/kyrise/crystal_01d.png"),
			preload("res://assets/icons/kyrise/crystal_01e.png"),
			preload("res://assets/icons/kyrise/crystal_01c.png"),
		]
		icon = theme_icons[randi() % theme_icons.size()]
	elif GIFT_ICONS.has(offer_id):
		icon = GIFT_ICONS[offer_id]
	var price: int = int(item_offer.get("price", 0))
	var desc_key: String = str(item_offer.get("desc_key", ""))
	var desc_text: String = LocaleManager.L(desc_key) if desc_key != "" else str(item_data.get("description", ""))
	_add_shop_row(parent, display_name, price, _on_buy_item.bind(offer_id, quantity, price), icon, offer_id, desc_text)


func _add_equipment_row(parent: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_equipment_icon = _make_icon_rect(ITEM_DATABASE.get_equipment_icon("weapon", "Common"))
	row.add_child(_equipment_icon)
	_equipment_label = Label.new()
	_equipment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_equipment_label)
	_equipment_button = Button.new()
	_equipment_button.pressed.connect(_on_buy_equipment)
	row.add_child(_equipment_button)
	parent.add_child(row)


func _add_shop_row(parent: Control, label_text: String, price: int, callback: Callable, icon: Texture2D = null, item_id: String = "", desc_text: String = "") -> void:
	var row_btn: Button = Button.new()
	row_btn.custom_minimum_size = Vector2(0, 32)
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.text = "  %s    %s" % [label_text, ITEM_DATABASE.format_currency(price)]
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = Color(0.14, 0.15, 0.2, 0.8)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.22, 0.24, 0.32, 0.9)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	row_btn.add_theme_stylebox_override("normal", row_style)
	row_btn.add_theme_stylebox_override("hover", hover_style)
	row_btn.add_theme_stylebox_override("pressed", hover_style)
	row_btn.add_theme_stylebox_override("focus", hover_style)
	row_btn.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97, 1.0))
	row_btn.pressed.connect(_show_detail.bind(label_text, desc_text, price, icon, callback))
	parent.add_child(row_btn)


func _show_detail(name_text: String, desc_text: String, price: int, icon: Texture2D, buy_callback: Callable) -> void:
	if _detail_placeholder != null:
		_detail_placeholder.visible = false
	if _detail_icon != null:
		_detail_icon.texture = icon
		_detail_icon.visible = icon != null
	if _detail_name != null:
		_detail_name.text = name_text
		_detail_name.visible = true
	if _detail_desc != null:
		_detail_desc.text = desc_text if desc_text != "" else "..."
		_detail_desc.visible = true
	if _detail_price != null:
		_detail_price.text = ITEM_DATABASE.format_currency(price)
		_detail_price.visible = true
	if _detail_buy_btn != null:
		# Disconnect old
		for conn: Dictionary in _detail_buy_btn.pressed.get_connections():
			_detail_buy_btn.pressed.disconnect(conn["callable"])
		_detail_buy_btn.pressed.connect(buy_callback)
		_detail_buy_btn.visible = true
		_detail_buy_btn.text = LocaleManager.L("buy")


func _clear_detail() -> void:
	if _detail_placeholder != null:
		_detail_placeholder.visible = true
	if _detail_icon != null:
		_detail_icon.visible = false
	if _detail_name != null:
		_detail_name.visible = false
	if _detail_desc != null:
		_detail_desc.visible = false
	if _detail_price != null:
		_detail_price.visible = false
	if _detail_buy_btn != null:
		_detail_buy_btn.visible = false


func _on_buy_item(item_id: String, quantity: int, price: int) -> void:
	if _current_player == null:
		return
	var inventory: Variant = _current_player.get("inventory")
	if inventory == null:
		return
	var payment: Dictionary = inventory.get_exact_currency_payment(price)
	if payment.is_empty():
		_set_message(LocaleManager.L("insufficient_gold"))
		return
	if item_id == "mystery_blessing":
		if inventory.pay_copper(price):
			_set_message("")
			_update_gold_label()
			_close_shop()
			_trigger_blessing_selection()
		else:
			_set_message(LocaleManager.L("insufficient_gold"))
		return
	if GIFT_RARITY_WEIGHTS.has(item_id):
		if inventory.pay_copper(price):
			var equip: Dictionary = _open_gift_box(item_id)
			if not equip.is_empty():
				if inventory.add_stack(equip):
					var equip_name: String = ITEM_DATABASE.get_stack_display_name(equip)
					_set_message(LocaleManager.L("gift_obtained") % equip_name)
					_purchased_gifts[item_id] = true
				else:
					inventory.refund_currency(payment)
					_set_message(LocaleManager.L("bag_full"))
			_update_gold_label()
		else:
			_set_message(LocaleManager.L("insufficient_gold"))
		return
	if item_id.begins_with("giftbox_"):
		if inventory.pay_copper(price):
			_update_gold_label()
			var loot: Dictionary = GIFT_BOX_SYSTEM.roll_loot(item_id)
			_deliver_giftbox_loot(loot)
		else:
			_set_message(LocaleManager.L("insufficient_gold"))
		return
	if inventory.pay_copper(price):
		if inventory.add_item(item_id, quantity):
			_set_message("")
			_update_gold_label()
			var am: Node = get_node_or_null("/root/AchievementManager")
			if am != null and am.has_method("record_merchant_purchase"):
				am.record_merchant_purchase()
		else:
			inventory.refund_currency(payment)
			_set_message(LocaleManager.L("bag_full"))
	else:
		_set_message(LocaleManager.L("insufficient_gold"))


func _open_gift_box(gift_id: String) -> Dictionary:
	var weights: Array = GIFT_RARITY_WEIGHTS.get(gift_id, []) as Array
	if weights.is_empty():
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var total_weight: int = 0
	for entry: Variant in weights:
		total_weight += int((entry as Array)[1])
	var roll: int = rng.randi() % maxi(total_weight, 1)
	var chosen_rarity: String = "Common"
	var running: int = 0
	for entry: Variant in weights:
		var pair: Array = entry as Array
		running += int(pair[1])
		if roll < running:
			chosen_rarity = str(pair[0])
			break
	return DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(_floor_number, chosen_rarity, rng)


func _deliver_giftbox_loot(loot: Dictionary) -> void:
	var loot_type: String = str(loot.get("type", "nothing"))
	if _current_player == null:
		return
	var inventory: Variant = _current_player.get("inventory")
	match loot_type:
		"item":
			var item_id: String = str(loot.get("id", ""))
			var qty: int = int(loot.get("qty", 1))
			if not item_id.is_empty() and qty > 0:
				if inventory != null:
					inventory.add_item(item_id, qty)
				_set_message("獲得: %s ×%d" % [item_id, qty])
		"blessing_choice", "blessing_scroll":
			_set_message("觸發祝福選擇！")
			_close_shop()
			_trigger_blessing_selection()
		"random_buff":
			var pool: Array = [
				{"type": "damage_multiplier", "value": 0.10, "name": "ATK +10%"},
				{"type": "armor_reduction", "value": 0.15, "name": "防禦 +15%"},
				{"type": "loot_drop_multiplier", "value": 0.20, "name": "掉落 +20%"},
				{"type": "move_speed_multiplier", "value": 0.10, "name": "移速 +10%"},
			]
			var buff: Dictionary = pool[randi() % pool.size()] as Dictionary
			if _current_player.has_method("add_tavern_buff"):
				_current_player.add_tavern_buff(str(buff.get("type", "")), float(buff.get("value", 0.0)))
			_set_message("酒館增益：%s" % str(buff.get("name", "")))
		"curse_debuff":
			var curse_pool: Array = [
				{"type": "damage_multiplier", "value": -0.10, "name": "ATK -10%"},
				{"type": "armor_reduction", "value": -0.15, "name": "防禦 -15%"},
				{"type": "move_speed_multiplier", "value": -0.10, "name": "移速 -10%"},
			]
			var curse: Dictionary = curse_pool[randi() % curse_pool.size()] as Dictionary
			if _current_player.has_method("add_tavern_buff"):
				_current_player.add_tavern_buff(str(curse.get("type", "")), float(curse.get("value", 0.0)))
			_set_message("詛咒！%s" % str(curse.get("name", "")))
		_:
			_set_message("禮盒裡什麼都沒有…")


func _trigger_blessing_selection() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	var hud_node: Node = main_scene.get_node_or_null("HUDCanvas/HUD")
	if hud_node == null:
		hud_node = main_scene.get_node_or_null("HUD")
	if hud_node != null and hud_node.has_method("open_blessing_selection"):
		hud_node.open_blessing_selection([], null)


func _on_buy_equipment() -> void:
	if _equipment_offer.is_empty() or _current_player == null:
		return
	var inventory: Variant = _current_player.get("inventory")
	if inventory == null:
		return
	var payment: Dictionary = inventory.get_exact_currency_payment(_equipment_price)
	if payment.is_empty():
		_set_message(LocaleManager.L("insufficient_gold"))
		return
	if inventory.pay_copper(_equipment_price):
		if inventory.add_stack(_equipment_offer):
			_set_message("")
			_equipment_offer.clear()
			_equipment_price = 0
			_update_gold_label()
			_refresh_equipment_offer_row()
		else:
			inventory.refund_currency(payment)
			_set_message(LocaleManager.L("bag_full"))
	else:
		_set_message(LocaleManager.L("insufficient_gold"))


func _refresh_equipment_offer_row() -> void:
	if _equipment_label == null or _equipment_button == null or _equipment_icon == null:
		return
	if _equipment_offer.is_empty():
		_equipment_icon.texture = ITEM_DATABASE.get_equipment_icon("weapon", "Common")
		_equipment_label.text = "%s  %s" % [LocaleManager.L("mystery_equipment"), LocaleManager.L("sold_out")]
		_equipment_label.remove_theme_color_override("font_color")
		_equipment_button.text = LocaleManager.L("sold_button")
		_equipment_button.disabled = true
		return
	_equipment_icon.texture = ITEM_DATABASE.get_stack_icon(_equipment_offer)
	_equipment_label.text = "%s  %s" % [ITEM_DATABASE.get_stack_display_name(_equipment_offer), ITEM_DATABASE.format_currency(_equipment_price)]
	_equipment_label.add_theme_color_override("font_color", DUNGEON_LOOT.get_item_display_color(_equipment_offer))
	_equipment_button.text = LocaleManager.L("buy")
	_equipment_button.disabled = false


func _update_gold_label() -> void:
	if _gold_label == null or _current_player == null:
		return
	var inventory: Variant = _current_player.get("inventory")
	var total: int = 0
	if inventory != null:
		total = inventory.get_total_copper()
	_gold_label.text = LocaleManager.L("gold_label") % total


func _set_message(message: String) -> void:
	if _message_label == null:
		return
	_message_label.text = message


func _make_icon_rect(icon: Texture2D) -> TextureRect:
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = icon
	return icon_rect


func _close_shop() -> void:
	if _shop_canvas != null:
		AudioManager.play_sfx("ui_close")
	if _shop_canvas != null:
		_shop_canvas.queue_free()
		_shop_canvas = null
	_shop_root = null
	get_tree().paused = false
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null
	_gold_label = null
	_message_label = null
	_equipment_icon = null
	_equipment_label = null
	_equipment_button = null
	_detail_icon = null
	_detail_name = null
	_detail_desc = null
	_detail_price = null
	_detail_buy_btn = null
	_detail_placeholder = null
	_item_list_container = null
	_tab_buttons.clear()


func _calculate_equipment_price(_floor_number: int, equipment_offer: Dictionary) -> int:
	var rarity: String = str(equipment_offer.get("rarity", "Common"))
	match rarity:
		"Legendary":
			return 10000
		"Epic", "Rare":
			return 300
		_:
			return 50
