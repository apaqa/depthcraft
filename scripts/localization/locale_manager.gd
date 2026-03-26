extends Node

signal locale_changed

var _strings: Dictionary = {}
var _locale: String = "zh"


func _ready() -> void:
	var saved := _load_saved_locale()
	_load_locale(saved if not saved.is_empty() else "zh")


func _load_saved_locale() -> String:
	var path := "user://settings.json"
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary and data.has("locale"):
		return str(data["locale"])
	return ""


func _load_locale(locale: String) -> void:
	var path := "res://locale/%s.json" % locale
	if not FileAccess.file_exists(path):
		push_warning("LocaleManager: locale file not found: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_strings = parsed
		_locale = locale


func tr(key: String) -> String:
	return _strings.get(key, key)


func set_locale(locale: String) -> void:
	if locale == _locale:
		return
	_load_locale(locale)
	locale_changed.emit()


func get_locale() -> String:
	return _locale
