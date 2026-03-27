extends Node

## QuestManager — AutoLoad
## Generates procedural bounty quests, tracks progress, and handles turn-in.
##
## Other systems call:
##   QuestManager.update_quest_progress("kill_enemies", "skeleton", 1)
##   QuestManager.update_quest_progress("collect_items", "wood", 5)
##   QuestManager.update_quest_progress("reach_floor", "", 7)

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal quest_accepted(quest_id: String)
signal quest_progress_updated(quest_id: String, progress: int, goal: int)
signal quest_completed(quest_id: String)
signal quest_turned_in(quest_id: String)
## Emitted when a bounty board building calls request_open_board().
## QuestBoardUI connects to this to show itself.
signal board_open_requested(player: Node)

# ---------------------------------------------------------------------------
# Quest type constants
# ---------------------------------------------------------------------------

const TYPE_KILL: String = "kill_enemies"
const TYPE_COLLECT: String = "collect_items"
const TYPE_REACH_FLOOR: String = "reach_floor"

const MAX_AVAILABLE_QUESTS: int = 3
const SAVE_PATH: String = "user://quests.json"

## Enemy target IDs → display names
const KILL_TARGETS: Dictionary = {
	"skeleton":   "Skeletons",
	"goblin":     "Goblins",
	"zombie":     "Zombies",
	"spider":     "Spiders",
	"slime":      "Slimes",
	"bat":        "Bats",
}

## Collectible item IDs → display names
const COLLECT_TARGETS: Dictionary = {
	"wood":     "Wood",
	"stone":    "Stone",
	"iron_ore": "Iron Ore",
	"herb":     "Herbs",
	"bone":     "Bones",
	"coal":     "Coal",
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _available_quests: Array[Dictionary] = []
var _active_quests: Array[Dictionary] = []
var _turned_in_ids: Array[String] = []
var _current_day: int = 1
var _id_counter: int = 0

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load()
	if _available_quests.is_empty():
		generate_available_quests(_current_day)


# ---------------------------------------------------------------------------
# Public API — generation
# ---------------------------------------------------------------------------

## Set the current in-game day so difficulty scales correctly.
func set_day(day: int) -> void:
	_current_day = maxi(1, day)


## Regenerate the pool of available quests shown on the board.
## Call this on a new day or after a full board refresh.
func generate_available_quests(day: int) -> void:
	_current_day = maxi(1, day)
	_available_quests.clear()
	for slot: int in range(MAX_AVAILABLE_QUESTS):
		_available_quests.append(_generate_quest(_current_day, slot))
	_save()


func _generate_quest(day: int, slot: int) -> Dictionary:
	_id_counter += 1
	var quest_id: String = "quest_%d_%d" % [day, _id_counter]

	# Difficulty 1-5, scales every 4 days; slot offset adds variety
	var difficulty: int = clampi(1 + (day - 1) / 4 + slot % 2, 1, 5)

	var all_types: Array[String] = [TYPE_KILL, TYPE_COLLECT, TYPE_REACH_FLOOR]
	var type: String = all_types[randi() % all_types.size()]

	var target_id: String = ""
	var title: String = ""
	var description: String = ""
	var goal: int = 1
	var reward_gold: int = 0
	var reward_shards: int = 0

	match type:
		TYPE_KILL:
			var keys: Array = KILL_TARGETS.keys()
			target_id = str(keys[randi() % keys.size()])
			var enemy_name: String = str(KILL_TARGETS.get(target_id, target_id))
			goal = 5 + difficulty * 5 + randi() % (difficulty * 3 + 1)
			title = "Slay %d %s" % [goal, enemy_name]
			description = "Eliminate %d %s lurking in the dungeon." % [goal, enemy_name]
			reward_gold = difficulty * 20 + randi() % (difficulty * 10 + 5)
			reward_shards = difficulty * 2 + randi() % 3

		TYPE_COLLECT:
			var keys: Array = COLLECT_TARGETS.keys()
			target_id = str(keys[randi() % keys.size()])
			var item_name: String = str(COLLECT_TARGETS.get(target_id, target_id))
			goal = 10 + difficulty * 10 + randi() % (difficulty * 5 + 1)
			title = "Gather %d %s" % [goal, item_name]
			description = "Collect %d units of %s from the world." % [goal, item_name]
			reward_gold = difficulty * 15 + randi() % (difficulty * 8 + 5)
			reward_shards = difficulty + randi() % 3

		TYPE_REACH_FLOOR:
			goal = clampi(2 + difficulty * 2 + randi() % 3, 2, 20)
			title = "Reach Floor %d" % goal
			description = "Descend to dungeon floor %d." % goal
			reward_gold = difficulty * 30 + randi() % (difficulty * 15 + 10)
			reward_shards = difficulty * 3 + randi() % 4

	return {
		"id":           quest_id,
		"type":         type,
		"target_id":    target_id,
		"goal":         goal,
		"progress":     0,
		"reward_gold":  reward_gold,
		"reward_shards": reward_shards,
		"title":        title,
		"description":  description,
		"difficulty":   difficulty,
		"completed":    false,
		"turned_in":    false,
	}


# ---------------------------------------------------------------------------
# Public API — player actions
# ---------------------------------------------------------------------------

## Move a quest from available → active. Returns false if already accepted or
## not found.
func accept_quest(quest_id: String) -> bool:
	for i: int in range(_available_quests.size()):
		var q: Dictionary = _available_quests[i]
		if str(q.get("id", "")) != quest_id:
			continue
		_active_quests.append(q.duplicate(true))
		_available_quests.remove_at(i)
		quest_accepted.emit(quest_id)
		_save()
		return true
	return false


## Push progress to every matching active quest.
## type     — one of TYPE_KILL / TYPE_COLLECT / TYPE_REACH_FLOOR
## target_id — enemy or item id; pass "" for reach_floor
## amount   — units gained (for floor: pass current floor number)
func update_quest_progress(type: String, target_id: String, amount: int) -> void:
	var changed: bool = false
	for q: Dictionary in _active_quests:
		if bool(q.get("completed", false)):
			continue
		if str(q.get("type", "")) != type:
			continue
		if type != TYPE_REACH_FLOOR and str(q.get("target_id", "")) != target_id:
			continue

		var goal: int = int(q.get("goal", 1))
		var old_progress: int = int(q.get("progress", 0))
		var new_progress: int = old_progress

		if type == TYPE_REACH_FLOOR:
			# Progress = deepest floor reached (max, not cumulative)
			new_progress = maxi(old_progress, amount)
		else:
			new_progress = mini(old_progress + amount, goal)

		if new_progress == old_progress:
			continue

		q["progress"] = new_progress
		changed = true
		quest_progress_updated.emit(str(q.get("id", "")), new_progress, goal)

		if new_progress >= goal and not bool(q.get("completed", false)):
			q["completed"] = true
			quest_completed.emit(str(q.get("id", "")))

	if changed:
		_save()


## Award rewards and remove the quest from active list.
## Returns false if the quest is not found or not yet completed.
func turn_in_quest(quest_id: String, player: Node) -> bool:
	for i: int in range(_active_quests.size()):
		var q: Dictionary = _active_quests[i]
		if str(q.get("id", "")) != quest_id:
			continue
		if not bool(q.get("completed", false)):
			return false

		var gold: int = int(q.get("reward_gold", 0))
		var shards: int = int(q.get("reward_shards", 0))
		if player != null:
			if gold > 0 and player.has_method("add_currency"):
				player.add_currency(gold)
			if shards > 0 and player.has_method("add_shards"):
				player.add_shards(shards)

		q["turned_in"] = true
		_turned_in_ids.append(quest_id)
		_active_quests.remove_at(i)
		quest_turned_in.emit(quest_id)
		_save()
		return true
	return false


## Called by BountyBoardFacility.interact(); raises board_open_requested so
## QuestBoardUI can show itself without either script knowing about the other.
func request_open_board(player: Node) -> void:
	board_open_requested.emit(player)


# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------

func get_available_quests() -> Array[Dictionary]:
	return _available_quests.duplicate(true)


func get_active_quests() -> Array[Dictionary]:
	return _active_quests.duplicate(true)


func get_active_quest_by_id(quest_id: String) -> Dictionary:
	for q: Dictionary in _active_quests:
		if str(q.get("id", "")) == quest_id:
			return q.duplicate(true)
	return {}


func is_quest_completed(quest_id: String) -> bool:
	for q: Dictionary in _active_quests:
		if str(q.get("id", "")) == quest_id:
			return bool(q.get("completed", false))
	return false


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save() -> void:
	var data: Dictionary = {
		"day":       _current_day,
		"counter":   _id_counter,
		"available": _available_quests,
		"active":    _active_quests,
		"turned_in": _turned_in_ids,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed as Dictionary

	_current_day = int(data.get("day", 1))
	_id_counter = int(data.get("counter", 0))

	var avail_raw: Variant = data.get("available", [])
	if avail_raw is Array:
		_available_quests.clear()
		for entry: Variant in (avail_raw as Array):
			if entry is Dictionary:
				_available_quests.append(entry as Dictionary)

	var active_raw: Variant = data.get("active", [])
	if active_raw is Array:
		_active_quests.clear()
		for entry: Variant in (active_raw as Array):
			if entry is Dictionary:
				_active_quests.append(entry as Dictionary)

	var turned_raw: Variant = data.get("turned_in", [])
	if turned_raw is Array:
		_turned_in_ids.clear()
		for entry: Variant in (turned_raw as Array):
			_turned_in_ids.append(str(entry))
