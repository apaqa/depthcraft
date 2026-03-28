extends Node

const SAVE_PATH: String = "user://codex_data.json"

# monsters: { enemy_kind -> { "seen": int, "killed": int } }
var monsters: Dictionary = {}
# items: { item_id -> { "seen": int } }
var items: Dictionary = {}


func _ready() -> void:
	_load_data()


func record_enemy_seen(enemy_kind: String) -> void:
	if enemy_kind == "":
		return
	if not monsters.has(enemy_kind):
		monsters[enemy_kind] = {"seen": 0, "killed": 0}
	var entry: Dictionary = monsters[enemy_kind] as Dictionary
	entry["seen"] = int(entry.get("seen", 0)) + 1
	monsters[enemy_kind] = entry


func record_enemy_killed(enemy_kind: String) -> void:
	if enemy_kind == "":
		return
	if not monsters.has(enemy_kind):
		monsters[enemy_kind] = {"seen": 0, "killed": 0}
	var entry: Dictionary = monsters[enemy_kind] as Dictionary
	entry["killed"] = int(entry.get("killed", 0)) + 1
	monsters[enemy_kind] = entry


func record_item_seen(item_id: String) -> void:
	if item_id == "":
		return
	if not items.has(item_id):
		items[item_id] = {"seen": 0}
	var entry: Dictionary = items[item_id] as Dictionary
	entry["seen"] = int(entry.get("seen", 0)) + 1
	items[item_id] = entry


func get_monster_entry(enemy_kind: String) -> Dictionary:
	if not monsters.has(enemy_kind):
		return {}
	return (monsters[enemy_kind] as Dictionary).duplicate(true)


func get_item_entry(item_id: String) -> Dictionary:
	if not items.has(item_id):
		return {}
	return (items[item_id] as Dictionary).duplicate(true)


func get_all_monster_kinds() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in monsters.keys():
		result.append(str(key))
	result.sort()
	return result


func get_all_item_ids() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in items.keys():
		result.append(str(key))
	result.sort()
	return result


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed as Dictionary
	var raw_monsters: Variant = data.get("monsters", {})
	if typeof(raw_monsters) == TYPE_DICTIONARY:
		monsters = raw_monsters as Dictionary
	var raw_items: Variant = data.get("items", {})
	if typeof(raw_items) == TYPE_DICTIONARY:
		items = raw_items as Dictionary


func save_data() -> void:
	var data: Dictionary = {"monsters": monsters, "items": items}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
