extends Area2D
class_name Merchant

const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

const SHOP_ITEMS := [
	{"id": "bandage", "quantity": 1, "price": 5, "label_key": "shop_bandage"},
	{"id": "bread", "quantity": 1, "price": 8, "label_key": "shop_bread"},
	{"id": "seed", "quantity": 3, "price": 3, "label_key": "shop_seed"},
	{"id": "iron_ore", "quantity": 5, "price": 15, "label_key": "shop_iron_ore"},
	{"id": "torch", "quantity": 3, "price": 6, "label_key": "shop_torch"},
]

var _shop_canvas: CanvasLayer = null
var _shop_root: Control = null
var _current_player = null
var _gold_label: Label = null
var _message_label: Label = null


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


func _open_shop() -> void:
	_shop_canvas = CanvasLayer.new()
	_shop_canvas.layer = 10
	add_child(_shop_canvas)

	_shop_root = Control.new()
	_shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_canvas.add_child(_shop_root)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_left = -210.0
	panel.offset_top = -200.0
	panel.offset_right = 210.0
	panel.offset_bottom = 200.0
	_shop_root.add_child(panel)

	var x_btn = Button.new()
	x_btn.name = "CloseButton"
	x_btn.text = "X"
	x_btn.custom_minimum_size = Vector2(32, 32)
	x_btn.size = Vector2(32, 32)
	x_btn.position = panel.position + Vector2(8, 8)
	x_btn.z_index = 100
	x_btn.pressed.connect(_close_shop)
	_shop_root.add_child(x_btn)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = LocaleManager.L("merchant")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for item in SHOP_ITEMS:
		_add_shop_row(vbox, LocaleManager.L(str(item["label_key"])), int(item["price"]),
				_on_buy_item.bind(str(item["id"]), int(item["quantity"]), int(item["price"])))

	_add_shop_row(vbox, LocaleManager.L("mystery_equipment"), 50, _on_buy_equipment)

	vbox.add_child(HSeparator.new())

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_message_label.text = ""
	vbox.add_child(_message_label)

	var footer := HBoxContainer.new()
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_gold_label()
	footer.add_child(_gold_label)
	var close_btn := Button.new()
	close_btn.text = LocaleManager.L("close_button")
	close_btn.pressed.connect(_close_shop)
	footer.add_child(close_btn)
	vbox.add_child(footer)


func _add_shop_row(parent: Control, label_text: String, price: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "%s  %s" % [label_text, ITEM_DATABASE.format_currency(price)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = LocaleManager.L("buy")
	btn.pressed.connect(callback)
	row.add_child(btn)
	parent.add_child(row)


func _on_buy_item(item_id: String, quantity: int, price: int) -> void:
	if _current_player == null:
		return
	var inv = _current_player.get("inventory")
	if inv == null:
		return
	var payment := inv.get_exact_currency_payment(price)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(price):
		if inv.add_item(item_id, quantity):
			_message_label.text = ""
			_update_gold_label()
		else:
			inv.refund_currency(payment)
			_message_label.text = LocaleManager.L("bag_full")
	else:
		_message_label.text = LocaleManager.L("insufficient_gold")


func _on_buy_equipment() -> void:
	if _current_player == null:
		return
	var inv = _current_player.get("inventory")
	if inv == null:
		return
	var payment := inv.get_exact_currency_payment(50)
	if payment.is_empty():
		_message_label.text = LocaleManager.L("insufficient_gold")
		return
	if inv.pay_copper(50):
		var equip := DUNGEON_LOOT.generate_dungeon_equipment(randi_range(1, 5))
		if inv.add_stack(equip):
			_message_label.text = ""
			_update_gold_label()
		else:
			inv.refund_currency(payment)
			_message_label.text = LocaleManager.L("bag_full")
	else:
		_message_label.text = LocaleManager.L("insufficient_gold")


func _update_gold_label() -> void:
	if _gold_label == null or _current_player == null:
		return
	var inv = _current_player.get("inventory")
	var total := 0
	if inv != null:
		total = inv.get_total_copper()
	_gold_label.text = LocaleManager.L("gold_label") % total


func _close_shop() -> void:
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
