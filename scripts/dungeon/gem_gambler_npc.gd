extends Area2D
class_name GemGamblerNpc

const GEM_ICON_GREEN: Texture2D = preload("res://assets/icons/gem_01a.png")
const GEM_ICON_BLUE: Texture2D = preload("res://assets/icons/gem_01c.png")
const GEM_ICON_PURPLE: Texture2D = preload("res://assets/icons/gem_01i.png")
const GEM_ICON_RED: Texture2D = preload("res://assets/icons/gem_01d.png")

const GEM_ORDER: Array[String] = ["gem_green", "gem_blue", "gem_purple", "gem_red"]

const GEM_COLORS: Dictionary = {
	"gem_green": Color(0.3, 0.85, 0.3, 1.0),
	"gem_blue": Color(0.3, 0.55, 1.0, 1.0),
	"gem_purple": Color(0.65, 0.3, 0.9, 1.0),
	"gem_red": Color(0.9, 0.2, 0.2, 1.0),
}

const GEM_NAMES: Dictionary = {
	"gem_green": "綠寶石",
	"gem_blue": "藍寶石",
	"gem_purple": "紫寶石",
	"gem_red": "紅寶石",
}

const NEXT_TIER: Dictionary = {
	"gem_green": "gem_blue",
	"gem_blue": "gem_purple",
	"gem_purple": "gem_red",
	"gem_red": "",
}

var _canvas: CanvasLayer = null
var _current_player: Variant = null
var _selected_gem: String = "gem_green"
var _bet_spin: SpinBox = null
var _dice_label_a: Label = null
var _dice_label_b: Label = null
var _result_label: Label = null
var _roll_btn: Button = null
var _owned_label: Label = null
var _gem_btns: Dictionary = {}
var _animating: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		add_child(col)


func get_interaction_prompt() -> String:
	return "[E] 寶石骰局"


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
	panel.offset_left = -240.0
	panel.offset_top = -230.0
	panel.offset_right = 240.0
	panel.offset_bottom = 230.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	style.border_color = Color(0.55, 0.25, 0.75, 1.0)
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
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "寶石骰局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.85, 0.6, 1.0, 1.0)
	vbox.add_child(title)

	var rules: Label = Label.new()
	rules.text = "2-5 輸 / 6-8 平（退還）/ 9-11 贏×2 / 12 大獎×5+升階寶石"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_theme_font_size_override("font_size", 11)
	rules.modulate = Color(0.65, 0.65, 0.65, 1.0)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rules)

	vbox.add_child(HSeparator.new())

	# Gem selector
	var gem_header: Label = Label.new()
	gem_header.text = "選擇押注寶石種類："
	gem_header.add_theme_font_size_override("font_size", 12)
	gem_header.modulate = Color(0.85, 0.85, 0.85, 1.0)
	vbox.add_child(gem_header)

	var gem_row: HBoxContainer = HBoxContainer.new()
	gem_row.add_theme_constant_override("separation", 6)
	vbox.add_child(gem_row)

	_gem_btns.clear()
	for gem_id: String in GEM_ORDER:
		var gbtn: Button = Button.new()
		gbtn.text = str(GEM_NAMES.get(gem_id, gem_id))
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.custom_minimum_size = Vector2(0, 28)
		gbtn.process_mode = Node.PROCESS_MODE_ALWAYS
		gbtn.pressed.connect(_on_gem_selected.bind(gem_id))
		gem_row.add_child(gbtn)
		_gem_btns[gem_id] = gbtn

	# Bet row
	var bet_row: HBoxContainer = HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bet_row)

	var bet_lbl: Label = Label.new()
	bet_lbl.text = "押注數量："
	bet_lbl.add_theme_font_size_override("font_size", 13)
	bet_lbl.modulate = Color(0.85, 0.85, 0.85, 1.0)
	bet_row.add_child(bet_lbl)

	_bet_spin = SpinBox.new()
	_bet_spin.min_value = 0
	_bet_spin.max_value = 0
	_bet_spin.step = 1
	_bet_spin.value = 0
	_bet_spin.custom_minimum_size = Vector2(90, 0)
	_bet_spin.process_mode = Node.PROCESS_MODE_ALWAYS
	bet_row.add_child(_bet_spin)

	_owned_label = Label.new()
	_owned_label.text = ""
	_owned_label.add_theme_font_size_override("font_size", 12)
	_owned_label.modulate = Color(0.65, 0.65, 0.65, 1.0)
	bet_row.add_child(_owned_label)

	# Dice display
	var dice_row: HBoxContainer = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 20)
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(dice_row)

	_dice_label_a = Label.new()
	_dice_label_a.text = "?"
	_dice_label_a.add_theme_font_size_override("font_size", 48)
	_dice_label_a.modulate = Color(0.9, 0.9, 1.0, 1.0)
	_dice_label_a.custom_minimum_size = Vector2(60, 60)
	_dice_label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_row.add_child(_dice_label_a)

	var plus_lbl: Label = Label.new()
	plus_lbl.text = "+"
	plus_lbl.add_theme_font_size_override("font_size", 32)
	plus_lbl.modulate = Color(0.7, 0.7, 0.7, 1.0)
	dice_row.add_child(plus_lbl)

	_dice_label_b = Label.new()
	_dice_label_b.text = "?"
	_dice_label_b.add_theme_font_size_override("font_size", 48)
	_dice_label_b.modulate = Color(0.9, 0.9, 1.0, 1.0)
	_dice_label_b.custom_minimum_size = Vector2(60, 60)
	_dice_label_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_row.add_child(_dice_label_b)

	# Result label
	_result_label = Label.new()
	_result_label.text = "押注寶石，然後擲骰！"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 15)
	_result_label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_result_label)

	vbox.add_child(HSeparator.new())

	# Footer
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)

	_roll_btn = Button.new()
	_roll_btn.text = "擲骰！"
	_roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_btn.custom_minimum_size = Vector2(0, 34)
	_roll_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_roll_btn.modulate = Color(0.85, 0.6, 1.0, 1.0)
	_roll_btn.pressed.connect(_on_roll_pressed)
	footer.add_child(_roll_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "關閉"
	close_btn.custom_minimum_size = Vector2(80, 34)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_ui)
	footer.add_child(close_btn)

	_on_gem_selected(_selected_gem)
	_update_gem_btn_visuals()
	AudioManager.play_sfx("ui_open")


func _on_gem_selected(gem_id: String) -> void:
	_selected_gem = gem_id
	_update_gem_btn_visuals()
	_update_owned_display()
	_reset_dice()


func _update_gem_btn_visuals() -> void:
	for gem_id: String in _gem_btns.keys():
		var gbtn: Button = _gem_btns[gem_id] as Button
		var is_active: bool = (gem_id == _selected_gem)
		var gem_col: Color = GEM_COLORS.get(gem_id, Color(0.7, 0.7, 0.7, 1.0)) as Color
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		if is_active:
			btn_style.bg_color = Color(gem_col.r * 0.35, gem_col.g * 0.35, gem_col.b * 0.35, 0.95)
			btn_style.border_color = gem_col
			btn_style.border_width_left = 2
			btn_style.border_width_top = 2
			btn_style.border_width_right = 2
			btn_style.border_width_bottom = 2
		else:
			btn_style.bg_color = Color(0.12, 0.09, 0.16, 0.9)
			btn_style.border_color = gem_col.darkened(0.5)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		gbtn.add_theme_stylebox_override("normal", btn_style)
		gbtn.modulate = gem_col if is_active else gem_col.darkened(0.3)


func _update_owned_display() -> void:
	if _current_player == null or _bet_spin == null or _owned_label == null:
		return
	var inv: Variant = _current_player.get("inventory")
	var owned: int = 0
	if inv != null and inv.has_method("get_item_count"):
		owned = int(inv.get_item_count(_selected_gem))
	_bet_spin.max_value = float(owned)
	if _bet_spin.value > float(owned):
		_bet_spin.value = float(owned)
	_owned_label.text = "（擁有 %d 個）" % owned
	var gem_col: Color = GEM_COLORS.get(_selected_gem, Color(0.7, 0.7, 0.7, 1.0)) as Color
	_owned_label.modulate = gem_col.lightened(0.2)


func _reset_dice() -> void:
	if _dice_label_a != null:
		_dice_label_a.text = "?"
		_dice_label_a.modulate = Color(0.9, 0.9, 1.0, 1.0)
	if _dice_label_b != null:
		_dice_label_b.text = "?"
		_dice_label_b.modulate = Color(0.9, 0.9, 1.0, 1.0)
	if _result_label != null:
		_result_label.text = "押注寶石，然後擲骰！"
		_result_label.modulate = Color(0.75, 0.75, 0.75, 1.0)


func _on_roll_pressed() -> void:
	if _animating:
		return
	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return
	var bet: int = int(_bet_spin.value)
	if bet <= 0:
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("請先設定押注數量", Color(1.0, 0.8, 0.3, 1.0), 1.5)
		return
	var owned: int = int(inv.get_item_count(_selected_gem))
	if owned < bet:
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("寶石不足！", Color(1.0, 0.4, 0.4, 1.0), 1.5)
		return
	if not inv.remove_item(_selected_gem, bet):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("扣除失敗", Color(1.0, 0.4, 0.4, 1.0), 1.5)
		return

	var die_a: int = randi() % 6 + 1
	var die_b: int = randi() % 6 + 1
	var total: int = die_a + die_b

	_animating = true
	_roll_btn.disabled = true
	_result_label.text = "骰子滾動中…"
	_result_label.modulate = Color(0.85, 0.85, 0.35, 1.0)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	var steps: int = 12
	var interval: float = 0.5 / float(steps)
	_active_tween = create_tween()
	_active_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	for i: int in range(steps):
		_active_tween.tween_callback(_animate_dice_step).set_delay(interval * float(i))

	_active_tween.tween_callback(_finish_roll.bind(die_a, die_b, total, bet)).set_delay(0.5)


func _animate_dice_step() -> void:
	if _dice_label_a != null:
		_dice_label_a.text = str(randi() % 6 + 1)
	if _dice_label_b != null:
		_dice_label_b.text = str(randi() % 6 + 1)


func _finish_roll(die_a: int, die_b: int, total: int, bet: int) -> void:
	_animating = false
	if _roll_btn != null:
		_roll_btn.disabled = false

	if _dice_label_a != null:
		_dice_label_a.text = str(die_a)
	if _dice_label_b != null:
		_dice_label_b.text = str(die_b)

	if _current_player == null:
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null:
		return

	var gem_col: Color = GEM_COLORS.get(_selected_gem, Color(0.7, 0.7, 0.7, 1.0)) as Color
	var gem_name: String = str(GEM_NAMES.get(_selected_gem, _selected_gem))

	if total <= 5:
		# Lose
		if _dice_label_a != null:
			_dice_label_a.modulate = Color(1.0, 0.3, 0.3, 1.0)
		if _dice_label_b != null:
			_dice_label_b.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_result_label.text = "點數 %d — 輸了！失去 %d 個%s" % [total, bet, gem_name]
		_result_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
		AudioManager.play_sfx("hit_enemy")
	elif total <= 8:
		# Tie — return bet
		inv.add_item(_selected_gem, bet)
		if _dice_label_a != null:
			_dice_label_a.modulate = Color(0.9, 0.9, 0.9, 1.0)
		if _dice_label_b != null:
			_dice_label_b.modulate = Color(0.9, 0.9, 0.9, 1.0)
		_result_label.text = "點數 %d — 平局！退還 %d 個%s" % [total, bet, gem_name]
		_result_label.modulate = Color(0.85, 0.85, 0.85, 1.0)
		AudioManager.play_sfx("ui_open")
	elif total <= 11:
		# Win ×2
		inv.add_item(_selected_gem, bet * 2)
		if _dice_label_a != null:
			_dice_label_a.modulate = Color(0.3, 1.0, 0.4, 1.0)
		if _dice_label_b != null:
			_dice_label_b.modulate = Color(0.3, 1.0, 0.4, 1.0)
		_result_label.text = "點數 %d — 贏了！獲得 %d 個%s" % [total, bet * 2, gem_name]
		_result_label.modulate = Color(0.35, 1.0, 0.45, 1.0)
		AudioManager.play_sfx("equip")
	else:
		# Jackpot (total == 12) ×5 + next tier
		inv.add_item(_selected_gem, bet * 5)
		if _dice_label_a != null:
			_dice_label_a.modulate = Color(1.0, 0.85, 0.2, 1.0)
		if _dice_label_b != null:
			_dice_label_b.modulate = Color(1.0, 0.85, 0.2, 1.0)
		var next_tier: String = str(NEXT_TIER.get(_selected_gem, ""))
		var jackpot_msg: String = "大獎！獲得 %d 個%s" % [bet * 5, gem_name]
		if not next_tier.is_empty():
			inv.add_item(next_tier, 1)
			var next_name: String = str(GEM_NAMES.get(next_tier, next_tier))
			jackpot_msg += " + 1 個%s！" % next_name
		else:
			jackpot_msg += "！"
		_result_label.text = "點數 12 — " + jackpot_msg
		_result_label.modulate = Color(1.0, 0.85, 0.25, 1.0)
		AudioManager.play_sfx("level_up")

	_update_owned_display()


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
	_animating = false


func _input(event: InputEvent) -> void:
	if _canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_ui()
		get_viewport().set_input_as_handled()
