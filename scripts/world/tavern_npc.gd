extends Node2D
class_name TavernNpc

## Interactable NPC inside the tavern interior scene.
## The player's InteractionArea detects this node via its child Area2D.

var npc_type: String = ""
var prompt_text: String = ""


func get_interaction_prompt() -> String:
	return prompt_text


## Returns which tab this NPC should open in TavernUI.
func get_tavern_tab() -> String:
	if npc_type == "pachinko":
		return "pachinko"
	return "slots"


func interact(player: Node) -> void:
	if npc_type == "exit":
		var parent_node: Node = get_parent()
		if parent_node != null and parent_node.has_signal("exit_tavern_requested"):
			parent_node.exit_tavern_requested.emit()
		return
	if npc_type == "merchant":
		if player != null and player.has_method("show_status_message"):
			player.show_status_message(
				LocaleManager.L("tavern_npc_mystery_merchant"),
				Color(0.8, 0.5, 1.0, 1.0), 3.0
			)
		return
	if npc_type == "dark_wizard":
		if player != null and player.has_method("show_status_message"):
			player.show_status_message(
				LocaleManager.L("tavern_npc_dark_wizard"),
				Color(0.85, 0.55, 1.0, 1.0), 3.5
			)
		return
	if player != null and player.has_method("request_tavern_menu"):
		player.request_tavern_menu(self)
