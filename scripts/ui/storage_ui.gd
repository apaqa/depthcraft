extends Control

signal close_requested

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@onready var panel_container: PanelContainer = $PanelContainer
@onready var player_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerGrid
@onready var chest_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ChestPanel/VBoxContainer/ChestGrid
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var player_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerLabel
@onready var chest_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ChestPanel/VBoxContainer/ChestLabel


var player_inventory = null
var chest_inventory = null
var player = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_close_button()


func open_for_storage(player_inv, chest_inv) -> void:
	player_inventory = player_inv
	chest_inventory = chest_inv
	player = player_inventory.get_parent() if player_inventory != null else null
	visible = true
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	_bind_inventory_signals()
	_rebuild()


func close_menu() -> void:
	if not visible:
		return
	_unbind_inventory_signals()
	visible = false
	if player != null and player.has_method("set_ui_blocked"):
		player.set_ui_blocked(false)
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
	title_label.text = LocaleManager.L("storage_title")
	player_label.text = LocaleManager.L("your_inventory")
	chest_label.text = LocaleManager.L("chest_label")
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
		var icon_holder := _build_item_icon_holder({})
		row.add_child(icon_holder)
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index < source_inventory.items.size():
			var stack: Dictionary = source_inventory.items[index]
			var item_name := ITEM_DATABASE.get_stack_display_name(stack)
			button.text = "%s x%d" % [item_name, int(stack["quantity"])]
			row.remove_child(icon_holder)
			icon_holder.queue_free()
			icon_holder = _build_item_icon_holder(stack)
			row.add_child(icon_holder)
			button.pressed.connect(_on_transfer_pressed.bind(source_inventory, target_inventory, index))
		else:
			button.text = LocaleManager.L("storage_empty_slot")
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


func _build_item_icon_holder(stack: Dictionary) -> Control:
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(stack)
	if icon != null:
		var icon_tex := TextureRect.new()
		icon_tex.custom_minimum_size = Vector2(16, 16)
		icon_tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_tex.texture = icon
		return icon_tex
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.color = ITEM_DATABASE.get_stack_color(stack) if not stack.is_empty() else Color(0.18, 0.18, 0.2, 1.0)
	return swatch


func _ensure_close_button() -> void:
	if get_node_or_null("CloseButton") != null:
		return
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.size = Vector2(32, 32)
	close_btn.position = panel_container.position + Vector2(8, 8)
	close_btn.z_index = 100
	close_btn.pressed.connect(close_menu)
	add_child(close_btn)
