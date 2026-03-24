extends Control

@onready var detail_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DetailLabel

var player_inventory = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_for_player(inventory) -> void:
	player_inventory = inventory
	visible = true
	_refresh()


func close_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if player_inventory == null:
		detail_label.text = "No items available."
		return

	var lines: PackedStringArray = []
	lines.append("Repair Bench")
	lines.append("Phase 4 framework")
	lines.append("")
	var found_equipment := false
	for stack in player_inventory.items:
		if str(stack.get("type", "")) != "equipment":
			continue
		found_equipment = true
		var durability := int(stack.get("durability", 0))
		var max_durability := int(stack.get("max_durability", 0))
		lines.append("%s %d/%d" % [str(stack.get("name", stack["id"])), durability, max_durability])

	if not found_equipment:
		lines.append("No equipped or crafted gear yet.")
		lines.append("Repair costs and durability logic will plug in here later.")

	detail_label.text = "\n".join(lines)
