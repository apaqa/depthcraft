extends Node

const CYCLE_SAVE_PATH: String = "user://cycle_data.json"

var current_cycle: int = 1
var total_victories: int = 0


func _ready() -> void:
	_load()


func get_enemy_scale() -> float:
	return 1.0 + float(current_cycle - 1) * 0.5


func is_prefix_enabled() -> bool:
	return current_cycle >= 2


func advance_cycle() -> void:
	current_cycle += 1
	total_victories += 1
	var bs: Node = get_node_or_null("/root/BlessingSystem")
	if bs != null and bs.has_method("clear_all"):
		bs.call("clear_all")
	var cm: Node = get_node_or_null("/root/CycleModifier")
	if cm != null and cm.has_method("advance_cycle"):
		cm.call("advance_cycle")
	_save()


func reset() -> void:
	current_cycle = 1
	total_victories = 0
	_save()


func _save() -> void:
	var data: Dictionary = {
		"current_cycle": current_cycle,
		"total_victories": total_victories,
	}
	var file: FileAccess = FileAccess.open(CYCLE_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(CYCLE_SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(CYCLE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return
	var data: Dictionary = json.data as Dictionary
	current_cycle = int(data.get("current_cycle", 1))
	total_victories = int(data.get("total_victories", 0))
