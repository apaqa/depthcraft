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

var _canvas: CanvasLayer = null
var _current_player: Variant = null
var _refresh_count: int = 0
var _purchased_ids: Array[String] = []
var _btn_nodes: Array[Button] = []
var _balance_label: Label = null


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
	panel.offset_left = -260.0
	panel.offset_top = -220.0
	panel.offset_right = 260.0
	panel.offset_bottom = 220.0
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
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "酒保 — 出發前喝一杯？"
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

	vbox.add_child(HSeparator.new())

	var drink_list: VBoxContainer = VBoxContainer.new()
	drink_list.add_theme_constant_override("separation", 6)
	vbox.add_child(drink_list)

	_btn_nodes.clear()
	for drink: Dictionary in DRINKS:
		var btn: Button = _build_drink_button(drink)
		_btn_nodes.append(btn)
		drink_list.add_child(btn)

	vbox.add_child(HSeparator.new())

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

	vbox.add_child(footer)

	UI_AUDIO_CLICK_HOOK.attach(_canvas)
	AudioManager.play_sfx("ui_open")


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
	return btn


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
		_trigger_blessing_selection()
	elif _current_player.has_method("add_tavern_buff"):
		_current_player.add_tavern_buff(buff_type, buff_value)
	if _current_player.has_method("show_status_message"):
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
