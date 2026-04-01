extends Control
class_name TavernSlots

## Visual slot machine — 3 TextureRect reels, 5 icon symbols.
## Bet 1/5/10 copper.  3-same = bet×5,  2-same = bet×2.  EV ≈ 1.16×

const ICON_SWORD: Texture2D = preload("res://assets/icons/kyrise/sword_01a.png")
const ICON_SHIELD: Texture2D = preload("res://assets/icons/kyrise/shield_01a.png")
const ICON_POTION: Texture2D = preload("res://assets/icons/kyrise/potion_01a.png")
const ICON_COIN: Texture2D = preload("res://assets/icons/kyrise/coin_01c.png")
const ICON_SKULL: Texture2D = preload("res://assets/icons/kyrise/skull_01a.png")

const BET_MIN: int = 1
const BET_MAX: int = 1000
const MULT_3_SAME: int = 5
const MULT_2_SAME: int = 2
const SPIN_DURATION: float = 2.0

const SYMBOL_COLORS: Array = [
	Color(1.0, 0.55, 0.55, 1.0),
	Color(0.55, 0.75, 1.0, 1.0),
	Color(0.55, 1.0, 0.55, 1.0),
	Color(1.0, 0.9, 0.3, 1.0),
	Color(0.8, 0.5, 1.0, 1.0),
]

var _player: Node = null
var _spinning: bool = false
var _spin_elapsed: float = 0.0
var _cycle_elapsed: float = 0.0
var _reel_symbols: Array = [0, 0, 0]
var _final_symbols: Array = [0, 0, 0]
var _reel_icons: Array = []
var _reel_frames: Array = []
var _result_label: Label = null
var _spin_btn: Button = null
var _balance_label: Label = null
var _bet_slider: HSlider = null
var _bet_value_label: Label = null
var _current_bet: int = 10
var _history: Array = []
var _history_labels: Array = []


func _ready() -> void:
	_build_ui()


func setup(player: Node) -> void:
	_player = player
	_refresh_balance()


func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_elapsed += delta
	_cycle_elapsed += delta
	if _cycle_elapsed >= 0.08:
		_cycle_elapsed -= 0.08
		for i in range(3):
			var stop_at: float = SPIN_DURATION - float(2 - i) * 0.45
			if _spin_elapsed < stop_at:
				_reel_symbols[i] = randi() % 5
		_update_reel_display()
	if _spin_elapsed >= SPIN_DURATION:
		_reel_symbols[0] = _final_symbols[0]
		_reel_symbols[1] = _final_symbols[1]
		_reel_symbols[2] = _final_symbols[2]
		_update_reel_display()
		_spinning = false
		_finish_spin()


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "老虎機"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1.0, 0.85, 0.25, 1.0)
	vbox.add_child(title)

	# Balance
	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_balance_label)

	# Bet selector
	var bet_hbox: HBoxContainer = HBoxContainer.new()
	bet_hbox.add_theme_constant_override("separation", 8)
	bet_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bet_hbox)

	_bet_value_label = Label.new()
	_bet_value_label.text = "下注: %d 銅幣" % _current_bet
	_bet_value_label.add_theme_font_size_override("font_size", 13)
	_bet_value_label.custom_minimum_size = Vector2(120, 0)
	bet_hbox.add_child(_bet_value_label)

	_bet_slider = HSlider.new()
	_bet_slider.min_value = float(BET_MIN)
	_bet_slider.max_value = float(BET_MAX)
	_bet_slider.step = 1.0
	_bet_slider.value = float(_current_bet)
	_bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bet_slider.custom_minimum_size = Vector2(150, 0)
	_bet_slider.value_changed.connect(_on_bet_slider_changed)
	bet_hbox.add_child(_bet_slider)

	# Reel row
	var reels_hbox: HBoxContainer = HBoxContainer.new()
	reels_hbox.add_theme_constant_override("separation", 14)
	reels_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reels_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(reels_hbox)

	for i in range(3):
		var frame: PanelContainer = PanelContainer.new()
		frame.custom_minimum_size = Vector2(88.0, 88.0)
		reels_hbox.add_child(frame)
		_reel_frames.append(frame)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(icon_rect)
		_reel_icons.append(icon_rect)

	# Result label
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.custom_minimum_size = Vector2(0.0, 28.0)
	vbox.add_child(_result_label)

	# Spin button
	_spin_btn = Button.new()
	_spin_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_btn.custom_minimum_size = Vector2(200.0, 40.0)
	_spin_btn.pressed.connect(_on_spin_pressed)
	vbox.add_child(_spin_btn)
	_refresh_spin_btn_text()

	# Payout info
	var payout_lbl: Label = Label.new()
	payout_lbl.text = "3同 = 下注×%d   2同 = 下注×%d" % [MULT_3_SAME, MULT_2_SAME]
	payout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payout_lbl.add_theme_font_size_override("font_size", 12)
	payout_lbl.modulate = Color(0.65, 0.65, 0.65, 1.0)
	vbox.add_child(payout_lbl)

	# History header
	var hist_hdr: Label = Label.new()
	hist_hdr.text = "最近記錄:"
	hist_hdr.add_theme_font_size_override("font_size", 12)
	hist_hdr.modulate = Color(0.55, 0.55, 0.55, 1.0)
	vbox.add_child(hist_hdr)

	var hist_vbox: VBoxContainer = VBoxContainer.new()
	hist_vbox.add_theme_constant_override("separation", 1)
	vbox.add_child(hist_vbox)

	for _i in range(5):
		var hl: Label = Label.new()
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.add_theme_font_size_override("font_size", 11)
		hl.modulate = Color(0.5, 0.5, 0.5, 1.0)
		hist_vbox.add_child(hl)
		_history_labels.append(hl)

	_update_reel_display()


func _get_symbol_texture(idx: int) -> Texture2D:
	match idx:
		0: return ICON_SWORD
		1: return ICON_SHIELD
		2: return ICON_POTION
		3: return ICON_COIN
		4: return ICON_SKULL
		_: return ICON_COIN


func _update_reel_display() -> void:
	for i in range(3):
		var idx: int = _reel_symbols[i]
		var icon_rect: TextureRect = _reel_icons[i] as TextureRect
		if icon_rect == null:
			continue
		icon_rect.texture = _get_symbol_texture(idx)
		icon_rect.modulate = SYMBOL_COLORS[idx]


func _refresh_balance() -> void:
	if _balance_label == null or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	_balance_label.text = "餘額: %d 銅幣" % total


func _on_bet_slider_changed(value: float) -> void:
	_current_bet = maxi(int(value), 1)
	if _bet_value_label != null:
		_bet_value_label.text = "下注: %d 銅幣" % _current_bet
	_refresh_spin_btn_text()


func _refresh_spin_btn_text() -> void:
	if _spin_btn != null:
		_spin_btn.text = "旋轉 (-%d 銅幣)" % _current_bet


func _on_spin_pressed() -> void:
	if _spinning or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	if total < _current_bet:
		if _result_label != null:
			_result_label.text = "銅幣不足！"
			_result_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		return
	var paid: bool = _player.inventory.pay_copper(_current_bet)
	if not paid:
		return
	_refresh_balance()
	_final_symbols[0] = randi() % 5
	_final_symbols[1] = randi() % 5
	_final_symbols[2] = randi() % 5
	if _result_label != null:
		_result_label.text = "..."
		_result_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_spin_elapsed = 0.0
	_cycle_elapsed = 0.0
	_spinning = true
	if _spin_btn != null:
		_spin_btn.disabled = true


func _finish_spin() -> void:
	var s0: int = _final_symbols[0]
	var s1: int = _final_symbols[1]
	var s2: int = _final_symbols[2]
	var payout: int = 0
	var result_text: String = ""
	var result_color: Color = Color(1.0, 1.0, 1.0, 1.0)

	if s0 == s1 and s1 == s2:
		payout = _current_bet * MULT_3_SAME
		result_text = "★ 3同！+%d 銅幣" % payout
		result_color = Color(1.0, 0.92, 0.2, 1.0)
		_flash_win()
	elif s0 == s1 or s1 == s2 or s0 == s2:
		payout = _current_bet * MULT_2_SAME
		result_text = "2同！+%d 銅幣" % payout
		result_color = Color(0.55, 1.0, 0.55, 1.0)
	else:
		result_text = "未中獎"
		result_color = Color(0.6, 0.6, 0.6, 1.0)

	if _result_label != null:
		_result_label.text = result_text
		_result_label.modulate = result_color

	if payout > 0 and _player != null:
		_player.inventory.add_item("copper", payout)
		_refresh_balance()
		var am: Node = get_node_or_null("/root/AchievementManager")
		if am != null and am.has_method("record_gambling_win"):
			am.record_gambling_win(payout)

	_add_history(result_text)

	if _spin_btn != null:
		_spin_btn.disabled = false


func _flash_win() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.95, 0.35, 1.0), 0.10)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
	tween.tween_property(self, "modulate", Color(1.0, 0.95, 0.35, 1.0), 0.10)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)


func _add_history(text: String) -> void:
	_history.push_front(text)
	if _history.size() > 5:
		_history.pop_back()
	_refresh_history_display()


func _refresh_history_display() -> void:
	for i in range(_history_labels.size()):
		var lbl: Label = _history_labels[i] as Label
		if lbl == null:
			continue
		if i < _history.size():
			lbl.text = _history[i]
		else:
			lbl.text = ""
