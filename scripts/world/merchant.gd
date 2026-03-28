extends Area2D
class_name Merchant

const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")
const UI_AUDIO_CLICK_HOOK = preload("res://scripts/ui/ui_audio_click_hook.gd")

const SHOP_ITEMS = [
	{"id": "bandage", "quantity": 1, "price": 5, "label_key": "shop_bandage"},
	{"id": "bread", "quantity": 1, "price": 8, "label_key": "shop_bread"},
	{"id": "seed", "quantity": 3, "price": 3, "label_key": "shop_seed"},
	{"id": "iron_ore", "quantity": 5, "price": 15, "label_key": "shop_iron_ore"},
	{"id": "torch", "quantity": 3, "price": 6, "label_key": "shop_torch"},
]
const BASE_STOCKS: Dictionary = {
	"bandage": 3,
	"bread": 2,
	"seed": 2,
	"iron_ore": 2,
	"torch": 2,
	"mystery_equipment": 1,
}
const EXCHANGE_RECIPES = [
	{"from_id": "copper", "from_amount": 10, "to_id": "silver", "to_amount": 1},
	{"from_id": "silver", "from_amount": 10, "to_id": "gold", "to_amount": 1},
	{"from_id": "silver", "from_amount": 1, "to_id": "copper", "to_amount": 10},
	{"from_id": "gold", "from_amount": 1, "to_id": "silver", "to_amount": 10},
]

const SELL_PRICES: Dictionary = {
	"common": {"currency": "copper", "amount": 5},
	"uncommon": {"currency": "copper", "amount": 15},
	"rare": {"currency": "silver", "amount": 1},
	"epic": {"currency": "silver", "amount": 3},
	"legendary": {"currency": "gold", "amount": 1},
}

var _shop_canvas: CanvasLayer = null
var _shop_root: Control = null
var _current_player: Variant = null
var _gold_label: Label = null
var _message_label: Label = null
var _exchange_buttons: Array[Dictionary] = []
var _shop_buttons: Array[Dictionary] = []
var _sell_buttons: Array[Dictionary] = []
var _remaining_stock: Dictionary = {}
var _stock_day: int = -1
var _stock_bonus_applied: int = 0
var _current_tab: String = "buy"
var _tab_buttons: Dictionary = {}
var _tab_content_nodes: Dictionary = {}
var _sell_list_container: VBoxContainer = null


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
	_initialize_shop_stock()
	_shop_canvas = CanvasLayer.new()
	_shop_canvas.layer = 10
	add_child(_shop_canvas)

	_shop_root = Control.new()
	_shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_canvas.add_child(_shop_root)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.1
	panel.anchor_top = 0.5
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.5
	panel.offset_left = 0.0
	panel.offset_top = -260.0
	panel.offset_right = 0.0
	panel.offset_bottom = 260.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", panel_style)
	_shop_root.add_child(panel)

	var x_btn: Button = Button.new()
	x_btn.name = "CloseButton"
	x_btn.text = "X"
	x_btn.custom_minimum_size = Vector2(32, 32)
	x_btn.size = Vector2(32, 32)
	x_btn.position = Vector2(8.0, 8.0)
	x_btn.z_index = 100
	x_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	x_btn.pressed.connect(_close_shop)
	panel.add_child(x_btn)

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
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	_tab_buttons.clear()
	_tab_content_nodes.clear()
	_build_tab_button(tab_bar, "buy", LocaleManager.L("buy"))
	_build_tab_button(tab_bar, "sell", LocaleManager.L("sell"))
	_build_tab_button(tab_bar, "exchange", LocaleManager.L("exchange_button"))

	vbox.add_child(HSeparator.new())

	var content_area: Control = Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(content_area)

	var buy_scroll: ScrollContainer = ScrollContainer.new()
	buy_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(buy_scroll)
	_tab_content_nodes["buy"] = buy_scroll

	var shop_list: VBoxContainer = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	buy_scroll.add_child(shop_list)

	_shop_buttons.clear()
	for item: Dictionary in SHOP_ITEMS:
		var item_id: String = str(item.get("id", ""))
		var item_quantity: int = int(item.get("quantity", 1))
		var adjusted_price: int = _get_adjusted_price(int(item.get("price", 0)))
		_add_shop_row(
			shop_list,
			item_id,
			LocaleManager.L(str(item["label_key"])),
			adjusted_price,
			_on_buy_item.bind(item_id, item_quantity, adjusted_price),
			ITEM_DATABASE.get_item_icon(str(item["id"]))
		)
	_add_shop_row(
		shop_list,
		"mystery_equipment",
		LocaleManager.L("mystery_equipment"),
		_get_adjusted_price(50),
		_on_buy_equipment,
		ITEM_DATABASE.get_equipment_icon("weapon", "Common")
	)

	var sell_scroll: ScrollContainer = ScrollContainer.new()
	sell_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sell_scroll.visible = false
	content_area.add_child(sell_scroll)
	_tab_content_nodes["sell"] = sell_scroll

	_sell_list_container = VBoxContainer.new()
	_sell_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_list_container.add_theme_constant_override("separation", 6)
	sell_scroll.add_child(_sell_list_container)

	var exchange_scroll: ScrollContainer = ScrollContainer.new()
	exchange_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	exchange_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	exchange_scroll.visible = false
	content_area.add_child(exchange_scroll)
	_tab_content_nodes["exchange"] = exchange_scroll

	var exchange_list: VBoxContainer = VBoxContainer.new()
	exchange_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exchange_list.add_theme_constant_override("separation", 6)
	exchange_scroll.add_child(exchange_list)

	_exchange_buttons.clear()
	for recipe: Dictionary in EXCHANGE_RECIPES:
		_add_exchange_row(
			exchange_list,
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

	_current_tab = "buy"
	_switch_tab("buy")
	_refresh_shop_state()
	UI_AUDIO_CLICK_HOOK.attach(_shop_root)
	AudioManager.play_sfx("ui_open")


func refresh_inventory_state() -> void:
	if _shop_canvas == null:
		return
	_initialize_shop_stock()
	_refresh_shop_state()


func _add_shop_row(parent: Control, stock_key: String, label_text: String, price: int, callback: Callable, icon: Texture2D = null) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if icon != null:
		row.add_child(_make_icon_rect(icon))
	var lbl: Label = Label.new()
	lbl.text = _format_shop_row_text(label_text, price, stock_key)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn: Button = Button.new()
	btn.text = LocaleManager.L("buy")
	btn.pressed.connect(callback)
	row.add_child(btn)
	parent.add_child(row)
	_shop_buttons.append({
		"button": btn,
		"label": lbl,
		"stock_key": stock_key,
		"label_text": label_text,
		"price": price,
	})


func _add_exchange_row(parent: Control, from_id: String, from_amount: int, to_id: String, to_amount: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var from_icon: Texture2D = _get_exchange_icon(from_id, from_amount)
	if from_icon != null:
		row.add_child(_make_icon_rect(from_icon))
	var arrow_label: Label = Label.new()
	arrow_label.text = "->"
	row.add_child(arrow_label)
	var to_icon: Texture2D = _get_exchange_icon(to_id, to_amount)
	if to_icon != null:
		row.add_child(_make_icon_rect(to_icon))
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


func _get_exchange_icon(item_id: String, amount: int) -> Texture2D:
	if item_id == "copper" and amount >= 10:
		return preload("res://assets/icons/kyrise/coin_02b.png")
	return ITEM_DATABASE.get_item_icon(item_id)


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
	if not _has_stock(item_id):
		_message_label.text = LocaleManager.L("sold_out")
		_refresh_shop_state()
		return
	var payment: Dictionary = inv.get_exact_currency_payment(price)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(price):
		if inv.add_item(item_id, quantity):
			_consume_stock(item_id)
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
	if not _has_stock("mystery_equipment"):
		_message_label.text = LocaleManager.L("sold_out")
		_refresh_shop_state()
		return
	var equipment_price: int = _get_adjusted_price(50)
	var payment: Dictionary = inv.get_exact_currency_payment(equipment_price)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(equipment_price):
		var equip: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(randi_range(1, 5))
		if inv.add_stack(equip):
			_consume_stock("mystery_equipment")
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
	_update_shop_buttons()
	if _current_tab == "sell":
		_refresh_sell_list()


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


func _update_shop_buttons() -> void:
	for entry: Dictionary in _shop_buttons:
		var button: Button = entry.get("button", null) as Button
		var label: Label = entry.get("label", null) as Label
		var stock_key: String = str(entry.get("stock_key", ""))
		var label_text: String = str(entry.get("label_text", ""))
		var price: int = int(entry.get("price", 0))
		var in_stock: bool = _has_stock(stock_key)
		if button != null:
			button.disabled = not in_stock
			button.text = LocaleManager.L("buy") if in_stock else LocaleManager.L("sold_out")
		if label != null:
			label.text = _format_shop_row_text(label_text, price, stock_key)


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
		AudioManager.play_sfx("ui_close")
	if _shop_canvas != null:
		_shop_canvas.queue_free()
		_shop_canvas = null
	_shop_root = null
	_exchange_buttons.clear()
	_shop_buttons.clear()
	_sell_buttons.clear()
	_tab_buttons.clear()
	_tab_content_nodes.clear()
	_sell_list_container = null
	get_tree().paused = false
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null


func _initialize_shop_stock() -> void:
	var stock_bonus: int = NpcManager.get_merchant_stock_bonus() if NpcManager != null else 0
	var target_day: int = NpcManager.current_day if NpcManager != null else 0
	if _stock_day == target_day and not _remaining_stock.is_empty():
		if stock_bonus > _stock_bonus_applied:
			var stock_delta: int = stock_bonus - _stock_bonus_applied
			for stock_key_variant: Variant in BASE_STOCKS.keys():
				var stock_key: String = str(stock_key_variant)
				_remaining_stock[stock_key] = int(_remaining_stock.get(stock_key, 0)) + stock_delta
			_stock_bonus_applied = stock_bonus
		return
	_remaining_stock.clear()
	for stock_key_variant: Variant in BASE_STOCKS.keys():
		var stock_key: String = str(stock_key_variant)
		_remaining_stock[stock_key] = int(BASE_STOCKS.get(stock_key_variant, 0)) + stock_bonus
	_stock_day = target_day
	_stock_bonus_applied = stock_bonus


func _get_adjusted_price(base_price: int) -> int:
	var price_multiplier: float = NpcManager.get_merchant_price_multiplier() if NpcManager != null else 1.0
	return maxi(int(floor(float(base_price) * price_multiplier)), 1)


func _has_stock(stock_key: String) -> bool:
	return int(_remaining_stock.get(stock_key, 0)) > 0


func _consume_stock(stock_key: String) -> void:
	_remaining_stock[stock_key] = maxi(int(_remaining_stock.get(stock_key, 0)) - 1, 0)


func _format_shop_row_text(label_text: String, price: int, stock_key: String) -> String:
	var stock_left: int = int(_remaining_stock.get(stock_key, 0))
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "%s  %s  [剩餘 %d]" % [label_text, ITEM_DATABASE.format_currency(price), stock_left]
	return "%s  %s  [%d left]" % [label_text, ITEM_DATABASE.format_currency(price), stock_left]


func _build_tab_button(parent: HBoxContainer, tab_id: String, label_text: String) -> void:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.toggle_mode = true
	btn.pressed.connect(_switch_tab.bind(tab_id))
	parent.add_child(btn)
	_tab_buttons[tab_id] = btn


func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for key: Variant in _tab_content_nodes.keys():
		var node: Control = _tab_content_nodes[key] as Control
		if node != null:
			node.visible = (str(key) == tab_id)
	for key: Variant in _tab_buttons.keys():
		var btn: Button = _tab_buttons[key] as Button
		if btn != null:
			btn.button_pressed = (str(key) == tab_id)
	if _message_label != null:
		_message_label.text = ""
	if tab_id == "sell":
		_refresh_sell_list()


func _refresh_sell_list() -> void:
	if _sell_list_container == null:
		return
	while _sell_list_container.get_child_count() > 0:
		var child: Node = _sell_list_container.get_child(0)
		_sell_list_container.remove_child(child)
		child.queue_free()
	_sell_buttons.clear()
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var found_any: bool = false
	for i: int in range(inv.items.size()):
		var stack: Dictionary = inv.items[i]
		if not _is_sellable(stack):
			continue
		_add_sell_row(_sell_list_container, i, stack)
		found_any = true
	if not found_any:
		var empty_label: Label = Label.new()
		empty_label.text = "（無可出售物品）"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sell_list_container.add_child(empty_label)


func _add_sell_row(parent: VBoxContainer, stack_index: int, stack: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	if icon != null:
		row.add_child(_make_icon_rect(icon))
	var name_label: Label = Label.new()
	var qty: int = int(stack.get("quantity", 1))
	name_label.text = ITEM_DATABASE.get_stack_display_name(stack)
	if qty > 1:
		name_label.text += " x%d" % qty
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var price_info: Dictionary = _get_sell_price(stack)
	var price_copper: int = _sell_price_to_copper(price_info, qty)
	var price_label: Label = Label.new()
	price_label.text = ITEM_DATABASE.format_currency(price_copper)
	row.add_child(price_label)
	var btn: Button = Button.new()
	btn.text = LocaleManager.L("sell")
	btn.pressed.connect(_on_sell_item.bind(stack_index))
	row.add_child(btn)
	parent.add_child(row)
	_sell_buttons.append({"button": btn, "stack_index": stack_index})


func _on_sell_item(stack_index: int) -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	if stack_index < 0 or stack_index >= inv.items.size():
		_refresh_sell_list()
		return
	var stack: Dictionary = inv.items[stack_index]
	if not _is_sellable(stack):
		_refresh_sell_list()
		return
	var price_info: Dictionary = _get_sell_price(stack)
	var qty: int = int(stack.get("quantity", 1))
	var currency: String = str(price_info.get("currency", "copper"))
	var amount_per: int = int(price_info.get("amount", 1))
	inv.items.remove_at(stack_index)
	inv.inventory_changed.emit()
	inv.add_item(currency, amount_per * qty)
	if _message_label != null:
		_message_label.text = ""
	_refresh_shop_state()


func _is_sellable(stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var item_id: String = str(stack.get("id", ""))
	if item_id == "copper" or item_id == "silver" or item_id == "gold":
		return false
	return true


func _get_sell_price(stack: Dictionary) -> Dictionary:
	var rarity: String = str(stack.get("rarity", "")).to_lower()
	if rarity != "" and SELL_PRICES.has(rarity):
		return (SELL_PRICES[rarity] as Dictionary).duplicate()
	return {"currency": "copper", "amount": 1}


func _sell_price_to_copper(price_info: Dictionary, qty: int) -> int:
	var currency: String = str(price_info.get("currency", "copper"))
	var amount: int = int(price_info.get("amount", 1))
	var total_currency: int = amount * qty
	match currency:
		"gold":
			return total_currency * 100
		"silver":
			return total_currency * 10
		_:
			return total_currency
