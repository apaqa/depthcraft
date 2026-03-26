extends Control
class_name SettingsMenu

signal close_requested

const SETTINGS_PATH := "user://settings.json"
const TUTORIAL_PATH := "user://tutorial_save.json"

var _sliders: Dictionary = {}
var _lang_button: Button = null
var _zoom_slider: HSlider = null
var _tutorial_toggle: CheckButton = null
var _camera_ref: Camera2D = null
var _notice_label: Label = null
var _menu_buttons_root: VBoxContainer = null
var _settings_panel: PanelContainer = null
var _paused_game: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas_layer := get_parent()
	if canvas_layer is CanvasLayer:
		canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var content_root := Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_root)

	_notice_label = Label.new()
	_notice_label.anchor_left = 0.18
	_notice_label.anchor_top = 0.14
	_notice_label.anchor_right = 0.52
	_notice_label.anchor_bottom = 0.2
	_notice_label.offset_left = -10.0
	_notice_label.offset_right = 20.0
	_notice_label.text = "å¤šäººæ¨¡å?ä¸­ï??Šæˆ²ä¸æ??«å?"
	_notice_label.visible = false
	_notice_label.add_theme_font_size_override("font_size", 14)
	_notice_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 1.0))
	_notice_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_notice_label.add_theme_constant_override("outline_size", 2)
	content_root.add_child(_notice_label)

	_menu_buttons_root = VBoxContainer.new()
	_menu_buttons_root.anchor_left = 0.18
	_menu_buttons_root.anchor_top = 0.28
	_menu_buttons_root.anchor_right = 0.42
	_menu_buttons_root.anchor_bottom = 0.78
	_menu_buttons_root.offset_left = -20.0
	_menu_buttons_root.offset_right = 20.0
	_menu_buttons_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_buttons_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_buttons_root.add_theme_constant_override("separation", 16)
	content_root.add_child(_menu_buttons_root)

	_menu_buttons_root.add_child(_make_menu_button("ç¹¼ç??Šæˆ²", close_menu))
	_menu_buttons_root.add_child(_make_menu_button("ä¿å??Šæˆ²", _on_save_pressed))
	_menu_buttons_root.add_child(_make_menu_button("è¨­å?", _show_settings_page))
	_menu_buttons_root.add_child(_make_menu_button("ä¸»é¸??, _go_to_main_menu))
	_menu_buttons_root.add_child(_make_menu_button("?œé?", close_menu))

	_settings_panel = PanelContainer.new()
	_settings_panel.anchor_left = 0.42
	_settings_panel.anchor_top = 0.18
	_settings_panel.anchor_right = 0.82
	_settings_panel.anchor_bottom = 0.82
	_settings_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.98)
	_settings_panel.visible = false
	content_root.add_child(_settings_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 24)
	panel_margin.add_theme_constant_override("margin_right", 24)
	panel_margin.add_theme_constant_override("margin_top", 22)
	panel_margin.add_theme_constant_override("margin_bottom", 22)
	_settings_panel.add_child(panel_margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 14)
	panel_margin.add_child(panel_vbox)

	var back_button := _make_menu_button("??è¿”å?", _show_main_page)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_vbox.add_child(back_button)

	var title := Label.new()
	title.text = "è¨­å?"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	panel_vbox.add_child(title)

	panel_vbox.add_child(_build_section_label("?³é?"))
	_add_bus_slider(panel_vbox, "Master", "ä¸»éŸ³??)
	_add_bus_slider(panel_vbox, "Music", "?³æ?")
	_add_bus_slider(panel_vbox, "SFX", "?³æ?")

	panel_vbox.add_child(_build_section_label("è¦–è?"))
	var zoom_row := _build_option_row("è¦–è?ç¸®æ”¾")
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 1.5
	_zoom_slider.max_value = 3.0
	_zoom_slider.step = 0.1
	_zoom_slider.value = 2.0
	_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	zoom_row.add_child(_zoom_slider)
	panel_vbox.add_child(zoom_row)

	panel_vbox.add_child(_build_section_label("èªžè?"))
	var language_row := _build_option_row("èªžè?")
	_lang_button = Button.new()
	_style_secondary_button(_lang_button)
	_lang_button.custom_minimum_size = Vector2(140, 32)
	_lang_button.pressed.connect(_on_lang_toggle)
	language_row.add_child(_lang_button)
	panel_vbox.add_child(language_row)

	panel_vbox.add_child(_build_section_label("?°æ??ç¤º"))
	var tutorial_row := _build_option_row("é¡¯ç¤º?ç¤º")
	_tutorial_toggle = CheckButton.new()
	_tutorial_toggle.button_pressed = true
	_tutorial_toggle.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_tutorial_toggle.toggled.connect(_on_tutorial_toggled)
	tutorial_row.add_child(_tutorial_toggle)
	panel_vbox.add_child(tutorial_row)


func _make_menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(240, 36)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(callback)
	button.mouse_entered.connect(func() -> void:
		button.modulate = Color(1.15, 1.15, 1.15, 1.0)
		button.scale = Vector2(1.05, 1.05)
	)
	button.mouse_exited.connect(func() -> void:
		button.modulate = Color.WHITE
		button.scale = Vector2.ONE
	)
	return button


func _build_section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _build_option_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	row.add_child(label)
	return row


func _style_secondary_button(button: Button) -> void:
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	button.add_theme_constant_override("outline_size", 1)


func _add_bus_slider(parent: Control, bus_name: String, display_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var row := _build_option_row(display_name)
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 0.5
	slider.value = AudioServer.get_bus_volume_db(bus_idx)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float) -> void: _on_volume_changed(bus_name, val))
	row.add_child(slider)
	_sliders[bus_name] = slider
	parent.add_child(row)


func open_menu(camera: Camera2D = null) -> void:
	_camera_ref = camera
	_load_settings()
	_show_main_page()
	visible = true
	_paused_game = _can_pause_game()
	if _notice_label != null:
		_notice_label.visible = not _paused_game
	if _paused_game:
		get_tree().paused = true


func close_menu() -> void:
	if not visible:
		return
	_save_settings()
	visible = false
	if _paused_game:
		get_tree().paused = false
	_paused_game = false
	close_requested.emit()


func _show_main_page() -> void:
	if _menu_buttons_root != null:
		_menu_buttons_root.visible = true
	if _settings_panel != null:
		_settings_panel.visible = false


func _show_settings_page() -> void:
	if _menu_buttons_root != null:
		_menu_buttons_root.visible = false
	if _settings_panel != null:
		_settings_panel.visible = true


func _can_pause_game() -> bool:
	return not (multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0)


func _on_save_pressed() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].has_method("_save_persistent_state"):
		players[0]._save_persistent_state()
		print("Game saved.")
		return
	print("Save placeholder: no save hook available.")


func _go_to_main_menu() -> void:
	_save_settings()
	if _paused_game:
		get_tree().paused = false
	_paused_game = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_volume_changed(bus_name: String, db_value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db_value)


func _on_lang_toggle() -> void:
	var current := TranslationServer.get_locale()
	if current.begins_with("zh"):
		TranslationServer.set_locale("en")
		_lang_button.text = "English"
	else:
		TranslationServer.set_locale("zh_TW")
		_lang_button.text = "ç¹é?ä¸­æ?"


func _on_zoom_changed(value: float) -> void:
	if _camera_ref != null and is_instance_valid(_camera_ref):
		_camera_ref.zoom = Vector2(value, value)


func _on_tutorial_toggled(show_hints: bool) -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(TUTORIAL_PATH):
		var file := FileAccess.open(TUTORIAL_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				data = parsed
	data["completed"] = not show_hints
	var out := FileAccess.open(TUTORIAL_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(data))
		out.close()


func _load_settings() -> void:
	if _tutorial_toggle != null and FileAccess.file_exists(TUTORIAL_PATH):
		var tf := FileAccess.open(TUTORIAL_PATH, FileAccess.READ)
		if tf != null:
			var parsed = JSON.parse_string(tf.get_as_text())
			tf.close()
			if parsed is Dictionary:
				_tutorial_toggle.set_pressed_no_signal(not bool(parsed.get("completed", false)))

	if _lang_button != null:
		_lang_button.text = "ç¹é?ä¸­æ?" if TranslationServer.get_locale().begins_with("zh") else "English"

	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return

	for bus_name in ["Master", "Music", "SFX"]:
		var key = "volume_" + bus_name.to_lower()
		if data.has(key):
			var bus_idx := AudioServer.get_bus_index(bus_name)
			if bus_idx >= 0:
				var db_val := float(data[key])
				AudioServer.set_bus_volume_db(bus_idx, db_val)
				if _sliders.has(bus_name):
					(_sliders[bus_name] as HSlider).set_value_no_signal(db_val)

	if data.has("locale") and _lang_button != null:
		var locale := str(data["locale"])
		TranslationServer.set_locale(locale)
		_lang_button.text = "ç¹é?ä¸­æ?" if locale.begins_with("zh") else "English"

	if data.has("camera_zoom") and _zoom_slider != null:
		var zoom_value := float(data["camera_zoom"])
		_zoom_slider.set_value_no_signal(zoom_value)
		if _camera_ref != null and is_instance_valid(_camera_ref):
			_camera_ref.zoom = Vector2(zoom_value, zoom_value)


func _save_settings() -> void:
	var data: Dictionary = {}
	for bus_name in ["Master", "Music", "SFX"]:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			data["volume_" + bus_name.to_lower()] = AudioServer.get_bus_volume_db(bus_idx)
	data["locale"] = TranslationServer.get_locale()
	if _zoom_slider != null:
		data["camera_zoom"] = _zoom_slider.value
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

