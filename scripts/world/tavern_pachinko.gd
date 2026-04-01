extends Control
class_name TavernPachinko

## Visual pachinko — TextureRect ball (gem_01a.png), 3 peg rows, 5 bins.
## Multi-step Tween path: start → row1 drift → row2 drift → final bin.
## Cost 5c  EV ≈ 4.6c

const BALL_TEXTURE: Texture2D = preload("res://assets/icons/kyrise/gem_01a.png")

const BET_OPTIONS: Array[int] = [10, 50, 100]
const BET_LABELS: Array[String] = ["10 銅", "50 銅", "1 銀"]
# Base payouts at 10c bet — multiply by bet/10 for larger bets
const BIN_BASE_PAYOUTS: Array = [0, 4, 10, 20, 60]
const BIN_WEIGHTS: Array = [0.30, 0.30, 0.20, 0.15, 0.05]
const BIN_COLORS: Array = [
	Color(0.5, 0.5, 0.5, 1.0),
	Color(0.55, 0.85, 0.55, 1.0),
	Color(0.6, 0.9, 0.5, 1.0),
	Color(1.0, 0.85, 0.3, 1.0),
	Color(1.0, 0.6, 0.2, 1.0),
]
const BOARD_W: float = 300.0
const BOARD_H: float = 200.0
const BALL_SIZE: float = 20.0

var _player: Node = null
var _animating: bool = false
var _result_bin: int = -1
var _ball_node: TextureRect = null
var _result_label: Label = null
var _drop_btn: Button = null
var _balance_label: Label = null
var _board_area: Control = null
var _active_tween: Tween = null
var _current_bet: int = 10
var _bet_btns: Array[Button] = []


func _ready() -> void:
	_build_ui()


func setup(player: Node) -> void:
	_player = player
	_refresh_balance()


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var title: Label = Label.new()
	title.text = "彈珠台"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.7, 0.9, 1.0, 1.0)
	vbox.add_child(title)

	var bet_row: HBoxContainer = HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 8)
	var bet_lbl: Label = Label.new()
	bet_lbl.text = "賭注:"
	bet_lbl.add_theme_font_size_override("font_size", 13)
	bet_lbl.modulate = Color(0.8, 0.8, 0.8, 1.0)
	bet_row.add_child(bet_lbl)
	_bet_btns.clear()
	for bi: int in range(BET_OPTIONS.size()):
		var bb: Button = Button.new()
		bb.text = BET_LABELS[bi]
		bb.custom_minimum_size = Vector2(60.0, 26.0)
		bb.pressed.connect(_on_bet_selected.bind(bi))
		bet_row.add_child(bb)
		_bet_btns.append(bb)
	vbox.add_child(bet_row)
	_update_bet_buttons()

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_balance_label)

	# Board
	_board_area = Control.new()
	_board_area.custom_minimum_size = Vector2(BOARD_W, BOARD_H)
	_board_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_board_area)

	var board_bg: ColorRect = ColorRect.new()
	board_bg.color = Color(0.08, 0.06, 0.14, 1.0)
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_area.add_child(board_bg)

	_build_pegs()
	_build_bins()

	# Ball (TextureRect)
	_ball_node = TextureRect.new()
	_ball_node.texture = BALL_TEXTURE
	_ball_node.size = Vector2(BALL_SIZE, BALL_SIZE)
	_ball_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ball_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ball_node.position = Vector2(BOARD_W * 0.5 - BALL_SIZE * 0.5, 8.0)
	_board_area.add_child(_ball_node)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.custom_minimum_size = Vector2(0.0, 28.0)
	vbox.add_child(_result_label)

	_drop_btn = Button.new()
	_drop_btn.text = "投球 (-%d 銅幣)" % _current_bet
	_drop_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_drop_btn.custom_minimum_size = Vector2(200.0, 40.0)
	_drop_btn.pressed.connect(_on_drop_pressed)
	vbox.add_child(_drop_btn)


func _build_pegs() -> void:
	var peg_rows: Array = [
		[Vector2(60.0, 42.0), Vector2(120.0, 42.0), Vector2(180.0, 42.0), Vector2(240.0, 42.0)],
		[Vector2(30.0, 82.0), Vector2(90.0, 82.0), Vector2(150.0, 82.0), Vector2(210.0, 82.0), Vector2(270.0, 82.0)],
		[Vector2(60.0, 122.0), Vector2(120.0, 122.0), Vector2(180.0, 122.0), Vector2(240.0, 122.0)],
	]
	for row: Array in peg_rows:
		for peg_pos_v: Variant in row:
			var peg_pos: Vector2 = peg_pos_v as Vector2
			var peg: ColorRect = ColorRect.new()
			peg.color = Color(0.75, 0.65, 0.25, 1.0)
			peg.size = Vector2(8.0, 8.0)
			peg.position = peg_pos - Vector2(4.0, 4.0)
			_board_area.add_child(peg)


func _build_bins() -> void:
	var bin_w: float = BOARD_W / float(BIN_BASE_PAYOUTS.size())
	for i in range(1, BIN_BASE_PAYOUTS.size()):
		var sep: ColorRect = ColorRect.new()
		sep.color = Color(0.45, 0.45, 0.5, 0.9)
		sep.size = Vector2(2.0, 40.0)
		sep.position = Vector2(float(i) * bin_w - 1.0, BOARD_H - 42.0)
		_board_area.add_child(sep)
	for i in range(BIN_BASE_PAYOUTS.size()):
		var base_val: int = int(BIN_BASE_PAYOUTS[i])
		var lbl_text: String = "x" if base_val == 0 else "%dx" % (base_val / 10)
		var lbl: Label = Label.new()
		lbl.text = lbl_text
		lbl.modulate = BIN_COLORS[i]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(bin_w, 36.0)
		lbl.position = Vector2(float(i) * bin_w, BOARD_H - 38.0)
		_board_area.add_child(lbl)


func _refresh_balance() -> void:
	if _balance_label == null or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	_balance_label.text = "餘額: %d 銅幣" % total


func _on_bet_selected(bet_index: int) -> void:
	if _animating:
		return
	if bet_index >= 0 and bet_index < BET_OPTIONS.size():
		_current_bet = BET_OPTIONS[bet_index]
	if _drop_btn != null:
		_drop_btn.text = "投球 (-%d 銅幣)" % _current_bet
	_update_bet_buttons()


func _update_bet_buttons() -> void:
	for bi: int in range(_bet_btns.size()):
		if bi >= BET_OPTIONS.size():
			break
		var is_active: bool = BET_OPTIONS[bi] == _current_bet
		_bet_btns[bi].modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.6, 0.6, 0.6, 1.0)


func _on_drop_pressed() -> void:
	if _animating or _player == null:
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
	_result_bin = _roll_bin()
	if _result_label != null:
		_result_label.text = "..."
		_result_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_animating = true
	if _drop_btn != null:
		_drop_btn.disabled = true
	_start_ball_animation()


func _roll_bin() -> int:
	var r: float = randf()
	var cumulative: float = 0.0
	for i in range(BIN_WEIGHTS.size()):
		cumulative += float(BIN_WEIGHTS[i])
		if r <= cumulative:
			return i
	return BIN_WEIGHTS.size() - 1


func _start_ball_animation() -> void:
	if _ball_node == null or _board_area == null:
		_on_ball_landed()
		return

	var bin_w: float = BOARD_W / float(BIN_BASE_PAYOUTS.size())
	var target_x: float = float(_result_bin) * bin_w + bin_w * 0.5 - BALL_SIZE * 0.5

	# Start position
	var start: Vector2 = Vector2(BOARD_W * 0.5 - BALL_SIZE * 0.5, 8.0)
	# Waypoints drift left/right as ball bounces off pegs
	var drift1: float = randf_range(-28.0, 28.0)
	var drift2: float = drift1 + randf_range(-28.0, 28.0)
	var wp1: Vector2 = Vector2(clamp(start.x + drift1, 8.0, BOARD_W - BALL_SIZE - 8.0), 65.0)
	var wp2: Vector2 = Vector2(clamp(start.x + drift2, 8.0, BOARD_W - BALL_SIZE - 8.0), 110.0)
	var end: Vector2 = Vector2(target_x, BOARD_H - 45.0)

	_ball_node.position = start

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_ball_node, "position", wp1, 0.40).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(_ball_node, "position", wp2, 0.40).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(_ball_node, "position", end, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	_active_tween.finished.connect(_on_ball_landed)


func _on_ball_landed() -> void:
	_animating = false
	if _drop_btn != null:
		_drop_btn.disabled = false
	if _result_bin < 0 or _result_bin >= BIN_BASE_PAYOUTS.size():
		return
	var bet_mult: int = _current_bet / 10
	var payout: int = int(BIN_BASE_PAYOUTS[_result_bin]) * bet_mult
	if payout > 0 and _player != null:
		_player.inventory.add_item("copper", payout)
		_refresh_balance()
		if _result_label != null:
			_result_label.text = "第 %d 格！+%d 銅幣" % [_result_bin + 1, payout]
			_result_label.modulate = BIN_COLORS[_result_bin]
	else:
		if _result_label != null:
			_result_label.text = "空格…"
			_result_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
