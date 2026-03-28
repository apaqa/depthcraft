extends StaticBody2D
class_name LevelPortal

@export var target_level_id: String = "dungeon"
@export var prompt_text: String = "[E] Enter Portal"

const DOWN_TEXTURE: Texture2D = preload("res://assets/floor_stairs.png")
const CHECKPOINT_STEP: int = 5

var _checkpoint_canvas: CanvasLayer = null
var _checkpoint_root: Control = null
var _current_player: Variant = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite != null:
		sprite.texture = DOWN_TEXTURE
		sprite.modulate = Color(0.95, 0.95, 0.95, 1.0)


func get_interaction_prompt() -> String:
	if target_level_id == "dungeon" and _is_dungeon_locked():
		return "Cannot enter during raid"
	var resolved_prompt: String = prompt_text
	if target_level_id == "dungeon" and NpcManager != null and NpcManager.has_available_explorer_intel():
		resolved_prompt += NpcManager.get_explorer_prompt_suffix()
	return resolved_prompt


func interact(player) -> void:
	if target_level_id == "dungeon" and _is_dungeon_locked():
		if player != null and player.has_method("show_status_message"):
			player.show_status_message("Cannot enter during raid", Color(1.0, 0.35, 0.35, 1.0), 1.5)
		return
	if player == null:
		return
	if target_level_id == "dungeon":
		_open_checkpoint_panel(player)
		return
	player.portal_requested.emit(target_level_id, 1)


func secondary_interact(player) -> void:
	if target_level_id != "dungeon" or NpcManager == null:
		return
	var explorer_intel: Dictionary = NpcManager.claim_explorer_intel(player)
	if explorer_intel.is_empty():
		return
	if player != null and player.has_method("show_status_message"):
		var intel_message: String = str(explorer_intel.get("message", ""))
		var intel_color: Color = Color(0.75, 0.95, 1.0, 1.0)
		if str(explorer_intel.get("type", "")) == "buff":
			intel_color = Color(0.75, 1.0, 0.75, 1.0)
		player.show_status_message(intel_message, intel_color, 3.2)


func _input(event: InputEvent) -> void:
	if _checkpoint_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_checkpoint_panel()
		get_viewport().set_input_as_handled()


func _open_checkpoint_panel(player: Variant) -> void:
	if _checkpoint_canvas != null:
		return
	_current_player = player
	if player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	if "in_menu" in player:
		player.in_menu = true

	_checkpoint_canvas = CanvasLayer.new()
	_checkpoint_canvas.layer = 10
	add_child(_checkpoint_canvas)

	_checkpoint_root = Control.new()
	_checkpoint_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_checkpoint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checkpoint_canvas.add_child(_checkpoint_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_checkpoint_root.add_child(backdrop)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -170.0
	panel.offset_top = -150.0
	panel.offset_right = 170.0
	panel.offset_bottom = 150.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.96)
	panel_style.border_color = Color(0.35, 0.35, 0.42, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	_checkpoint_root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = _get_checkpoint_title_text()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)

	var hint_label: Label = Label.new()
	hint_label.text = _get_checkpoint_hint_text()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.modulate = Color(0.82, 0.82, 0.88, 1.0)
	vbox.add_child(hint_label)

	var button_list: VBoxContainer = VBoxContainer.new()
	button_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_list.add_theme_constant_override("separation", 8)
	vbox.add_child(button_list)

	var unlocked_floors: Array[int] = _get_unlocked_checkpoint_floors()
	for floor_number: int in unlocked_floors:
		var button: Button = Button.new()
		button.text = _get_checkpoint_option_text(floor_number)
		button.custom_minimum_size = Vector2(0.0, 36.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_checkpoint_selected.bind(floor_number))
		button_list.add_child(button)

	var close_button: Button = Button.new()
	close_button.text = _get_checkpoint_close_text()
	close_button.custom_minimum_size = Vector2(0.0, 34.0)
	close_button.pressed.connect(_close_checkpoint_panel)
	vbox.add_child(close_button)


func _on_checkpoint_selected(start_floor: int) -> void:
	var player: Variant = _current_player
	_close_checkpoint_panel()
	if player != null:
		player.portal_requested.emit(target_level_id, start_floor)


func _close_checkpoint_panel() -> void:
	if _checkpoint_canvas != null:
		_checkpoint_canvas.queue_free()
	_checkpoint_canvas = null
	_checkpoint_root = null
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null


func _get_unlocked_checkpoint_floors() -> Array[int]:
	var floors: Array[int] = [1]
	var deepest_floor: int = _get_deepest_floor_reached()
	var checkpoint_floor: int = CHECKPOINT_STEP
	while checkpoint_floor <= deepest_floor:
		floors.append(checkpoint_floor)
		checkpoint_floor += CHECKPOINT_STEP
	return floors


func _get_deepest_floor_reached() -> int:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return 1
	var deepest_value: Variant = main_node.get("deepest_dungeon_floor_reached")
	if deepest_value == null:
		return 1
	return max(int(deepest_value), 1)


func _get_checkpoint_title_text() -> String:
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "\u9078\u64c7\u8d77\u59cb\u6a13\u5c64"
	return "Choose Starting Floor"


func _get_checkpoint_hint_text() -> String:
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "\u53ea\u6703\u986f\u793a\u5df2\u89e3\u9396\u7684 checkpoint"
	return "Only unlocked checkpoints are shown"


func _get_checkpoint_option_text(floor_number: int) -> String:
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "\u5f9e\u7b2c %d \u5c64\u958b\u59cb" % floor_number
	return "Start from Floor %d" % floor_number


func _get_checkpoint_close_text() -> String:
	if str(LocaleManager.get_locale()).begins_with("zh"):
		return "\u53d6\u6d88"
	return "Cancel"


func _is_dungeon_locked() -> bool:
	var level: Node = get_parent()
	return level != null and level.has_method("is_raid_active") and level.is_raid_active()
