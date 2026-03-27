extends Area2D
class_name Merchant

const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")

const SHOP_ITEMS = [
	{"id": "bandage", "quantity": 1, "price": 5, "label_key": "shop_bandage"},
	{"id": "bread", "quantity": 1, "price": 8, "label_key": "shop_bread"},
	{"id": "seed", "quantity": 3, "price": 3, "label_key": "shop_seed"},
	{"id": "iron_ore", "quantity": 5, "price": 15, "label_key": "shop_iron_ore"},
	{"id": "torch", "quantity": 3, "price": 6, "label_key": "shop_torch"},
]
const EXCHANGE_RECIPES = [
	{"from_id": "copper", "from_amount": 10, "to_id": "silver", "to_amount": 1},
	{"from_id": "silver", "from_amount": 10, "to_id": "gold", "to_amount": 1},
	{"from_id": "silver", "from_amount": 1, "to_id": "copper", "to_amount": 10},
	{"from_id": "gold", "from_amount": 1, "to_id": "silver", "to_amount": 10},
]

var _shop_canvas: CanvasLayer = null
var _shop_root: Control = null
var _current_player: Variant = null
var _gold_label: Label = null
var _message_label: Label = null
var _exchange_buttons: Array[Dictionary] = []


func get_interaction_prompt() -> String:
	return LocaleManager.L("merchant_interact")


func interact(player: Variant) -> void:
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


func _open_shop() -> void:
	_shop_canvas = CanvasLayer.new()
	_shop_canvas.layer = 10
	add_child(_shop_canvas)

	_shop_root = Control.new()
	_shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_canvas.add_child(_shop_root)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_left = -210.0
	panel.offset_top = -250.0
	panel.offset_right = 210.0
	panel.offset_bottom = 250.0
	_shop_root.add_child(panel)

	var x_btn: Button = Button.new()
	x_btn.name = "CloseButton"
	x_btn.text = "X"
	x_btn.custom_minimum_size = Vector2(32, 32)
	x_btn.size = Vector2(32, 32)
	x_btn.position = panel.position + Vector2(8, 8)
	x_btn.z_index = 100
	x_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	x_btn.pressed.connect(_close_shop)
	_shop_root.add_child(x_btn)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = LocaleManager.L("merchant")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for item in SHOP_ITEMS:
		_add_shop_row(
			vbox,
			LocaleManager.L(str(item["label_key"])),
			int(item["price"]),
			_on_buy_item.bind(str(item["id"]), int(item["quantity"]), int(item["price"])),
			ITEM_DATABASE.get_item_icon(str(item["id"]))
		)

	_add_shop_row(vbox, LocaleManager.L("mystery_equipment"), 50, _on_buy_equipment, ITEM_DATABASE.get_default_equipment_icon("weapon"))

	vbox.add_child(HSeparator.new())
	_exchange_buttons.clear()

	var exchange_title: Label = Label.new()
	exchange_title.text = LocaleManager.L("merchant_exchange")
	exchange_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exchange_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(exchange_title)

	for recipe: Dictionary in EXCHANGE_RECIPES:
		_add_exchange_row(
			vbox,
			str(recipe.get("from_id", "")),
			int(recipe.get("from_amount", 0)),
			str(recipe.get("to_id", "")),
			int(recipe.get("to_amount", 0))
		)

	vbox.add_child(HSeparator.new())

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_message_label.text = ""
	vbox.add_child(_message_label)

	var footer: HBoxContainer = HBoxContainer.new()
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_gold_label()
	footer.add_child(_gold_label)
	var close_btn: Button = Button.new()
	close_btn.text = LocaleManager.L("close_button")
	close_btn.pressed.connect(_close_shop)
	footer.add_child(close_btn)
	vbox.add_child(footer)
	_refresh_shop_state()


func _add_shop_row(parent: Control, label_text: String, price: int, callback: Callable, icon: Texture2D = null) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if icon != null:
		row.add_child(_make_icon_rect(icon))
	var lbl: Label = Label.new()
	lbl.text = "%s  %s" % [label_text, ITEM_DATABASE.format_currency(price)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn: Button = Button.new()
	btn.text = LocaleManager.L("buy")
	btn.pressed.connect(callback)
	row.add_child(btn)
	parent.add_child(row)


func _add_exchange_row(parent: Control, from_id: String, from_amount: int, to_id: String, to_amount: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_make_icon_rect(ITEM_DATABASE.get_item_icon(from_id)))
	var label: Label = Label.new()
	label.text = _format_exchange_text(from_id, from_amount, to_id, to_amount)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button: Button = Button.new()
	button.text = LocaleManager.L("exchange_button")
	button.pressed.connect(_on_exchange_currency.bind(from_id, from_amount, to_id, to_amount))
	row.add_child(button)
	parent.add_child(row)
	_exchange_buttons.append({
		"button": button,
		"from_id": from_id,
		"from_amount": from_amount,
	})


func _format_exchange_text(from_id: String, from_amount: int, to_id: String, to_amount: int) -> String:
	return "%d %s -> %d %s" % [
		from_amount,
		ITEM_DATABASE.get_display_name(from_id),
		to_amount,
		ITEM_DATABASE.get_display_name(to_id),
	]


func _on_buy_item(item_id: String, quantity: int, price: int) -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var payment: Dictionary = inv.get_exact_currency_payment(price)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(price):
		if inv.add_item(item_id, quantity):
			_message_label.text = ""
			_refresh_shop_state()
		else:
			inv.refund_currency(payment)
			_message_label.text = LocaleManager.L("bag_full")
	else:
		_message_label.text = LocaleManager.L("insufficient_gold")
	_refresh_shop_state()


func _on_buy_equipment() -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var payment: Dictionary = inv.get_exact_currency_payment(50)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(50):
		var equip: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(randi_range(1, 5))
		if inv.add_stack(equip):
			_message_label.text = ""
			_refresh_shop_state()
		else:
			inv.refund_currency(payment)
			_message_label.text = LocaleManager.L("bag_full")
	else:
		_message_label.text = LocaleManager.L("insufficient_gold")
	_refresh_shop_state()


func _on_exchange_currency(from_id: String, from_amount: int, to_id: String, to_amount: int) -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	if not _can_exchange(inv, from_id, from_amount):
		_message_label.text = LocaleManager.L("insufficient_gold")
		_refresh_shop_state()
		return
	if not inv.remove_item(from_id, from_amount):
		_message_label.text = LocaleManager.L("insufficient_gold")
		_refresh_shop_state()
		return
	if not inv.add_item(to_id, to_amount):
		inv.add_item(from_id, from_amount)
		_message_label.text = LocaleManager.L("bag_full")
		_refresh_shop_state()
		return
	_message_label.text = ""
	_refresh_shop_state()


func _can_exchange(inv: Variant, from_id: String, from_amount: int) -> bool:
	return inv != null and int(inv.get_item_count(from_id)) >= from_amount


func _refresh_shop_state() -> void:
	_update_gold_label()
	_update_exchange_buttons()


func _update_exchange_buttons() -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	for entry: Dictionary in _exchange_buttons:
		var button: Button = entry.get("button", null) as Button
		if button == null:
			continue
		var from_id: String = str(entry.get("from_id", ""))
		var from_amount: int = int(entry.get("from_amount", 0))
		button.disabled = not _can_exchange(inv, from_id, from_amount)


func _update_gold_label() -> void:
	if _gold_label == null or _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	var gold_count: int = 0
	var silver_count: int = 0
	var copper_count: int = 0
	if inv != null:
		gold_count = int(inv.get_item_count("gold"))
		silver_count = int(inv.get_item_count("silver"))
		copper_count = int(inv.get_item_count("copper"))
	_gold_label.text = "%s: %d   %s: %d   %s: %d" % [
		ITEM_DATABASE.get_display_name("gold"),
		gold_count,
		ITEM_DATABASE.get_display_name("silver"),
		silver_count,
		ITEM_DATABASE.get_display_name("copper"),
		copper_count,
	]


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
		_shop_canvas.queue_free()
		_shop_canvas = null
	_shop_root = null
	_exchange_buttons.clear()
	get_tree().paused = false
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null
