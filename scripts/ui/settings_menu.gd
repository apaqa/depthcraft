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


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "設定 / Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# --- Volume ---
	_add_section_label(vbox, "音量 / Volume")
	_add_bus_slider(vbox, "Master", "主音量")
	_add_bus_slider(vbox, "Music", "BGM")
	_add_bus_slider(vbox, "SFX", "音效")
	vbox.add_child(HSeparator.new())

	# --- Language ---
	_add_section_label(vbox, "語言 / Language")
	var lang_row := HBoxContainer.new()
	var lang_label := Label.new()
	lang_label.text = "語言 / Language:"
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)
	_lang_button = Button.new()
	_lang_button.text = "中文"
	_lang_button.custom_minimum_size = Vector2(80, 0)
	_lang_button.pressed.connect(_on_lang_toggle)
	lang_row.add_child(_lang_button)
	vbox.add_child(lang_row)
	vbox.add_child(HSeparator.new())

	# --- Camera zoom ---
	_add_section_label(vbox, "視角 / View")
	var zoom_row := HBoxContainer.new()
	var zoom_label := Label.new()
	zoom_label.text = "視角高度:"
	zoom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_label)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 1.5
	_zoom_slider.max_value = 3.0
	_zoom_slider.step = 0.1
	_zoom_slider.value = 2.0
	_zoom_slider.custom_minimum_size = Vector2(140, 0)
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	zoom_row.add_child(_zoom_slider)
	vbox.add_child(zoom_row)
	vbox.add_child(HSeparator.new())

	# --- Tutorial toggle ---
	_add_section_label(vbox, "新手提示 / Tutorial")
	var tut_row := HBoxContainer.new()
	var tut_label := Label.new()
	tut_label.text = "顯示新手提示:"
	tut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_row.add_child(tut_label)
	_tutorial_toggle = CheckButton.new()
	_tutorial_toggle.toggled.connect(_on_tutorial_toggled)
	tut_row.add_child(_tutorial_toggle)
	vbox.add_child(tut_row)
	vbox.add_child(HSeparator.new())

	# --- Close button ---
	var close_btn := Button.new()
	close_btn.text = "關閉 / Close  [Esc]"
	close_btn.pressed.connect(close_menu)
	vbox.add_child(close_btn)


func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.self_modulate = Color(0.9, 0.85, 0.55, 1.0)
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)


func _add_bus_slider(parent: Control, bus_name: String, display_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = display_name + ":"
	label.custom_minimum_size = Vector2(60, 0)
	row.add_child(label)
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
	visible = true


func close_menu() -> void:
	if not visible:
		return
	_save_settings()
	visible = false
	close_requested.emit()


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
		_lang_button.text = "中文"


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
	# Tutorial toggle from tutorial_save.json
	if _tutorial_toggle != null and FileAccess.file_exists(TUTORIAL_PATH):
		var tf := FileAccess.open(TUTORIAL_PATH, FileAccess.READ)
		if tf != null:
			var parsed = JSON.parse_string(tf.get_as_text())
			tf.close()
			if parsed is Dictionary:
				_tutorial_toggle.set_pressed_no_signal(not bool(parsed.get("completed", false)))

	if not FileAccess.file_exists(SETTINGS_PATH):
		# Reflect current locale
		if _lang_button != null:
			_lang_button.text = "中文" if TranslationServer.get_locale().begins_with("zh") else "English"
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return

	for bus_name in ["Master", "Music", "SFX"]:
		var key := "volume_" + bus_name.to_lower()
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
		_lang_button.text = "中文" if locale.begins_with("zh") else "English"
	elif _lang_button != null:
		_lang_button.text = "中文" if TranslationServer.get_locale().begins_with("zh") else "English"

	if data.has("camera_zoom") and _zoom_slider != null:
		_zoom_slider.set_value_no_signal(float(data["camera_zoom"]))


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
