extends Node

const SAVE_PATH := "user://class_save.json"

const CLASS_DEFS := {
	"warrior": {
		"id": "warrior",
		"name_key": "class_warrior_name",
		"desc_key": "class_warrior_desc",
		"hp_mult": 1.3,
		"atk_mult": 1.2,
		"spd_mult": 0.9,
		"cd_mult": 1.0,
	},
	"mage": {
		"id": "mage",
		"name_key": "class_mage_name",
		"desc_key": "class_mage_desc",
		"hp_mult": 0.9,
		"atk_mult": 1.1,
		"spd_mult": 1.0,
		"cd_mult": 0.7,
	},
	"ranger": {
		"id": "ranger",
		"name_key": "class_ranger_name",
		"desc_key": "class_ranger_desc",
		"hp_mult": 1.0,
		"atk_mult": 1.1,
		"spd_mult": 1.2,
		"cd_mult": 1.0,
	},
}

var current_class_id: String = ""


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		current_class_id = str(data.get("class_id", ""))


func save_class(class_id: String) -> void:
	current_class_id = class_id
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"class_id": class_id}))
	file.close()


func has_chosen_class() -> bool:
	return current_class_id != "" and CLASS_DEFS.has(current_class_id)


func get_class_def() -> Dictionary:
	if not has_chosen_class():
		return {}
	return (CLASS_DEFS[current_class_id] as Dictionary).duplicate(true)


func get_cd_multiplier() -> float:
	var def := get_class_def()
	if def.is_empty():
		return 1.0
	return float(def.get("cd_mult", 1.0))


func get_class_display_name() -> String:
	var def := get_class_def()
	if def.is_empty():
		return ""
	return LocaleManager.L(str(def.get("name_key", "")))


func apply_to_stats(player_stats) -> void:
	if not has_chosen_class():
		return
	var def := get_class_def()
	var hp_mult: float = float(def.get("hp_mult", 1.0))
	var atk_mult: float = float(def.get("atk_mult", 1.0))
	var spd_mult: float = float(def.get("spd_mult", 1.0))
	player_stats.base_max_hp = int(round(float(player_stats.base_max_hp) * hp_mult))
	player_stats.base_attack = int(round(float(player_stats.base_attack) * atk_mult))
	player_stats.base_speed = player_stats.base_speed * spd_mult
