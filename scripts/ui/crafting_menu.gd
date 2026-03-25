extends Control

const CRAFTING_SYSTEM := preload("res://scripts/crafting/crafting_system.gd")

signal close_requested

@onready var recipe_list_container: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/RecipePanel/RecipeScroll/RecipeListContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/TitleLabel
@onready var detail_text: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/DetailText
@onready var craft_button: Button = $PanelContainer/MarginContainer/HBoxContainer/DetailPanel/VBoxContainer/CraftButton
@onready var flash_rect: ColorRect = $FlashRect

var player_inventory = null
var player = null
var recipe_ids: PackedStringArray = []
var selected_recipe_id: String = ""
var filtered_recipe_ids: PackedStringArray = []
var menu_title: String = "Crafting"


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	craft_button.pressed.connect(_on_craft_pressed)


func open_for_player(target_player, available_recipe_ids: PackedStringArray = PackedStringArray(), title: String = "Crafting") -> void:
	player = target_player
	player_inventory = player.inventory if player != null else null
	filtered_recipe_ids = available_recipe_ids
	menu_title = title
	visible = true
	_rebuild_recipe_list()
	if not recipe_ids.is_empty():
		_on_recipe_button_pressed(recipe_ids[0])


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
	for child in recipe_list_container.get_children():
		child.queue_free()
	recipe_ids.clear()
	title_label.text = menu_title
	var recipes: Array[Dictionary] = CRAFTING_SYSTEM.get_available_recipes_for_ids(filtered_recipe_ids) if not filtered_recipe_ids.is_empty() else CRAFTING_SYSTEM.get_available_recipes()
	var grouped: Dictionary = {}
	for recipe in recipes:
		var category := str(recipe.get("category", "Crafting"))
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(recipe)
	var category_names := grouped.keys()
	category_names.sort()
	for category_name in category_names:
		var header := Label.new()
		header.text = "=== %s ===" % category_name
		header.modulate = Color(0.95, 0.9, 0.65, 1.0)
		recipe_list_container.add_child(header)
		for recipe in grouped[category_name]:
			var recipe_id := str(recipe["id"])
			recipe_ids.append(recipe_id)
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = "%s (%s)" % [str(recipe["name"]), _format_cost_summary(recipe_id)]
			button.pressed.connect(_on_recipe_button_pressed.bind(recipe_id))
			recipe_list_container.add_child(button)


func _on_recipe_button_pressed(recipe_id: String) -> void:
	selected_recipe_id = recipe_id
	_refresh_details()

func _refresh_details() -> void:
	if selected_recipe_id == "" or player_inventory == null:
		detail_text.text = ""
		craft_button.disabled = true
		return

	var recipe: Dictionary = CRAFTING_SYSTEM.get_recipe(selected_recipe_id)
	var cost_multiplier: float = player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0
	var cost := CRAFTING_SYSTEM.get_recipe_cost(selected_recipe_id, cost_multiplier)
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % str(recipe.get("name", selected_recipe_id)))
	if recipe.get("result_type", "") == "equipment":
		for stat_id in recipe.get("stats", {}).keys():
			lines.append("%s: +%s" % [_pretty_name(stat_id), str(recipe["stats"][stat_id])])
		if recipe.has("max_durability"):
			lines.append("Durability: %d/%d" % [int(recipe.get("durability", recipe.get("max_durability", 0))), int(recipe.get("max_durability", 0))])
		if recipe.has("slot"):
			lines.append("Slot: %s" % _pretty_name(str(recipe.get("slot", ""))))
	else:
		for effect_id in recipe.get("effect", {}).keys():
			lines.append("%s: %s" % [_pretty_name(effect_id), str(recipe["effect"][effect_id])])
	lines.append("")
	lines.append("[b]Materials:[/b]")
	for resource_id in cost.keys():
		var required: int = int(cost[resource_id])
		var owned: int = player_inventory.get_item_count(resource_id)
		var color_tag := "green" if owned >= required else "red"
		var suffix := " [color=green]OK[/color]" if owned >= required else ""
		lines.append("[color=%s]%s: %d/%d%s[/color]" % [color_tag, _pretty_name(resource_id), owned, required, suffix])

	detail_text.bbcode_enabled = true
	detail_text.text = "\n".join(lines)
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


func _format_cost_summary(recipe_id: String) -> String:
	var cost := CRAFTING_SYSTEM.get_recipe_cost(recipe_id, player.get_crafting_cost_multiplier() if player != null and player.has_method("get_crafting_cost_multiplier") else 1.0)
	var parts: PackedStringArray = []
	for resource_id in cost.keys():
		parts.append("%d %s" % [int(cost[resource_id]), _pretty_name(str(resource_id))])
	return ", ".join(parts)
