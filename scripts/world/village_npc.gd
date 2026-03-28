extends Area2D

signal recruited(npc_data: Dictionary)

const DIALOG_WIDTH: float = 360.0
const DIALOG_HEIGHT: float = 220.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var npc_data: Dictionary = {}
var is_recruitable: bool = true
var _dialog_canvas: CanvasLayer = null
var _dialog_root: Control = null
var _current_player: Node = null


func _ready() -> void:
	_apply_setup()


func setup(data: Dictionary, recruitable: bool = true) -> void:
	npc_data = data.duplicate(true)
	is_recruitable = recruitable
	_apply_setup()


func get_interaction_prompt() -> String:
	if not is_recruitable:
		return ""
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "[E] 交談"
	return "[E] Talk"


func interact(player: Node) -> void:
	if not is_recruitable or _dialog_canvas != null:
		return
	_current_player = player
	if _current_player != null and _current_player.has_method("set_ui_blocked"):
		_current_player.set_ui_blocked(true)
	_open_dialog()


func _exit_tree() -> void:
	if _dialog_canvas != null and is_instance_valid(_dialog_canvas):
		_dialog_canvas.queue_free()
	_dialog_canvas = null
	_dialog_root = null
	_release_player()


func _apply_setup() -> void:
	if not is_inside_tree():
		return
	if sprite != null:
		var portrait_path: String = str(npc_data.get("portrait_path", ""))
		if portrait_path != "":
			var portrait_texture: Texture2D = load(portrait_path) as Texture2D
			if portrait_texture != null:
				sprite.texture = portrait_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if collision_shape != null:
		collision_shape.disabled = not is_recruitable
	monitorable = is_recruitable
	monitoring = is_recruitable


func _open_dialog() -> void:
	_dialog_canvas = CanvasLayer.new()
	_dialog_canvas.layer = 11
	add_child(_dialog_canvas)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_canvas.add_child(root)
	_dialog_root = root

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	root.add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -DIALOG_WIDTH * 0.5
	panel.offset_top = -DIALOG_HEIGHT * 0.5
	panel.offset_right = DIALOG_WIDTH * 0.5
	panel.offset_bottom = DIALOG_HEIGHT * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title_label: Label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.text = str(npc_data.get("name", "NPC"))
	content.add_child(title_label)

	var dialog_label: Label = Label.new()
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.text = NpcManager.get_dialog_text(npc_data)
	content.add_child(dialog_label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	content.add_child(button_row)

	var recruit_button: Button = Button.new()
	recruit_button.text = "招募" if str(LocaleManager.get_locale()).begins_with("zh") else "Recruit"
	recruit_button.pressed.connect(_on_recruit_pressed)
	button_row.add_child(recruit_button)

	var leave_button: Button = Button.new()
	leave_button.text = "之後再說" if str(LocaleManager.get_locale()).begins_with("zh") else "Maybe Later"
	leave_button.pressed.connect(_close_dialog)
	button_row.add_child(leave_button)


func _close_dialog() -> void:
	if _dialog_canvas != null and is_instance_valid(_dialog_canvas):
		_dialog_canvas.queue_free()
	_dialog_canvas = null
	_dialog_root = null
	_release_player()


func _on_recruit_pressed() -> void:
	NpcManager.recruit_npc(npc_data)
	if _current_player != null and _current_player.has_method("show_status_message"):
		var npc_name: String = str(npc_data.get("name", "NPC"))
		var role_name: String = NpcManager.get_role_display_name(str(npc_data.get("role", "")))
		if str(LocaleManager.get_locale()).begins_with("zh"):
			_current_player.show_status_message("%s 已加入據點，擔任 %s。" % [npc_name, role_name], Color(0.75, 1.0, 0.75, 1.0), 2.6)
		else:
			_current_player.show_status_message("%s joined your base as a %s." % [npc_name, role_name], Color(0.75, 1.0, 0.75, 1.0), 2.6)
	recruited.emit(npc_data.duplicate(true))
	_close_dialog()
	queue_free()


func _release_player() -> void:
	if _current_player != null and _current_player.has_method("set_ui_blocked"):
		_current_player.set_ui_blocked(false)
	_current_player = null
