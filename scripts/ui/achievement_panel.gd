extends Control

signal close_requested

const LABEL_DESCRIPTION := "\u63cf\u8ff0\uff1a%s"
const LABEL_STATUS_UNLOCKED := "\u72b6\u6001\uff1a\u5df2\u89e3\u9501"
const LABEL_STATUS_LOCKED := "\u72b6\u6001\uff1a\u672a\u89e3\u9501"
const TITLE_TEXT := "\u6210\u5c31\u603b\u89c8"
const HINT_TEXT := "\u6309 J \u6216 Esc \u5173\u95ed"

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HintLabel
@onready var list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ListContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = TITLE_TEXT
	hint_label.text = HINT_TEXT
	_ensure_close_button()


func open_panel() -> void:
	visible = true
	rebuild()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	release_focus()
	close_requested.emit()


func rebuild() -> void:
	for child in list_container.get_children():
		child.queue_free()
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager == null:
		return
	for achievement in achievement_manager.get_achievement_list():
		list_container.add_child(_build_row(achievement))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_achievements"):
		close_panel()
		get_viewport().set_input_as_handled()


func _build_row(achievement: Dictionary) -> Control:
	var unlocked := bool(achievement.get("unlocked", false))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.self_modulate = Color(1.0, 1.0, 1.0, 1.0) if unlocked else Color(0.45, 0.45, 0.45, 1.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var name_label := Label.new()
	name_label.text = str(achievement.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.self_modulate = Color(1.0, 0.9, 0.45, 1.0) if unlocked else Color(0.8, 0.8, 0.8, 1.0)
	box.add_child(name_label)

	var description_label := Label.new()
	description_label.text = LABEL_DESCRIPTION % str(achievement.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description_label)

	var reward_label := Label.new()
	reward_label.text = str(achievement.get("reward", ""))
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.self_modulate = Color(0.7, 0.95, 0.7, 1.0) if unlocked else Color(0.65, 0.65, 0.65, 1.0)
	box.add_child(reward_label)

	var status_label := Label.new()
	status_label.text = LABEL_STATUS_UNLOCKED if unlocked else LABEL_STATUS_LOCKED
	status_label.self_modulate = Color(1.0, 0.95, 0.55, 1.0) if unlocked else Color(0.6, 0.6, 0.6, 1.0)
	box.add_child(status_label)

	return panel


func _ensure_close_button() -> void:
	if panel_container == null or panel_container.get_node_or_null("CloseButton") != null:
		return
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(8.0, 8.0)
	close_button.custom_minimum_size = Vector2(28.0, 28.0)
	close_button.pressed.connect(close_panel)
	panel_container.add_child(close_button)
