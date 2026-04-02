extends Node

# Tracks which monsters have been shown their first-encounter text this session.
# Resets each game session so returning players still get a reminder.
var _shown_this_session: Dictionary = {}


func check_first_encounter(enemy_kind: String) -> void:
	if enemy_kind == "":
		return
	if _shown_this_session.has(enemy_kind):
		return
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex == null or not codex.has_method("get_monster_entry"):
		_show_if_hud_ready(enemy_kind)
		return
	var entry: Dictionary = codex.get_monster_entry(enemy_kind)
	if int(entry.get("seen", 0)) > 0:
		return
	_shown_this_session[enemy_kind] = true
	_show_if_hud_ready(enemy_kind)


func _show_if_hud_ready(enemy_kind: String) -> void:
	call_deferred("_trigger_encounter_text", enemy_kind)


func _trigger_encounter_text(enemy_kind: String) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var hud: Node = scene_root.get_node_or_null("HUDCanvas/HUD")
	if hud == null or not hud.has_method("show_encounter_text"):
		return
	var name_key: String = "encounter_" + enemy_kind
	var desc_key: String = "encounter_" + enemy_kind + "_desc"
	var monster_name: String = LocaleManager.L(name_key)
	var description: String = LocaleManager.L(desc_key)
	hud.show_encounter_text(monster_name, description)
