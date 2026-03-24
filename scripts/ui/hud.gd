extends Control

@onready var hp_label: Label = $HPLabel
@onready var bag_label: Label = $BagLabel
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var inventory_grid: GridContainer = $InventoryPanel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var build_hud: Control = $BuildHUD
@onready var debug_label: Label = $DebugLabel

var player = null
var inventory = null


func _ready() -> void:
	update_hp(100, 100)
	update_bag_label(0, 20)
	inventory_panel.visible = false


func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current, max_hp]


func bind_player(new_player) -> void:
	if player != null:
		if player.interaction_prompt_changed.is_connected(show_interaction_prompt):
			player.interaction_prompt_changed.disconnect(show_interaction_prompt)
		if player.interaction_prompt_cleared.is_connected(hide_interaction_prompt):
			player.interaction_prompt_cleared.disconnect(hide_interaction_prompt)
		if player.inventory.inventory_changed.is_connected(_on_inventory_changed):
			player.inventory.inventory_changed.disconnect(_on_inventory_changed)
		if player.building_system.build_state_changed.is_connected(_refresh_debug_label):
			player.building_system.build_state_changed.disconnect(_refresh_debug_label)

	player = new_player
	inventory = player.inventory
	player.interaction_prompt_changed.connect(show_interaction_prompt)
	player.interaction_prompt_cleared.connect(hide_interaction_prompt)
	inventory.inventory_changed.connect(_on_inventory_changed)
	player.building_system.build_state_changed.connect(_refresh_debug_label)
	if build_hud.has_method("bind_system"):
		build_hud.bind_system(player.building_system, inventory)
	_on_inventory_changed()
	_refresh_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and inventory_panel.visible:
		inventory_panel.visible = false
		get_viewport().set_input_as_handled()


func toggle_inventory_panel() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		rebuild_inventory_grid()


func show_interaction_prompt(prompt_text: String) -> void:
	if interaction_prompt.has_method("show_prompt"):
		interaction_prompt.show_prompt(prompt_text)
	else:
		interaction_prompt.text = prompt_text
		interaction_prompt.visible = true


func hide_interaction_prompt() -> void:
	if interaction_prompt.has_method("hide_prompt"):
		interaction_prompt.hide_prompt()
	else:
		interaction_prompt.text = ""
		interaction_prompt.visible = false


func _on_inventory_changed() -> void:
	if inventory == null:
		return

	update_bag_label(inventory.items.size(), inventory.max_slots)
	rebuild_inventory_grid()


func update_bag_label(used_slots: int, max_slots: int) -> void:
	bag_label.text = "Bag: %d/%d slots" % [used_slots, max_slots]


func _refresh_debug_label() -> void:
	if player == null:
		debug_label.visible = false
		return

	debug_label.visible = player.building_system.is_debug_mode_enabled()


func rebuild_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	if inventory == null:
		return

	for index in range(inventory.max_slots):
		var slot := _build_slot(index)
		inventory_grid.add_child(slot)


func _build_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(48, 48)
	slot.self_modulate = Color(0.18, 0.18, 0.22, 0.95)

	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.position = Vector2(8, 6)
	icon_rect.size = Vector2(32, 24)
	slot.add_child(icon_rect)

	var quantity_label := Label.new()
	quantity_label.position = Vector2(6, 24)
	quantity_label.size = Vector2(36, 20)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slot.add_child(quantity_label)

	if index < inventory.items.size():
		var stack: Dictionary = inventory.items[index]
		icon_rect.texture = stack.get("icon", null)
		quantity_label.text = "x%d" % stack["quantity"]
		quantity_label.tooltip_text = stack["name"]
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.28, 0.28, 0.32, 0.55)
		placeholder.position = Vector2(8, 8)
		placeholder.size = Vector2(32, 20)
		slot.add_child(placeholder)
		slot.move_child(placeholder, 0)
		quantity_label.text = ""

	return slot
