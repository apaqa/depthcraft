extends Node2D
class_name FloorTeleporterNpc

## Floor teleporter NPC for the underground tavern (Floor 0).
## Shows a checkpoint panel listing unlocked floors with travel costs.

signal floor_selected(floor_number: int)

const CHECKPOINT_STEP: int = 5
const COST_PER_FLOOR: int = 10


func _ready() -> void:
	_build_visual()


func get_interaction_prompt() -> String:
	return LocaleManager.L("teleporter_prompt")


func interact(player: Node) -> void:
	if player == null:
		return
	_open_panel(player)


var _canvas: CanvasLayer = null
var _current_player: Variant = null


func _build_visual() -> void:
	var tex: Texture2D = preload("res://assets/doc_idle_anim_f0.png")
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(1.0, 1.0)
	sprite.position = Vector2(0.0, -24.0)
	add_child(sprite)

	var name_lbl: Label = Label.new()
	name_lbl.text = LocaleManager.L("teleporter_name")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.85, 0.65, 1.0, 1.0)
	name_lbl.position = Vector2(-22.0, -55.0)
	add_child(name_lbl)

	var area: Area2D = Area2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = circle
	area.add_child(col_shape)
	add_child(area)


func _open_panel(player: Variant) -> void:
	if _canvas != null:
		return
	_current_player = player
	if player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	if "in_menu" in player:
		player.in_menu = true

	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -170.0
	panel.offset_top = -170.0
	panel.offset_right = 170.0
	panel.offset_bottom = 170.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.96)
	style.border_color = Color(0.40, 0.28, 0.60, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = LocaleManager.L("teleporter_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var hint: Label = Label.new()
	hint.text = LocaleManager.L("teleporter_hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.82, 0.82, 0.88, 1.0)
	vbox.add_child(hint)

	var btn_list: VBoxContainer = VBoxContainer.new()
	btn_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_list.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_list)

	var floors: Array[int] = _get_unlocked_floors()
	var inventory: Variant = player.get("inventory") if player != null else null
	for floor_num: int in floors:
		var cost: int = _get_cost(floor_num)
		var btn_text: String = LocaleManager.L("teleporter_floor_label") % floor_num
		if cost > 0:
			btn_text += LocaleManager.L("teleporter_floor_cost") % cost
		else:
			btn_text += LocaleManager.L("teleporter_floor_free")

		var can_afford: bool = true
		if cost > 0 and inventory != null and inventory.has_method("get_item_count"):
			can_afford = int(inventory.get_item_count("copper")) >= cost

		var btn: Button = Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(0.0, 34.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not can_afford
		btn.pressed.connect(_on_floor_picked.bind(floor_num, cost))
		btn_list.add_child(btn)

	var close_btn: Button = Button.new()
	close_btn.text = LocaleManager.L("teleporter_cancel")
	close_btn.custom_minimum_size = Vector2(0.0, 32.0)
	close_btn.pressed.connect(_close_panel)
	vbox.add_child(close_btn)


func _on_floor_picked(floor_num: int, cost: int) -> void:
	var player: Variant = _current_player
	if cost > 0 and player != null:
		var inventory: Variant = player.get("inventory")
		if inventory != null and inventory.has_method("remove_item"):
			inventory.remove_item("copper", cost)
	_close_panel()
	floor_selected.emit(floor_num)


func _close_panel() -> void:
	if _canvas != null:
		_canvas.queue_free()
	_canvas = null
	if _current_player != null:
		if _current_player.has_method("set_ui_blocked"):
			_current_player.set_ui_blocked(false)
		if "in_menu" in _current_player:
			_current_player.in_menu = false
	_current_player = null


func _input(event: InputEvent) -> void:
	if _canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()


func _get_unlocked_floors() -> Array[int]:
	var floors: Array[int] = [1]
	var deepest: int = _get_deepest_floor()
	var cp: int = CHECKPOINT_STEP
	while cp <= deepest:
		if not floors.has(cp):
			floors.append(cp)
		cp += CHECKPOINT_STEP
	# Floor 5 is always available
	if not floors.has(5):
		floors.append(5)
		floors.sort()
	return floors


func _get_deepest_floor() -> int:
	var main_node: Node = get_tree().current_scene
	if main_node == null:
		return 1
	var val: Variant = main_node.get("deepest_dungeon_floor_reached")
	if val == null:
		return 1
	return max(int(val), 1)


func _get_cost(floor_num: int) -> int:
	if floor_num <= 1:
		return 0
	if floor_num == 5:
		return 50
	return floor_num * COST_PER_FLOOR
