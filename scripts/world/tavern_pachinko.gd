extends Control
class_name TavernPachinko

## 5-bin weighted pachinko.
## Bins: [0, 2, 5, 10, 30] copper  Weights: [0.30, 0.30, 0.20, 0.15, 0.05]
## Cost 5c → EV = 4.6c

const DROP_COST: int = 5
const BIN_PAYOUTS: Array = [0, 2, 5, 10, 30]
const BIN_WEIGHTS: Array = [0.30, 0.30, 0.20, 0.15, 0.05]
const BIN_LABELS: Array = ["×", "2c", "5c", "10c", "30c"]
const BIN_COLORS: Array = [
	Color(0.5, 0.5, 0.5, 1.0),
	Color(0.55, 0.85, 0.55, 1.0),
	Color(0.6, 0.9, 0.5, 1.0),
	Color(1.0, 0.85, 0.3, 1.0),
	Color(1.0, 0.6, 0.2, 1.0),
]
const BOARD_W: float = 300.0
const BOARD_H: float = 200.0

var _player: Node = null
var _animating: bool = false
var _result_bin: int = -1
var _ball_node: ColorRect = null
var _result_label: Label = null
var _drop_btn: Button = null
var _balance_label: Label = null
var _board_area: Control = null
var _active_tween: Tween = null


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

	var info: Label = Label.new()
	info.text = "每次: %d 銅幣" % DROP_COST
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.modulate = Color(0.75, 0.75, 0.75, 1.0)
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_balance_label)

	# Board area
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

	# Ball
	_ball_node = ColorRect.new()
	_ball_node.color = Color(1.0, 0.88, 0.15, 1.0)
	_ball_node.size = Vector2(12.0, 12.0)
	_ball_node.position = Vector2(BOARD_W * 0.5 - 6.0, 8.0)
	_board_area.add_child(_ball_node)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.custom_minimum_size = Vector2(0.0, 28.0)
	vbox.add_child(_result_label)

	_drop_btn = Button.new()
	_drop_btn.text = "投球 (-%d 銅幣)" % DROP_COST
	_drop_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_drop_btn.custom_minimum_size = Vector2(200.0, 40.0)
	_drop_btn.pressed.connect(_on_drop_pressed)
	vbox.add_child(_drop_btn)


func _build_pegs() -> void:
	# Three staggered rows of pegs
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
			peg.size = Vector2(7.0, 7.0)
			peg.position = peg_pos - Vector2(3.5, 3.5)
			_board_area.add_child(peg)


func _build_bins() -> void:
	var bin_w: float = BOARD_W / float(BIN_PAYOUTS.size())
	# Separator lines
	for i in range(1, BIN_PAYOUTS.size()):
		var sep: ColorRect = ColorRect.new()
		sep.color = Color(0.45, 0.45, 0.5, 0.9)
		sep.size = Vector2(2.0, 40.0)
		sep.position = Vector2(float(i) * bin_w - 1.0, BOARD_H - 42.0)
		_board_area.add_child(sep)
	# Labels
	for i in range(BIN_PAYOUTS.size()):
		var lbl: Label = Label.new()
		lbl.text = BIN_LABELS[i]
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


func _on_drop_pressed() -> void:
	if _animating or _player == null:
		return
	var total: int = _player.inventory.get_total_copper()
	if total < DROP_COST:
		if _result_label != null:
			_result_label.text = "銅幣不足！"
			_result_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		return
	var paid: bool = _player.inventory.pay_copper(DROP_COST)
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
	var bin_w: float = BOARD_W / float(BIN_PAYOUTS.size())
	var target_x: float = float(_result_bin) * bin_w + bin_w * 0.5 - 6.0
	var target_pos: Vector2 = Vector2(target_x, BOARD_H - 45.0)
	_ball_node.position = Vector2(BOARD_W * 0.5 - 6.0, 8.0)
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.set_trans(Tween.TRANS_BOUNCE)
	_active_tween.tween_property(_ball_node, "position", target_pos, 1.4)
	_active_tween.finished.connect(_on_ball_landed)


func _on_ball_landed() -> void:
	_animating = false
	if _drop_btn != null:
		_drop_btn.disabled = false
	if _result_bin < 0 or _result_bin >= BIN_PAYOUTS.size():
		return
	var payout: int = int(BIN_PAYOUTS[_result_bin])
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
