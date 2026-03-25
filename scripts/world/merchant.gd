extends Area2D
class_name Merchant

const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")

const SHOP_ITEMS := [
	{"id": "bandage", "quantity": 1, "price": 5, "label": "Bandage"},
	{"id": "bread", "quantity": 1, "price": 8, "label": "Bread"},
	{"id": "seed", "quantity": 3, "price": 3, "label": "Seed x3"},
	{"id": "iron_ore", "quantity": 5, "price": 15, "label": "Iron Ore x5"},
	{"id": "torch", "quantity": 3, "price": 6, "label": "Torch x3"},
]

var _shop_canvas: CanvasLayer = null
var _current_player = null
var _gold_label: Label = null


func get_interaction_prompt() -> String:
	return "[E] 交易"


func interact(player) -> void:
	if _shop_canvas != null:
		return
	_current_player = player
	_open_shop()
	if player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)


func _unhandled_input(event: InputEvent) -> void:
	if _shop_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_shop()
		get_viewport().set_input_as_handled()


func _open_shop() -> void:
	_shop_canvas = CanvasLayer.new()
	_shop_canvas.layer = 10
	add_child(_shop_canvas)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_top = -200.0
	panel.offset_right = 210.0
	panel.offset_bottom = 200.0
	_shop_canvas.add_child(panel)

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
	title.text = "商人"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for item in SHOP_ITEMS:
		_add_shop_row(vbox, str(item["label"]), int(item["price"]),
				_on_buy_item.bind(str(item["id"]), int(item["quantity"]), int(item["price"])))

	_add_shop_row(vbox, "神秘裝備", 50, _on_buy_equipment)

	vbox.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_gold_label()
	footer.add_child(_gold_label)
	var close_btn := Button.new()
	close_btn.text = "關閉 [Esc]"
	close_btn.pressed.connect(_close_shop)
	footer.add_child(close_btn)
	vbox.add_child(footer)


func _add_shop_row(parent: Control, label_text: String, price: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "%s  —  %d 金幣" % [label_text, price]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "購買"
	btn.pressed.connect(callback)
	row.add_child(btn)
	parent.add_child(row)


func _on_buy_item(item_id: String, quantity: int, price: int) -> void:
	if _current_player == null:
		return
	var inv = _current_player.get("inventory")
	if inv == null or not inv.has_item("gold", price):
		return
	if inv.remove_item("gold", price):
		inv.add_item(item_id, quantity)
		_update_gold_label()


func _on_buy_equipment() -> void:
	if _current_player == null:
		return
	var inv = _current_player.get("inventory")
	if inv == null or not inv.has_item("gold", 50):
		return
	if inv.remove_item("gold", 50):
		var equip := DUNGEON_LOOT.generate_dungeon_equipment(randi_range(1, 5))
		inv.add_stack(equip)
		_update_gold_label()


func _update_gold_label() -> void:
	if _gold_label == null or _current_player == null:
		return
	var inv = _current_player.get("inventory")
	var gold_count := 0
	if inv != null:
		gold_count = inv.get_item_count("gold")
	_gold_label.text = "金幣: %d" % gold_count


func _close_shop() -> void:
	if _shop_canvas != null:
		_shop_canvas.queue_free()
		_shop_canvas = null
	if _current_player != null and _current_player.has_method("set_ui_blocked"):
		_current_player.set_ui_blocked(false)
	_current_player = null
