extends Control

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var cost_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CostLabel
@onready var help_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HelpLabel
@onready var core_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CoreLabel

var building_system = null
var inventory = null


func bind_system(new_building_system, new_inventory) -> void:
	if building_system != null and building_system.build_state_changed.is_connected(refresh):
		building_system.build_state_changed.disconnect(refresh)
	if inventory != null and inventory.inventory_changed.is_connected(refresh):
		inventory.inventory_changed.disconnect(refresh)

	building_system = new_building_system
	inventory = new_inventory

	if building_system != null:
		building_system.build_state_changed.connect(refresh)
	if inventory != null:
		inventory.inventory_changed.connect(refresh)

	refresh()


func refresh() -> void:
	if building_system == null:
		visible = false
		return

	var state: Dictionary = building_system.get_ui_state()
	visible = bool(state.get("build_mode", false))
	if not visible:
		return

	if bool(state.get("remove_mode", false)):
		title_label.text = "Remove Mode"
		cost_label.text = "Click a placed tile to reclaim 50% resources"
		cost_label.modulate = Color(1.0, 0.7, 0.45, 1.0)
	else:
		var building: Dictionary = state.get("building", {})
		title_label.text = str(building.get("name", "Build"))
		cost_label.text = _format_costs(building.get("cost", {}))
		cost_label.modulate = Color(0.45, 1.0, 0.45, 1.0) if bool(state.get("can_afford", false)) else Color(1.0, 0.45, 0.45, 1.0)

	core_label.text = "Core: placed" if bool(state.get("has_core", false)) else "Core: press C (10 Wood, 5 Stone)"
	help_label.text = "[LMB] Place  [RMB] Remove  [Scroll] Switch  [B] Exit"


func _format_costs(costs: Dictionary) -> String:
	if inventory == null:
		return ""

	var parts: PackedStringArray = []
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		var owned: int = inventory.get_item_count(resource_id)
		parts.append("%d/%d %s" % [owned, amount, _pretty_name(resource_id)])
	return "Cost: %s" % ", ".join(parts)


func _pretty_name(resource_id: String) -> String:
	return resource_id.replace("_", " ").capitalize()
