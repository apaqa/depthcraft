extends Area2D
class_name BartenderNpc

const UI_AUDIO_CLICK_HOOK = preload("res://scripts/ui/ui_audio_click_hook.gd")

const DRINKS: Array[Dictionary] = [
	{
		"id": "firewater",
		"name": "烈酒",
		"desc": "ATK +15%，持續本局",
		"price": 20,
		"buff_type": "damage_multiplier",
		"buff_value": 0.15,
		"color": Color(0.9, 0.35, 0.1, 1.0),
	},
	{
		"id": "shield_brew",
		"name": "護盾釀",
		"desc": "傷害減免 +20%，持續本局",
		"price": 20,
		"buff_type": "armor_reduction",
		"buff_value": 0.20,
		"color": Color(0.3, 0.6, 1.0, 1.0),
	},
	{
		"id": "lucky_drink",
		"name": "幸運酒",
		"desc": "掉落倍率 +25%，持續本局",
		"price": 15,
		"buff_type": "loot_drop_multiplier",
		"buff_value": 0.25,
		"color": Color(0.9, 0.75, 0.2, 1.0),
	},
	{
		"id": "speed_elixir",
		"name": "疾風靈",
		"desc": "移速 +15%，持續本局",
		"price": 15,
		"buff_type": "move_speed_multiplier",
		"buff_value": 0.15,
		"color": Color(0.4, 0.9, 0.5, 1.0),
	},
	{
		"id": "holy_water",
		"name": "聖水",
		"desc": "立即觸發一次祝福選擇",
		"price": 50,
		"buff_type": "free_blessing",
		"buff_value": 1.0,
		"color": Color(0.85, 0.85, 1.0, 1.0),
	},
]

const GEM_ICON_GREEN: Texture2D = preload("res://assets/icons/gem_01a.png")
const GEM_ICON_BLUE: Texture2D = preload("res://assets/icons/gem_01c.png")
const GEM_ICON_PURPLE: Texture2D = preload("res://assets/icons/gem_01i.png")
const GEM_ICON_RED: Texture2D = preload("res://assets/icons/gem_01d.png")

const GEM_EXCHANGE_RATES: Dictionary = {
	"gem_green": {"currency": "copper", "amount": 5},
	"gem_blue": {"currency": "silver", "amount": 1},
	"gem_purple": {"currency": "silver", "amount": 10},
	"gem_red": {"currency": "gold", "amount": 1},
}

var _canvas: CanvasLayer = null
var _current_player: Variant = null
var _refresh_count: int = 0
var _purchased_ids: Array[String] = []
var _btn_nodes: Array[Button] = []
var _balance_label: Label = null
var _detail_label: Label = null
var _active_tab: int = 0
var _drinks_panel: VBoxContainer = null
var _exchange_panel: VBoxContainer = null
var _tab_btn_drinks: Button = null
var _tab_btn_exchange: Button = null
var _gem_sliders: Dictionary = {}
var _gem_count_labels: Dictionary = {}


func _ready() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		add_child(col)


func get_interaction_prompt() -> String:
	return "[E] 酒保"


func interact(player: Variant) -> void:
	if _canvas != null:
		return
	_current_player = player
	_open_ui()
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	if "in_menu" in player:
		player.in_menu = true
	get_tree().paused = true


func _open_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320.0
	panel.offset_top = -240.0
	panel.offset_right = 320.0
	panel.offset_bottom = 240.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.05, 0.97)
	style.border_color = Color(0.55, 0.35, 0.15, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "酒保"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.85, 0.5, 1.0)
	vbox.add_child(title)

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 13)
	_balance_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	_balance_label.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(_balance_label)
	_refresh_balance()

	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	vbox.add_child(tab_row)

	_tab_btn_drinks = Button.new()
	_tab_btn_drinks.text = "調酒"
	_tab_btn_drinks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_btn_drinks.custom_minimum_size = Vector2(0, 28)
	_tab_btn_drinks.process_mode = Node.PROCESS_MODE_ALWAYS
	_tab_btn_drinks.pressed.connect(_on_tab_switched.bind(0))
	tab_row.add_child(_tab_btn_drinks)

	_tab_btn_exchange = Button.new()
	_tab_btn_exchange.text = "碎片兌換"
	_tab_btn_exchange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_btn_exchange.custom_minimum_size = Vector2(0, 28)
	_tab_btn_exchange.process_mode = Node.PROCESS_MODE_ALWAYS
	_tab_btn_exchange.pressed.connect(_on_tab_switched.bind(1))
	tab_row.add_child(_tab_btn_exchange)

	vbox.add_child(HSeparator.new())

	_drinks_panel = VBoxContainer.new()
	_drinks_panel.add_theme_constant_override("separation", 6)
	_drinks_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_drinks_panel)
	_build_drinks_tab(_drinks_panel)

	_exchange_panel = VBoxContainer.new()
	_exchange_panel.add_theme_constant_override("separation", 8)
	_exchange_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_exchange_panel.visible = false
	vbox.add_child(_exchange_panel)
	_build_exchange_tab(_exchange_panel)

	_update_tab_visuals()
	UI_AUDIO_CLICK_HOOK.attach(_canvas)
	AudioManager.play_sfx("ui_open")


func _on_tab_switched(tab_idx: int) -> void:
	_active_tab = tab_idx
	if _drinks_panel != null:
		_drinks_panel.visible = (tab_idx == 0)
	if _exchange_panel != null:
		_exchange_panel.visible = (tab_idx == 1)
	if tab_idx == 1:
		_refresh_exchange_rows()
	_update_tab_visuals()


func _update_tab_visuals() -> void:
	if _tab_btn_drinks == null or _tab_btn_exchange == null:
		return
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.18, 0.10, 1.0)
	active_style.border_color = Color(0.7, 0.5, 0.2, 1.0)
	active_style.border_width_left = 1
	active_style.border_width_top = 1
	active_style.border_width_right = 1
	active_style.border_width_bottom = 2
	var inactive_style: StyleBoxFlat = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.12, 0.09, 0.06, 1.0)
	inactive_style.border_color = Color(0.35, 0.25, 0.12, 1.0)
	inactive_style.border_width_left = 1
	inactive_style.border_width_top = 1
	inactive_style.border_width_right = 1
	inactive_style.border_width_bottom = 1
	if _active_tab == 0:
		_tab_btn_drinks.add_theme_stylebox_override("normal", active_style)
		_tab_btn_exchange.add_theme_stylebox_override("normal", inactive_style)
	else:
		_tab_btn_drinks.add_theme_stylebox_override("normal", inactive_style)
		_tab_btn_exchange.add_theme_stylebox_override("normal", active_style)


func _build_drinks_tab(parent: VBoxContainer) -> void:
	var drink_list: VBoxContainer = VBoxContainer.new()
	drink_list.add_theme_constant_override("separation", 6)
	parent.add_child(drink_list)

	_btn_nodes.clear()
	for drink: Dictionary in DRINKS:
		var btn: Button = _build_drink_button(drink)
		_btn_nodes.append(btn)
		drink_list.add_child(btn)

	_detail_label = Label.new()
	_detail_label.text = "將滑鼠移到飲品上查看詳情"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(0, 28)
	_detail_label.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(_detail_label)

	parent.add_child(HSeparator.new())

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)

	var refresh_btn: Button = Button.new()
	refresh_btn.text = "刷新飲品 (-%d 銅)" % _get_refresh_cost()
	refresh_btn.custom_minimum_size = Vector2(140, 30)
	refresh_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_btn.name = "RefreshBtn"
	refresh_btn.pressed.connect(_on_refresh_pressed.bind(refresh_btn))
	footer.add_child(refresh_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var close_btn: Button = Button.new()
	close_btn.text = "關閉"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_ui)
	footer.add_child(close_btn)

	parent.add_child(footer)


func _build_exchange_tab(parent: VBoxContainer) -> void:
	var header: Label = Label.new()
	header.text = "寶石 → 貨幣兌換"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(0.9, 0.85, 0.6, 1.0)
	parent.add_child(header)

	var gem_order: Array[String] = ["gem_green", "gem_blue", "gem_purple", "gem_red"]
	for gem_id: String in gem_order:
		_build_gem_exchange_row(gem_id, parent)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

	parent.add_child(HSeparator.new())

	var footer: HBoxContainer = HBoxContainer.new()
	var fspc: Control = Control.new()
	fspc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fspc)
	var close_btn: Button = Button.new()
	close_btn.text = "關閉"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_ui)
	footer.add_child(close_btn)
	parent.add_child(footer)


func _build_gem_exchange_row(gem_id: String, container: VBoxContainer) -> void:
	var rate: Dictionary = GEM_EXCHANGE_RATES.get(gem_id, {}) as Dictionary
	if rate.is_empty():
		return
	var currency: String = str(rate.get("currency", "copper"))
	var amount: int = int(rate.get("amount", 0))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	match gem_id:
		"gem_green":
			icon_rect.texture = GEM_ICON_GREEN
		"gem_blue":
			icon_rect.texture = GEM_ICON_BLUE
		"gem_purple":
			icon_rect.texture = GEM_ICON_PURPLE
		"gem_red":
			icon_rect.texture = GEM_ICON_RED
	row.add_child(icon_rect)

	var gem_names: Dictionary = {
		"gem_green": "綠色寶石",
		"gem_blue": "藍色寶石",
		"gem_purple": "紫色寶石",
		"gem_red": "紅色寶石",
	}
	var gem_colors: Dictionary = {
		"gem_green": Color(0.3, 0.85, 0.3, 1.0),
		"gem_blue": Color(0.3, 0.55, 1.0, 1.0),
		"gem_purple": Color(0.65, 0.3, 0.9, 1.0),
		"gem_red": Color(0.9, 0.2, 0.2, 1.0),
	}
	var name_lbl: Label = Label.new()
	name_lbl.text = str(gem_names.get(gem_id, gem_id))
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.modulate = gem_colors.get(gem_id, Color(1.0, 1.0, 1.0, 1.0)) as Color
	row.add_child(name_lbl)

	var inv: Variant = null
	if _current_player != null:
		inv = _current_player.get("inventory")
	var owned: int = 0
	if inv != null and inv.has_method("get_item_count"):
		owned = int(inv.get_item_count(gem_id))

	var count_lbl: Label = Label.new()
	count_lbl.text = "擁有: %d" % owned
	count_lbl.custom_minimum_size = Vector2(72, 0)
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.modulate = Color(0.75, 0.75, 0.75, 1.0)
	row.add_child(count_lbl)
	_gem_count_labels[gem_id] = count_lbl

	var spin: SpinBox = SpinBox.new()
	spin.min_value = 0
	spin.max_value = float(owned)
	spin.step = 1
	spin.value = 0
	spin.custom_minimum_size = Vector2(72, 0)
	spin.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(spin)
	_gem_sliders[gem_id] = spin

	var rate_lbl: Label = Label.new()
	rate_lbl.text = "→ %s 各" % _currency_short(currency, amount)
	rate_lbl.custom_minimum_size = Vector2(88, 0)
	rate_lbl.add_theme_font_size_override("font_size", 12)
	rate_lbl.modulate = Color(0.8, 0.8, 0.5, 1.0)
	row.add_child(rate_lbl)

	var xbtn: Button = Button.new()
	xbtn.text = "兌換"
	xbtn.custom_minimum_size = Vector2(58, 26)
	xbtn.process_mode = Node.PROCESS_MODE_ALWAYS
	xbtn.disabled = (owned == 0)
	if gem_id == "gem_red":
		xbtn.modulate = Color(1.0, 0.5, 0.35, 1.0)
	xbtn.pressed.connect(_on_exchange_pressed.bind(gem_id))
	row.add_child(xbtn)


func _currency_short(currency: String, amount: int) -> String:
	match currency:
		"copper":
			return "%d 銅" % amount
		"silver":
			return "%d 銀" % amount
		"gold":
			return "%d 金" % amount
		_:
			return "%d %s" % [amount, currency]


func _on_exchange_pressed(gem_id: String) -> void:
	var spin_node: Variant = _gem_sliders.get(gem_id)
	if spin_node == null:
		return
	var qty: int = int((spin_node as SpinBox).value)
	if qty <= 0:
		if _current_player != null and _current_player.has_method("show_status_message"):
			_current_player.show_status_message("請先設定數量", Color(1.0, 0.8, 0.3, 1.0), 1.5)
		return
	if gem_id == "gem_red":
		_show_red_gem_confirm(qty)
		return
	_do_exchange(gem_id, qty)


func _show_red_gem_confirm(qty: int) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(overlay)

	var dialog: Panel = Panel.new()
	dialog.anchor_left = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -190.0
	dialog.offset_top = -85.0
	dialog.offset_right = 190.0
	dialog.offset_bottom = 85.0
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dstyle: StyleBoxFlat = StyleBoxFlat.new()
	dstyle.bg_color = Color(0.15, 0.05, 0.05, 0.98)
	dstyle.border_color = Color(0.9, 0.2, 0.2, 1.0)
	dstyle.border_width_left = 2
	dstyle.border_width_top = 2
	dstyle.border_width_right = 2
	dstyle.border_width_bottom = 2
	dstyle.corner_radius_top_left = 6
	dstyle.corner_radius_top_right = 6
	dstyle.corner_radius_bottom_left = 6
	dstyle.corner_radius_bottom_right = 6
	dialog.add_theme_stylebox_override("panel", dstyle)
	_canvas.add_child(dialog)

	var dm: MarginContainer = MarginContainer.new()
	dm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dm.add_theme_constant_override("margin_left", 16)
	dm.add_theme_constant_override("margin_right", 16)
	dm.add_theme_constant_override("margin_top", 14)
	dm.add_theme_constant_override("margin_bottom", 14)
	dialog.add_child(dm)

	var dv: VBoxContainer = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	dm.add_child(dv)

	var warn_lbl: Label = Label.new()
	warn_lbl.text = "確認兌換紅色寶石？"
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.add_theme_font_size_override("font_size", 15)
	warn_lbl.modulate = Color(1.0, 0.35, 0.2, 1.0)
	dv.add_child(warn_lbl)

	var msg_lbl: Label = Label.new()
	msg_lbl.text = "紅色寶石極為稀有，確定要兌換 %d 個嗎？" % qty
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 12)
	msg_lbl.modulate = Color(0.9, 0.75, 0.5, 1.0)
	dv.add_child(msg_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_child(btn_row)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	cancel_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		dialog.queue_free()
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "確認兌換"
	confirm_btn.custom_minimum_size = Vector2(90, 30)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.modulate = Color(1.0, 0.4, 0.3, 1.0)
	confirm_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		dialog.queue_free()
		_do_exchange("gem_red", qty)
	)
	btn_row.add_child(confirm_btn)


func _do_exchange(gem_id: String, qty: int) -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var rate: Dictionary = GEM_EXCHANGE_RATES.get(gem_id, {}) as Dictionary
	if rate.is_empty():
		return
	var currency: String = str(rate.get("currency", "copper"))
	var amount: int = int(rate.get("amount", 0))
	var owned: int = int(inv.get_item_count(gem_id))
	var actual_qty: int = mini(qty, owned)
	if actual_qty <= 0:
		return
	if not inv.remove_item(gem_id, actual_qty):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("兌換失敗", Color(1.0, 0.4, 0.4, 1.0), 1.5)
		return
	var total: int = actual_qty * amount
	inv.add_item(currency, total)
	if _current_player.has_method("show_status_message"):
		_current_player.show_status_message(
			"兌換成功！+%s" % _currency_short(currency, total),
			Color(0.6, 1.0, 0.7, 1.0), 2.0
		)
	AudioManager.play_sfx("equip")
	_refresh_balance()
	_refresh_exchange_rows()


func _refresh_exchange_rows() -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	for gem_id: String in _gem_count_labels.keys():
		var owned: int = int(inv.get_item_count(gem_id))
		var clbl: Variant = _gem_count_labels.get(gem_id)
		if clbl != null:
			(clbl as Label).text = "擁有: %d" % owned
		var spin_node: Variant = _gem_sliders.get(gem_id)
		if spin_node != null:
			var spin: SpinBox = spin_node as SpinBox
			spin.max_value = float(owned)
			if spin.value > float(owned):
				spin.value = float(owned)


func _build_drink_button(drink: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 40)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var drink_id: String = str(drink.get("id", ""))
	var already: bool = _purchased_ids.has(drink_id)
	var drink_color: Color = drink.get("color", Color(0.5, 0.5, 0.5, 1.0)) as Color
	var price: int = int(drink.get("price", 0))
	var name_str: String = str(drink.get("name", ""))
	var desc_str: String = str(drink.get("desc", ""))
	if already:
		btn.text = "%s  [已購]\n%s" % [name_str, desc_str]
		btn.disabled = true
	else:
		btn.text = "%s  -%d 銅\n%s" % [name_str, price, desc_str]
		btn.disabled = false
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(drink_color.r * 0.15, drink_color.g * 0.15, drink_color.b * 0.15, 0.85)
	normal_style.border_color = drink_color.darkened(0.3)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(drink_color.r * 0.25, drink_color.g * 0.25, drink_color.b * 0.25, 0.9)
	hover_style.border_color = drink_color
	btn.add_theme_stylebox_override("hover", hover_style)
	if not already:
		btn.pressed.connect(_on_drink_purchased.bind(drink_id))
	btn.mouse_entered.connect(_on_drink_hovered.bind(drink))
	return btn


func _on_drink_hovered(drink: Dictionary) -> void:
	if _detail_label == null:
		return
	var name_str: String = str(drink.get("name", ""))
	var desc_str: String = str(drink.get("desc", ""))
	var price: int = int(drink.get("price", 0))
	_detail_label.text = "%s (%d 銅) — %s" % [name_str, price, desc_str]
	var drink_color: Color = drink.get("color", Color(0.8, 0.8, 0.8, 1.0)) as Color
	_detail_label.modulate = drink_color.lightened(0.3)


func _on_drink_purchased(drink_id: String) -> void:
	if _current_player == null:
		return
	var drink: Dictionary = {}
	for d: Dictionary in DRINKS:
		if str(d.get("id", "")) == drink_id:
			drink = d
			break
	if drink.is_empty():
		return
	var price: int = int(drink.get("price", 0))
	var inv: Variant = _current_player.get("inventory")
	if inv == null or not inv.has_method("pay_copper"):
		return
	if not inv.pay_copper(price):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("銅幣不足！", Color(1.0, 0.4, 0.4, 1.0), 2.0)
		return
	_purchased_ids.append(drink_id)
	var buff_type: String = str(drink.get("buff_type", ""))
	var buff_value: float = float(drink.get("buff_value", 0.0))
	if buff_type == "free_blessing":
		if _current_player != null and _current_player.has_method("show_status_message"):
			_current_player.show_status_message(
				str(drink.get("name", "")) + " 已購買！",
				Color(0.6, 1.0, 0.7, 1.0), 2.0
			)
		AudioManager.play_sfx("equip")
		_close_ui()
		_trigger_blessing_selection()
		return
	elif _current_player.has_method("add_tavern_buff"):
		_current_player.add_tavern_buff(buff_type, buff_value)
	if _current_player != null and _current_player.has_method("show_status_message"):
		_current_player.show_status_message(
			str(drink.get("name", "")) + " 已購買！",
			Color(0.6, 1.0, 0.7, 1.0), 2.0
		)
	_refresh_balance()
	_update_drink_buttons()
	AudioManager.play_sfx("equip")


func _get_refresh_cost() -> int:
	match _refresh_count:
		0:
			return 20
		1:
			return 40
		2:
			return 80
		_:
			return 160


func _on_refresh_pressed(refresh_btn: Button) -> void:
	if _current_player == null:
		return
	var cost: int = _get_refresh_cost()
	var inv: Variant = _current_player.get("inventory")
	if inv == null or not inv.has_method("pay_copper"):
		return
	if not inv.pay_copper(cost):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("銅幣不足！", Color(1.0, 0.4, 0.4, 1.0), 2.0)
		return
	_refresh_count += 1
	_purchased_ids.clear()
	_refresh_balance()
	_update_drink_buttons()
	refresh_btn.text = "刷新飲品 (-%d 銅)" % _get_refresh_cost()
	AudioManager.play_sfx("ui_open")


func _update_drink_buttons() -> void:
	for i: int in range(_btn_nodes.size()):
		if i >= DRINKS.size():
			break
		var btn: Button = _btn_nodes[i]
		var drink: Dictionary = DRINKS[i]
		var drink_id: String = str(drink.get("id", ""))
		var already: bool = _purchased_ids.has(drink_id)
		var price: int = int(drink.get("price", 0))
		var name_str: String = str(drink.get("name", ""))
		var desc_str: String = str(drink.get("desc", ""))
		if already:
			btn.text = "%s  [已購]\n%s" % [name_str, desc_str]
			btn.disabled = true
			if btn.pressed.is_connected(_on_drink_purchased):
				btn.pressed.disconnect(_on_drink_purchased)
		else:
			btn.text = "%s  -%d 銅\n%s" % [name_str, price, desc_str]
			btn.disabled = false
			if not btn.pressed.is_connected(_on_drink_purchased):
				btn.pressed.connect(_on_drink_purchased.bind(drink_id))


func _refresh_balance() -> void:
	if _balance_label == null or _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null or not inv.has_method("get_total_copper"):
		return
	_balance_label.text = "餘額: %d 銅" % int(inv.get_total_copper())


func _trigger_blessing_selection() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	var hud_node: Node = main_scene.get_node_or_null("HUDCanvas/HUD")
	if hud_node == null:
		hud_node = main_scene.get_node_or_null("HUD")
	if hud_node != null and hud_node.has_method("open_blessing_selection"):
		hud_node.open_blessing_selection([], null)


func _close_ui() -> void:
	if _canvas != null:
		_canvas.queue_free()
		_canvas = null
	get_tree().paused = false
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null


func _input(event: InputEvent) -> void:
	if _canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_ui()
		get_viewport().set_input_as_handled()
