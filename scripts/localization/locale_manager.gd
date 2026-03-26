extends Node

signal locale_changed(new_locale: String)

var _locale: String = "zh"
var _strings: Dictionary = {}

func _ready() -> void:
	load_locale(_locale)


func load_locale(locale: String) -> void:
	var path := "res://locale/%s.json" % locale
	if not FileAccess.file_exists(path):
		printerr("Locale file not found: ", path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		_strings = json.data
		_locale = locale
		print("Loaded locale: ", locale)
	else:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())


func L(key: String) -> String:
	return _strings.get(key, key)


func set_locale(locale: String) -> void:
	if locale == "":
		return
	load_locale(locale)
	locale_changed.emit(locale)


func get_locale() -> String:
	return _locale
