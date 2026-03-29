extends Control
class_name TavernSlots

## 3-reel slot machine.
## 5 equal-weight symbols → P(3-same)=0.04, P(2-same)=0.48
## Cost 10c, 3-same→50c, 2-same→15c  EV = 0.92

const SPIN_COST: int = 10
const PAYOUT_3_SAME: int = 50
const PAYOUT_2_SAME: int = 15

const SYMBOL_NAMES: Array = ["CHERRY", "LEMON", "BELL", "STAR", "DIAM"]
const SYMBOL_COLORS: Array = [
	Color(1.0, 0.4, 0.4, 1.0),
	Color(1.0, 0.92, 0.3, 1.0),
	Color(0.9, 0.8, 0.35, 1.0),
	Color(1.0, 0.95, 0.15, 1.0),
	Color(0.45, 0.8, 1.0, 1.0),
]

var _player: Node = null
var _spinning: bool = false
var _spin_elapsed: float = 0.0
var _spin_duration: float = 2.0
var _reel_symbols: Array = [0, 0, 0]
var _final_symbols: Array = [0, 0, 0]
var _cycle_elapsed: float = 0.0
var _reel_labels: Array = []
var _result_label: Label = null
var _spin_btn: Button = null
var _balance_label: Label = null


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
			var stop_at: float = _spin_duration - float(2 - i) * 0.45
			if _spin_elapsed < stop_at:
				_reel_symbols[i] = randi() % 5
		_update_reel_display()
	if _spin_elapsed >= _spin_duration:
		_reel_symbols[0] = _final_symbols[0]
		_reel_symbols[1] = _final_symbols[1]
		_reel_symbols[2] = _final_symbols[2]
		_update_reel_display()
		_spinning = false
		_finish_spin()


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var title: Label = Label.new()
	title.text = "老虎機"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1.0, 0.85, 0.25, 1.0)
	vbox.add_child(title)

	var info: Label = Label.new()
	info.text = "每次: %d 銅幣   3同: %d銅   2同: %d銅" % [SPIN_COST, PAYOUT_3_SAME, PAYOUT_2_SAME]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.modulate = Color(0.75, 0.75, 0.75, 1.0)
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_balance_label)

	var reels_hbox: HBoxContainer = HBoxContainer.new()
	reels_hbox.add_theme_constant_override("separation", 20)
	reels_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reels_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(reels_hbox)

	for i in range(3):
		var reel_bg: PanelContainer = PanelContainer.new()
		reel_bg.custom_minimum_size = Vector2(100.0, 80.0)
		reels_hbox.add_child(reel_bg)
		var reel_lbl: Label = Label.new()
		reel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reel_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reel_lbl.add_theme_font_size_override("font_size", 16)
		reel_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reel_bg.add_child(reel_lbl)
		_reel_labels.append(reel_lbl)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.custom_minimum_size = Vector2(0.0, 28.0)
	vbox.add_child(_result_label)

	_spin_btn = Button.new()
	_spin_btn.text = "旋轉 (-%d 銅幣)" % SPIN_COST
	_spin_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_btn.custom_minimum_size = Vector2(200.0, 40.0)
	_spin_btn.pressed.connect(_on_spin_pressed)
	vbox.add_child(_spin_btn)

	_update_reel_display()


func _update_reel_display() -> void:
	for i in range(3):
		var idx: int = _reel_symbols[i]
		var lbl: Label = _reel_labels[i] as Label
		if lbl == null:
			continue
		lbl.text = SYMBOL_NAMES[idx]
		lbl.modulate = SYMBOL_COLORS[idx]


func _refresh_balance() -> void:
	if _balance_label == null or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	_balance_label.text = "餘額: %d 銅幣" % total


func _on_spin_pressed() -> void:
	if _spinning or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	if total < SPIN_COST:
		if _result_label != null:
			_result_label.text = "銅幣不足！"
			_result_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		return
	var paid: bool = _player.inventory.pay_copper(SPIN_COST)
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
	if s0 == s1 and s1 == s2:
		payout = PAYOUT_3_SAME
		if _result_label != null:
			_result_label.text = "★ 3 同！+%d 銅幣" % payout
			_result_label.modulate = Color(1.0, 0.92, 0.2, 1.0)
	elif s0 == s1 or s1 == s2 or s0 == s2:
		payout = PAYOUT_2_SAME
		if _result_label != null:
			_result_label.text = "2 同！+%d 銅幣" % payout
			_result_label.modulate = Color(0.55, 1.0, 0.55, 1.0)
	else:
		if _result_label != null:
			_result_label.text = "未中獎"
			_result_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	if payout > 0 and _player != null:
		_player.inventory.add_item("copper", payout)
		_refresh_balance()
	if _spin_btn != null:
		_spin_btn.disabled = false
