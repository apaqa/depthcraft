extends Area2D
class_name DungeonMerchant

const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const MERCHANT_TEXTURE := preload("res://assets/npc_merchant_2.png")
const SHOP_ITEMS := [
	{"id": "bandage", "quantity": 1, "price": 5},
	{"id": "bread", "quantity": 1, "price": 8},
	{"id": "torch", "quantity": 3, "price": 6},
]

var _shop_canvas: CanvasLayer = null
var _shop_root: Control = null
var _current_player = null
var _gold_label: Label = null
var _message_label: Label = null
var _equipment_label: Label = null
var _equipment_button: Button = null
var _equipment_offer: Dictionary = {}
var _equipment_price: int = 0
var _floor_number: int = 1


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
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = MERCHANT_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color(1.0, 0.92, 0.78, 1.0)
		add_child(sprite)
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 14.0
		collision.shape = shape
		add_child(collision)
	var marker := get_node_or_null("TradeMarker")
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

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_left = -220.0
	panel.offset_top = -190.0
	panel.offset_right = 220.0
	panel.offset_bottom = 190.0
	_shop_root.add_child(panel)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = panel.position + Vector2(8, 8)
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.size = Vector2(32, 32)
	close_button.z_index = 100
	close_button.pressed.connect(_close_shop)
	_shop_root.add_child(close_button)

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
	title.text = LocaleManager.L("boss_merchant_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = LocaleManager.L("boss_merchant_subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.84, 0.84, 0.84, 1.0)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	for item in SHOP_ITEMS:
		_add_item_row(vbox, item)

	vbox.add_child(HSeparator.new())
	_add_equipment_row(vbox)
	vbox.add_child(HSeparator.new())

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
	vbox.add_child(_message_label)

	var footer := HBoxContainer.new()
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_gold_label)
	var footer_close_button := Button.new()
	footer_close_button.text = LocaleManager.L("close_button")
	footer_close_button.pressed.connect(_close_shop)
	footer.add_child(footer_close_button)
	vbox.add_child(footer)

	_update_gold_label()
	_refresh_equipment_offer_row()


func _add_item_row(parent: Control, item_offer: Dictionary) -> void:
	var item_data := ITEM_DATABASE.get_item(str(item_offer.get("id", "")))
	var quantity := int(item_offer.get("quantity", 1))
	var name := str(item_data.get("name", ITEM_DATABASE.get_display_name(str(item_offer.get("id", "")))))
	if quantity > 1:
		name = "%s x%d" % [name, quantity]
	_add_shop_row(parent, name, int(item_offer.get("price", 0)), _on_buy_item.bind(str(item_offer.get("id", "")), quantity, int(item_offer.get("price", 0))))


func _add_equipment_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	_equipment_label = Label.new()
	_equipment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_equipment_label)
	_equipment_button = Button.new()
	_equipment_button.pressed.connect(_on_buy_equipment)
	row.add_child(_equipment_button)
	parent.add_child(row)


func _add_shop_row(parent: Control, label_text: String, price: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s  %s" % [label_text, ITEM_DATABASE.format_currency(price)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = LocaleManager.L("buy")
	button.pressed.connect(callback)
	row.add_child(button)
	parent.add_child(row)


func _on_buy_item(item_id: String, quantity: int, price: int) -> void:
	if _current_player == null:
		return
	var inventory = _current_player.get("inventory")
	if inventory == null:
		return
	if inventory.get_total_copper() < price:
		_set_message(LocaleManager.L("insufficient_gold"))
		return
	if inventory.pay_copper(price):
		if inventory.add_item(item_id, quantity):
			_set_message("")
			_update_gold_label()
		else:
			inventory.add_item("copper", price)
			_set_message(LocaleManager.L("bag_full"))


func _on_buy_equipment() -> void:
	if _equipment_offer.is_empty() or _current_player == null:
		return
	var inventory = _current_player.get("inventory")
	if inventory == null:
		return
	if inventory.get_total_copper() < _equipment_price:
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
			inventory.add_item("copper", _equipment_price)
			_set_message(LocaleManager.L("bag_full"))


func _refresh_equipment_offer_row() -> void:
	if _equipment_label == null or _equipment_button == null:
		return
	if _equipment_offer.is_empty():
		_equipment_label.text = "%s  %s" % [LocaleManager.L("mystery_equipment"), LocaleManager.L("sold_out")]
		_equipment_label.remove_theme_color_override("font_color")
		_equipment_button.text = LocaleManager.L("sold_button")
		_equipment_button.disabled = true
		return
	_equipment_label.text = "%s  %s" % [ITEM_DATABASE.get_stack_display_name(_equipment_offer), ITEM_DATABASE.format_currency(_equipment_price)]
	_equipment_label.add_theme_color_override("font_color", DUNGEON_LOOT.get_item_display_color(_equipment_offer))
	_equipment_button.text = LocaleManager.L("buy")
	_equipment_button.disabled = false


func _update_gold_label() -> void:
	if _gold_label == null or _current_player == null:
		return
	var inventory = _current_player.get("inventory")
	var total := 0
	if inventory != null:
		total = inventory.get_total_copper()
	_gold_label.text = LocaleManager.L("gold_label") % total


func _set_message(message: String) -> void:
	if _message_label == null:
		return
	_message_label.text = message


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
	_gold_label = null
	_message_label = null
	_equipment_label = null
	_equipment_button = null


func _calculate_equipment_price(floor_number: int, equipment_offer: Dictionary) -> int:
	var affix_count := (equipment_offer.get("affixes", []) as Array).size()
	return clampi(30 + floor_number * 4 + affix_count * 12, 42, 180)
