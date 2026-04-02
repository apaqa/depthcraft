extends Area2D
class_name GiftBoxNpc

const GIFT_BOX_SYSTEM: Script = preload("res://scripts/dungeon/gift_box_system.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")

const BOX_ORDER: Array[String] = [
	"giftbox_bronze",
	"giftbox_silver",
	"giftbox_gold",
	"giftbox_mystic",
	"giftbox_cursed",
	"giftbox_celestial",
]

const RANDOM_BUFF_POOL: Array[Dictionary] = [
	{"type": "damage_multiplier", "value": 0.10, "name": "ATK +10%"},
	{"type": "armor_reduction", "value": 0.15, "name": "防禦 +15%"},
	{"type": "loot_drop_multiplier", "value": 0.20, "name": "掉落 +20%"},
	{"type": "move_speed_multiplier", "value": 0.10, "name": "移速 +10%"},
]

const CURSE_POOL: Array[Dictionary] = [
	{"type": "damage_multiplier", "value": -0.10, "name": "ATK -10%"},
	{"type": "armor_reduction", "value": -0.15, "name": "防禦 -15%"},
	{"type": "move_speed_multiplier", "value": -0.10, "name": "移速 -10%"},
]

var _canvas: CanvasLayer = null
var _current_player: Variant = null
var _balance_label: Label = null
var _anim_overlay: ColorRect = null
var _anim_panel: Panel = null
var _anim_icon: TextureRect = null
var _anim_result: Label = null
var _anim_continue: Button = null
var _anim_dismiss_btn: Button = null
var _pending_blessing: bool = false
var _pending_scroll: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_node_or_null("CollisionShape2D") == null:
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		add_child(col)


func get_interaction_prompt() -> String:
	return "[E] 神秘禮物盒"


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
	panel.offset_left = -290.0
	panel.offset_top = -240.0
	panel.offset_right = 290.0
	panel.offset_bottom = 240.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.10, 0.97)
	style.border_color = Color(0.65, 0.45, 0.85, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
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
	title.text = "神秘禮物盒"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.85, 0.7, 1.0, 1.0)
	vbox.add_child(title)

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 12)
	_balance_label.modulate = Color(0.78, 0.78, 0.78, 1.0)
	_balance_label.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(_balance_label)
	_refresh_balance()

	vbox.add_child(HSeparator.new())

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list)

	for box_id: String in BOX_ORDER:
		_build_box_row(box_id, list)

	vbox.add_child(HSeparator.new())

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
	vbox.add_child(footer)

	AudioManager.play_sfx("ui_open")


func _build_box_row(box_id: String, parent: VBoxContainer) -> void:
	var data: Dictionary = GIFT_BOX_SYSTEM.BOX_DATA.get(box_id, {}) as Dictionary
	if data.is_empty():
		return
	var box_color: Color = data.get("color", Color(0.7, 0.7, 0.7, 1.0)) as Color
	var price: int = int(data.get("price", 0))
	var name_key: String = str(data.get("name_key", ""))
	var desc_key: String = str(data.get("desc_key", ""))
	var box_name: String = LocaleManager.L(name_key) if name_key != "" else box_id
	var box_desc: String = LocaleManager.L(desc_key) if desc_key != "" else ""

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var box_icon: Variant = GIFT_BOX_SYSTEM.BOX_ICONS.get(box_id)
	if box_icon != null:
		icon.texture = box_icon as Texture2D
	row.add_child(icon)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 1)
	row.add_child(info_box)

	var name_lbl: Label = Label.new()
	name_lbl.text = box_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.modulate = box_color
	info_box.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = box_desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.65, 0.65, 0.65, 1.0)
	info_box.add_child(desc_lbl)

	var price_lbl: Label = Label.new()
	price_lbl.text = ITEM_DATABASE.format_currency(price)
	price_lbl.custom_minimum_size = Vector2(90, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.modulate = Color(1.0, 0.85, 0.3, 1.0)
	row.add_child(price_lbl)

	var buy_btn: Button = Button.new()
	buy_btn.text = "購買"
	buy_btn.custom_minimum_size = Vector2(56, 32)
	buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(box_color.r * 0.2, box_color.g * 0.2, box_color.b * 0.2, 0.9)
	btn_style.border_color = box_color.darkened(0.2)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	buy_btn.pressed.connect(_on_buy_pressed.bind(box_id, price))
	row.add_child(buy_btn)


func _on_buy_pressed(box_id: String, price: int) -> void:
	if _anim_overlay != null:
		return
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	if not inv.pay_copper(price):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message(LocaleManager.L("insufficient_gold"), Color(1.0, 0.4, 0.4, 1.0), 1.5)
		return
	_refresh_balance()
	var loot: Dictionary = GIFT_BOX_SYSTEM.roll_loot(box_id)
	_show_opening_animation(box_id, loot)


func _show_opening_animation(box_id: String, loot: Dictionary) -> void:
	_anim_overlay = ColorRect.new()
	_anim_overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	_anim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_anim_overlay)

	_anim_panel = Panel.new()
	_anim_panel.anchor_left = 0.5
	_anim_panel.anchor_top = 0.5
	_anim_panel.anchor_right = 0.5
	_anim_panel.anchor_bottom = 0.5
	_anim_panel.offset_left = -140.0
	_anim_panel.offset_top = -140.0
	_anim_panel.offset_right = 140.0
	_anim_panel.offset_bottom = 140.0
	_anim_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	var data: Dictionary = GIFT_BOX_SYSTEM.BOX_DATA.get(box_id, {}) as Dictionary
	var box_color: Color = data.get("color", Color(0.7, 0.7, 0.7, 1.0)) as Color
	ps.bg_color = Color(0.08, 0.06, 0.10, 0.98)
	ps.border_color = box_color
	ps.border_width_left = 2
	ps.border_width_top = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.corner_radius_top_left = 8
	ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8
	ps.corner_radius_bottom_right = 8
	_anim_panel.add_theme_stylebox_override("panel", ps)
	_canvas.add_child(_anim_panel)

	var anim_margin: MarginContainer = MarginContainer.new()
	anim_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anim_margin.add_theme_constant_override("margin_left", 16)
	anim_margin.add_theme_constant_override("margin_right", 16)
	anim_margin.add_theme_constant_override("margin_top", 14)
	anim_margin.add_theme_constant_override("margin_bottom", 14)
	_anim_panel.add_child(anim_margin)

	var anim_vbox: VBoxContainer = VBoxContainer.new()
	anim_vbox.add_theme_constant_override("separation", 10)
	anim_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	anim_margin.add_child(anim_vbox)

	_anim_icon = TextureRect.new()
	_anim_icon.custom_minimum_size = Vector2(64, 64)
	_anim_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_anim_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var closed_icon: Variant = GIFT_BOX_SYSTEM.BOX_ICONS.get(box_id)
	if closed_icon != null:
		_anim_icon.texture = closed_icon as Texture2D
	anim_vbox.add_child(_anim_icon)

	_anim_result = Label.new()
	_anim_result.text = "開箱中…"
	_anim_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_result.add_theme_font_size_override("font_size", 14)
	_anim_result.modulate = Color(0.85, 0.85, 0.35, 1.0)
	_anim_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anim_result.custom_minimum_size = Vector2(200, 40)
	anim_vbox.add_child(_anim_result)

	_anim_continue = Button.new()
	_anim_continue.text = "繼續"
	_anim_continue.custom_minimum_size = Vector2(100, 30)
	_anim_continue.process_mode = Node.PROCESS_MODE_ALWAYS
	_anim_continue.visible = false
	_anim_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_anim_continue.pressed.connect(_on_anim_continue.bind(loot))
	anim_vbox.add_child(_anim_continue)

	_anim_panel.scale = Vector2(0.6, 0.6)
	_anim_panel.pivot_offset = Vector2(140.0, 140.0)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_active_tween.tween_property(_anim_panel, "scale", Vector2(1.2, 1.2), 0.12)
	_active_tween.tween_property(_anim_panel, "scale", Vector2(1.0, 1.0), 0.08)
	_active_tween.tween_callback(_swap_to_open_icon.bind(box_id))
	_active_tween.tween_interval(0.05)
	_active_tween.tween_callback(_show_loot_result.bind(loot, box_id))

	var safety_ref: ColorRect = _anim_overlay
	get_tree().create_timer(5.0, true).timeout.connect(func() -> void:
		if _anim_overlay == safety_ref:
			_force_close_opening()
	)


func _swap_to_open_icon(box_id: String) -> void:
	if _anim_icon == null:
		return
	var open_icon: Variant = GIFT_BOX_SYSTEM.BOX_OPEN_ICONS.get(box_id)
	if open_icon != null:
		_anim_icon.texture = open_icon as Texture2D
	AudioManager.play_sfx("equip")


func _show_loot_result(loot: Dictionary, box_id: String) -> void:
	if _anim_result == null:
		return
	var loot_type: String = str(loot.get("type", "nothing"))
	var data: Dictionary = GIFT_BOX_SYSTEM.BOX_DATA.get(box_id, {}) as Dictionary
	var box_color: Color = data.get("color", Color(0.7, 0.7, 0.7, 1.0)) as Color

	match loot_type:
		"item":
			var item_id: String = str(loot.get("id", ""))
			var qty: int = int(loot.get("qty", 1))
			_anim_result.text = "獲得: %s ×%d" % [item_id, qty]
			_anim_result.modulate = Color(0.6, 1.0, 0.7, 1.0)
			_deliver_loot(loot)
			_enable_click_dismiss()
		"blessing_choice":
			_anim_result.text = "觸發祝福選擇！"
			_anim_result.modulate = Color(0.85, 0.7, 1.0, 1.0)
			_pending_blessing = true
			_anim_continue.visible = true
		"blessing_scroll":
			_anim_result.text = "觸發祝福捲軸！"
			_anim_result.modulate = Color(0.7, 0.85, 1.0, 1.0)
			_pending_scroll = true
			_anim_continue.visible = true
		"random_buff":
			var buff: Dictionary = RANDOM_BUFF_POOL[randi() % RANDOM_BUFF_POOL.size()]
			_anim_result.text = "酒館增益：%s" % str(buff.get("name", ""))
			_anim_result.modulate = Color(0.5, 1.0, 0.6, 1.0)
			_deliver_loot_buff(buff, false)
			_enable_click_dismiss()
		"curse_debuff":
			var curse: Dictionary = CURSE_POOL[randi() % CURSE_POOL.size()]
			_anim_result.text = "詛咒！%s" % str(curse.get("name", ""))
			_anim_result.modulate = Color(1.0, 0.35, 0.35, 1.0)
			_deliver_loot_buff(curse, true)
			_enable_click_dismiss()
		"nothing":
			_anim_result.text = "空空如也…"
			_anim_result.modulate = Color(0.55, 0.55, 0.55, 1.0)
			_enable_click_dismiss()
		_:
			_anim_result.text = "未知獎勵"
			_anim_result.modulate = box_color
			_enable_click_dismiss()


func _deliver_loot(loot: Dictionary) -> void:
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var item_id: String = str(loot.get("id", ""))
	var qty: int = int(loot.get("qty", 1))
	if item_id.is_empty() or qty <= 0:
		return
	inv.add_item(item_id, qty)


func _deliver_loot_buff(buff: Dictionary, is_curse: bool) -> void:
	if _current_player == null:
		return
	if not _current_player.has_method("add_tavern_buff"):
		return
	var buff_type: String = str(buff.get("type", ""))
	var buff_value: float = float(buff.get("value", 0.0))
	if buff_type.is_empty():
		return
	_current_player.add_tavern_buff(buff_type, buff_value)
	if is_curse:
		AudioManager.play_sfx("hit_enemy")
		var curse_player: Variant = _current_player
		var curse_type: String = buff_type
		var curse_value: float = buff_value
		get_tree().create_timer(60.0).timeout.connect(func() -> void:
			if is_instance_valid(curse_player) and curse_player.has_method("remove_tavern_buff"):
				curse_player.remove_tavern_buff(curse_type, curse_value)
		)
	else:
		AudioManager.play_sfx("equip")


func _on_anim_continue(loot: Dictionary) -> void:
	_dismiss_anim_overlay()
	_close_ui()
	if _pending_blessing or _pending_scroll:
		_pending_blessing = false
		_pending_scroll = false
		_trigger_blessing_selection()


func _enable_click_dismiss() -> void:
	if _canvas == null:
		return
	_anim_dismiss_btn = Button.new()
	_anim_dismiss_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim_dismiss_btn.flat = true
	_anim_dismiss_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_anim_dismiss_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_anim_dismiss_btn.modulate = Color(1, 1, 1, 0)
	_anim_dismiss_btn.pressed.connect(_dismiss_anim_overlay)
	_canvas.add_child(_anim_dismiss_btn)


func _force_close_opening() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_dismiss_anim_overlay()


func _dismiss_anim_overlay() -> void:
	if _anim_dismiss_btn != null:
		_anim_dismiss_btn.queue_free()
		_anim_dismiss_btn = null
	if _anim_overlay != null:
		_anim_overlay.queue_free()
		_anim_overlay = null
	if _anim_panel != null:
		_anim_panel.queue_free()
		_anim_panel = null
	_anim_icon = null
	_anim_result = null
	_anim_continue = null
	_refresh_balance()


func _refresh_balance() -> void:
	if _balance_label == null or _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null or not inv.has_method("get_total_copper"):
		return
	var total: int = int(inv.get_total_copper())
	_balance_label.text = "餘額: %s" % ITEM_DATABASE.format_currency(total)


func _trigger_blessing_selection() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	var hud_node: Node = main_scene.get_node_or_null("HUDCanvas/HUD")
	if hud_node == null:
		hud_node = main_scene.get_node_or_null("HUD")
	if hud_node != null and hud_node.has_method("open_blessing_selection"):
		get_tree().paused = false
		hud_node.open_blessing_selection([], null)


func _close_ui() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
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
	_anim_overlay = null
	_anim_panel = null
	_anim_icon = null
	_anim_result = null
	_anim_continue = null
	_anim_dismiss_btn = null
	_pending_blessing = false
	_pending_scroll = false


func _input(event: InputEvent) -> void:
	if _canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if _anim_overlay != null:
			return
		_close_ui()
		get_viewport().set_input_as_handled()
