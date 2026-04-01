extends Area2D
class_name ClassMasterNpc

const CHANGE_COST_COPPER: int = 100
const UI_AUDIO_CLICK_HOOK = preload("res://scripts/ui/ui_audio_click_hook.gd")

const CLASS_COLORS: Dictionary = {
	"warrior": Color(0.65, 0.25, 0.15, 1.0),
	"mage": Color(0.25, 0.25, 0.65, 1.0),
	"ranger": Color(0.15, 0.55, 0.25, 1.0),
}

var _canvas: CanvasLayer = null
var _current_player: Variant = null


func _ready() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 18.0
		col.shape = shape
		add_child(col)


func get_interaction_prompt() -> String:
	return "[E] 職業大師"


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
	panel.offset_top = -160.0
	panel.offset_right = 240.0
	panel.offset_bottom = 160.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "職業大師"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "費用: 1 銀幣（100 銅）＋重置天賦"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.84, 0.84, 0.84, 1.0)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var class_row: HBoxContainer = HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 12)
	vbox.add_child(class_row)

	for class_id: String in ["warrior", "mage", "ranger"]:
		class_row.add_child(_build_class_button(class_id))

	vbox.add_child(HSeparator.new())

	var footer: HBoxContainer = HBoxContainer.new()
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_btn: Button = Button.new()
	close_btn.text = "關閉"
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_ui)
	footer.add_child(close_btn)
	vbox.add_child(footer)

	UI_AUDIO_CLICK_HOOK.attach(_canvas)
	AudioManager.play_sfx("ui_open")


func _build_class_button(class_id: String) -> Button:
	var class_names: Dictionary = {"warrior": "戰士", "mage": "法師", "ranger": "弓手"}
	var btn: Button = Button.new()
	btn.text = str(class_names.get(class_id, class_id))
	btn.custom_minimum_size = Vector2(120, 60)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var base_color: Color = CLASS_COLORS.get(class_id, Color(0.3, 0.3, 0.3)) as Color
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(base_color.r, base_color.g, base_color.b, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(base_color.r, base_color.g, base_color.b, 0.6)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.pressed.connect(_on_class_chosen.bind(class_id))
	return btn


func _on_class_chosen(class_id: String) -> void:
	if _current_player == null:
		_close_ui()
		return
	var inv: Variant = _current_player.get("inventory")
	if inv == null or not inv.has_method("pay_copper"):
		_close_ui()
		return
	if not inv.pay_copper(CHANGE_COST_COPPER):
		if _current_player.has_method("show_status_message"):
			_current_player.show_status_message("銀幣不足！", Color(1.0, 0.4, 0.4, 1.0), 2.5)
		return
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	if class_system != null and class_system.has_method("save_class"):
		class_system.save_class(class_id)
		# Reset base stats to defaults before re-applying class multipliers
		var ps: Variant = _current_player.get("player_stats")
		if ps != null:
			ps.base_max_hp = 100
			ps.base_attack = 8
			ps.base_speed = 80.0
			class_system.apply_to_stats(ps)
	if _current_player.has_method("refresh_class_visuals"):
		_current_player.refresh_class_visuals()
	if _current_player.has_method("_refresh_all_stats"):
		_current_player._refresh_all_stats()
	var skill_system: Node = get_node_or_null("/root/SkillSystem")
	if skill_system != null and skill_system.has_method("_equip_class_skills"):
		skill_system._equip_class_skills(class_id)
	if _current_player.has_method("show_status_message"):
		var class_names: Dictionary = {"warrior": "戰士", "mage": "法師", "ranger": "弓手"}
		_current_player.show_status_message("職業已更改為 " + str(class_names.get(class_id, class_id)), Color(0.6, 1.0, 0.8, 1.0), 3.0)
	_close_ui()


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
