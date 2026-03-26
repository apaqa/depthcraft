extends Control

const TITLE_FORMAT := "\u6210\u5c31\u89e3\u9501\uff1a%s"

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel

var _queue: Array[Dictionary] = []
var _playing: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)


func show_achievement(achievement: Dictionary) -> void:
	if achievement.is_empty():
		return
	_queue.append(achievement.duplicate(true))
	if not _playing:
		_play_next()


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		visible = false
		return
	_playing = true
	var achievement: Dictionary = _queue.pop_front()
	title_label.text = TITLE_FORMAT % str(achievement.get("name", ""))
	description_label.text = str(achievement.get("description", ""))
	visible = true
	modulate = Color(1, 1, 1, 0)
	position.y = -12.0
	if _active_tween != null:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	_active_tween.parallel().tween_property(self, "position:y", 12.0, 0.2)
	_active_tween.tween_interval(3.0)
	_active_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.35)
	_active_tween.parallel().tween_property(self, "position:y", -6.0, 0.35)
	_active_tween.tween_callback(_play_next)
