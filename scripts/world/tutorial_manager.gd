extends Node

const SAVE_PATH: String = "user://tutorial_save.json"

enum Step { MOVE = 0, ATTACK = 1, BUILD = 2, INTERACT = 3, DUNGEON = 4, DONE = 5 }

const STEP_TEXT_KEYS: Dictionary = {
	Step.MOVE: "tutorial_move",
	Step.ATTACK: "tutorial_attack",
	Step.BUILD: "tutorial_build",
	Step.INTERACT: "tutorial_interact",
	Step.DUNGEON: "tutorial_dungeon",
}

var _step: int = Step.MOVE
var _completed: bool = false
var _player = null
var _prompt_visible: bool = false

var _canvas: CanvasLayer
var _label: Label


func _ready() -> void:
	if _load_completed():
		_completed = true
		return
	_build_ui()
	_show_step(_step)


func bind_player(new_player) -> void:
	if _completed:
		return
	if _player != null:
		_disconnect_player(_player)
	_player = new_player
	if _player == null:
		return
	if _player.interaction_prompt_changed.is_connected(_on_prompt_changed):
		_player.interaction_prompt_changed.disconnect(_on_prompt_changed)
	if _player.interaction_prompt_cleared.is_connected(_on_prompt_cleared):
		_player.interaction_prompt_cleared.disconnect(_on_prompt_cleared)
	if _player.portal_requested.is_connected(_on_portal_requested):
		_player.portal_requested.disconnect(_on_portal_requested)
	if _player.building_system.build_state_changed.is_connected(_on_build_state_changed):
		_player.building_system.build_state_changed.disconnect(_on_build_state_changed)
	_player.interaction_prompt_changed.connect(_on_prompt_changed)
	_player.interaction_prompt_cleared.connect(_on_prompt_cleared)
	_player.portal_requested.connect(_on_portal_requested)
	_player.building_system.build_state_changed.connect(_on_build_state_changed)


func _disconnect_player(p) -> void:
	if p.interaction_prompt_changed.is_connected(_on_prompt_changed):
		p.interaction_prompt_changed.disconnect(_on_prompt_changed)
	if p.interaction_prompt_cleared.is_connected(_on_prompt_cleared):
		p.interaction_prompt_cleared.disconnect(_on_prompt_cleared)
	if p.portal_requested.is_connected(_on_portal_requested):
		p.portal_requested.disconnect(_on_portal_requested)
	if p.building_system.build_state_changed.is_connected(_on_build_state_changed):
		p.building_system.build_state_changed.disconnect(_on_build_state_changed)


func _process(_delta: float) -> void:
	if _completed or _player == null:
		return
	match _step:
		Step.MOVE:
			if _player.velocity.length_squared() > 1.0:
				_advance()
		Step.ATTACK:
			if Input.is_action_just_pressed("attack"):
				_advance()
		Step.INTERACT:
			if _prompt_visible and Input.is_action_just_pressed("interact"):
				_advance()


func _on_prompt_changed(_text: String) -> void:
	_prompt_visible = true


func _on_prompt_cleared() -> void:
	_prompt_visible = false


func _on_build_state_changed() -> void:
	if _step == Step.BUILD and _player != null and _player.building_system.is_build_mode_active():
		_advance()


func _on_portal_requested(target_level_id: String, _start_floor: int) -> void:
	if _step == Step.DUNGEON and target_level_id == "dungeon":
		_advance()


func _advance() -> void:
	_step += 1
	if _step >= Step.DONE:
		_finish()
		return
	_show_step(_step)


func _finish() -> void:
	_completed = true
	_save_completed()
	if _canvas != null:
		_canvas.visible = false


func _show_step(step: int) -> void:
	if _label == null:
		return
	var key: String = str(STEP_TEXT_KEYS.get(step, ""))
	_label.text = LocaleManager.L(key) if key != "" else ""


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	var bg: ColorRect = ColorRect.new()
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 0.82
	bg.anchor_bottom = 0.82
	bg.offset_left = -180.0
	bg.offset_top = -24.0
	bg.offset_right = 180.0
	bg.offset_bottom = 24.0
	bg.color = Color(0.0, 0.0, 0.0, 0.60)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.82
	_label.anchor_bottom = 0.82
	_label.offset_left = -180.0
	_label.offset_top = -24.0
	_label.offset_right = 180.0
	_label.offset_bottom = 24.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_label)


func _load_completed() -> bool:
	var path: String = ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(path):
		return false
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var text: String = raw.get_string_from_utf8()
	if text.is_empty():
		return false
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return bool(data.get("completed", false))


func _save_completed() -> void:
	var path: String = ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"completed": true}))
	file.flush()
