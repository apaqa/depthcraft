extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@onready var player_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerGrid
@onready var chest_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ChestPanel/VBoxContainer/ChestGrid
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel

var player_inventory = null
var chest_inventory = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_for_storage(player_inv, chest_inv) -> void:
	player_inventory = player_inv
	chest_inventory = chest_inv
	visible = true
	_bind_inventory_signals()
	_rebuild()


func close_menu() -> void:
	if not visible:
		return
	_unbind_inventory_signals()
	visible = false
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_menu()
		get_viewport().set_input_as_handled()


func _bind_inventory_signals() -> void:
	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_rebuild):
		player_inventory.inventory_changed.connect(_rebuild)
	if chest_inventory != null and not chest_inventory.inventory_changed.is_connected(_rebuild):
		chest_inventory.inventory_changed.connect(_rebuild)


func _unbind_inventory_signals() -> void:
	if player_inventory != null and player_inventory.inventory_changed.is_connected(_rebuild):
		player_inventory.inventory_changed.disconnect(_rebuild)
	if chest_inventory != null and chest_inventory.inventory_changed.is_connected(_rebuild):
		chest_inventory.inventory_changed.disconnect(_rebuild)


func _rebuild() -> void:
	title_label.text = "Storage Chest"
	_rebuild_grid(player_grid, player_inventory, chest_inventory, true)
	_rebuild_grid(chest_grid, chest_inventory, player_inventory, false)


func _rebuild_grid(grid: GridContainer, source_inventory, target_inventory, from_player: bool) -> void:
	for child in grid.get_children():
		child.queue_free()

	if source_inventory == null:
		return

	for index in range(source_inventory.max_slots):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(120, 28)
		row.add_theme_constant_override("separation", 6)
		var icon_tex := TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(16, 16)
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_tex)
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index < source_inventory.items.size():
			var stack: Dictionary = source_inventory.items[index]
			button.text = "%s x%d" % [str(stack.get("name", stack["id"])), int(stack["quantity"])]
			var item_data := ITEM_DATABASE.get_item(str(stack.get("id", "")))
			icon_tex.texture = item_data.get("icon", null)
			button.pressed.connect(_on_transfer_pressed.bind(source_inventory, target_inventory, index))
		else:
			button.text = "--"
			button.disabled = true
		if from_player:
			button.modulate = Color(0.92, 1.0, 0.92, 1.0)
		else:
			button.modulate = Color(0.92, 0.95, 1.0, 1.0)
		row.add_child(button)
		grid.add_child(row)


func _on_transfer_pressed(source_inventory, target_inventory, stack_index: int) -> void:
	if source_inventory == null or target_inventory == null:
		return
	source_inventory.move_stack_to(target_inventory, stack_index)
