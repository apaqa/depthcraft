extends Control

const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")

signal close_requested

@onready var recipe_list: ItemList = $PanelContainer/MarginContainer/HBoxContainer/RecipeList
@onready var detail_label: Label = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/DetailLabel
@onready var craft_button: Button = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/CraftButton
@onready var flash_rect: ColorRect = $FlashRect

var player_inventory = null
var player = null
var recipe_ids: PackedStringArray = []
var selected_recipe_id: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_pressed)


func open_for_player(target_player) -> void:
	player = target_player
	player_inventory = player.inventory if player != null else null
	visible = true
	_rebuild_recipe_list()
	if not recipe_ids.is_empty():
		recipe_list.select(0)
		_on_recipe_selected(0)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	release_focus()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_menu()
		get_viewport().set_input_as_handled()


func _rebuild_recipe_list() -> void:
	recipe_list.clear()
	recipe_ids.clear()
	for recipe in CRAFTING_SYSTEM.get_available_recipes():
		recipe_ids.append(str(recipe["id"]))
		recipe_list.add_item(str(recipe["name"]))


func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= recipe_ids.size():
		return
	selected_recipe_id = recipe_ids[index]
	_refresh_details()


func _refresh_details() -> void:
	if selected_recipe_id == "" or player_inventory == null:
		detail_label.text = ""
		craft_button.disabled = true
		return

	var recipe: Dictionary = CRAFTING_SYSTEM.get_recipe(selected_recipe_id)
	var cost_multiplier: float = player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0
	var cost := CRAFTING_SYSTEM.get_recipe_cost(selected_recipe_id, cost_multiplier)
	var lines: PackedStringArray = []
	lines.append(str(recipe.get("name", selected_recipe_id)))
	lines.append("")
	lines.append("Materials:")
	for resource_id in cost.keys():
		var required: int = int(cost[resource_id])
		var owned: int = player_inventory.get_item_count(resource_id)
		var marker := "[OK]" if owned >= required else "[X]"
		lines.append("%s %d/%d %s" % [marker, owned, required, _pretty_name(resource_id)])

	lines.append("")
	if recipe.get("result_type", "") == "equipment":
		lines.append("Stats:")
		for stat_id in recipe.get("stats", {}).keys():
			lines.append("%s: %s" % [_pretty_name(stat_id), str(recipe["stats"][stat_id])])
	else:
		lines.append("Effect:")
		for effect_id in recipe.get("effect", {}).keys():
			lines.append("%s: %s" % [_pretty_name(effect_id), str(recipe["effect"][effect_id])])

	detail_label.text = "\n".join(lines)
	craft_button.disabled = not CRAFTING_SYSTEM.can_craft(selected_recipe_id, player_inventory, cost_multiplier)


func _on_craft_pressed() -> void:
	if selected_recipe_id == "" or player_inventory == null:
		return
	var cost_multiplier: float = player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0
	if CRAFTING_SYSTEM.craft(selected_recipe_id, player_inventory, cost_multiplier):
		_refresh_details()
		_play_flash()


func _play_flash() -> void:
	flash_rect.color = Color(1, 1, 0.8, 0.0)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1, 1, 0.8, 0.25), 0.08)
	tween.tween_property(flash_rect, "color", Color(1, 1, 0.8, 0.0), 0.18)


func _pretty_name(value: String) -> String:
	return value.replace("_", " ").capitalize()
