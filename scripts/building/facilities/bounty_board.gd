extends "res://scripts/building/building_base.gd"
class_name BountyBoardFacility

## BountyBoard — out-of-dungeon facility.
## Place it in the overworld base; the player presses E to open the quest board.
##
## To wire into BuildingData add an entry like:
##   "bounty_board": {
##       "id": "bounty_board", "name": "bounty_board",
##       "category": "facility", "kind": "scene",
##       "cost": {"wood": 8, "stone": 4},
##       "scene": BOUNTY_BOARD_SCENE_PATH,
##       "base_max_hp": 60,
##   }

const INTERACTION_PROMPT: String = "[E] Quest Board"


func get_interaction_prompt() -> String:
	return INTERACTION_PROMPT


func interact(player) -> void:
	if player == null:
		return
	# Preferred: player exposes open_quest_board() so it can handle UI focus.
	if player.has_method("open_quest_board"):
		player.open_quest_board(self)
		return
	# Fallback: ask QuestManager to relay via its board_open_requested signal.
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("request_open_board"):
		qm.request_open_board(player)


func requires_home_core() -> bool:
	return true


# ---------------------------------------------------------------------------
# Serialisation (no extra state beyond base HP)
# ---------------------------------------------------------------------------

func _serialize_extra_state() -> Dictionary:
	return {}


func _load_extra_state(_data: Dictionary) -> void:
	pass
