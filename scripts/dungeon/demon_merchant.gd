extends Area2D
class_name DemonMerchant

const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")
const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const LOOT_DROP_SCENE: PackedScene = preload("res://scenes/dungeon/loot_drop.tscn")
const UI_AUDIO_CLICK_HOOK: Script = preload("res://scripts/ui/ui_audio_click_hook.gd")
const STRONG_BUFF_IDS: Array[String] = [
	"atk_up_2",
	"aoe_attack",
	"lifesteal",
	"armor",
	"hp_up",
	"speed_up",
]

var loot_root: Node = null
var floor_number: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_player: Variant = null
var _ui_canvas: CanvasLayer = null
var _ui_root: Control = null
var _message_label: Label = null
var _merchant_sprite: Sprite2D = null
var _copper_button: Button = null
var _equipment_button: Button = null
var _buff_button: Button = null
var _offer_state: Dictionary = {
	"copper": false,
	"equipment": false,
	"buff": false,
}


func setup(target_loot_root: Node, target_floor_number: int, seed_value: int) -> void:
	loot_root = target_loot_root
	floor_number = maxi(target_floor_number, 1)
	rng.seed = seed_value


func _ready() -> void:
	monitoring = true
	monitorable = true
	_build_visuals()
	_refresh_visual_state()


func _exit_tree() -> void:
	_close_ui()


func get_interaction_prompt() -> String:
	if _all_offers_used():
		return "The demon has nothing left to trade"
	return "Press E to bargain with the demon"


func interact(player: Variant) -> void:
	if _all_offers_used() or _ui_canvas != null or player == null:
		return
	_current_player = player
	_open_ui()
	if player.has_method("set_ui_blocked"):
		player.set_ui_blocked(true)
	if "in_menu" in player:
		player.in_menu = true


func _input(event: InputEvent) -> void:
	if _ui_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_ui()
		get_viewport().set_input_as_handled()


func _build_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 16.0
		collision.shape = shape
		add_child(collision)

	_merchant_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _merchant_sprite == null:
		_merchant_sprite = Sprite2D.new()
		_merchant_sprite.name = "Sprite2D"
		_merchant_sprite.texture = load("res://assets/monster_demon.png") as Texture2D
		_merchant_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_merchant_sprite)

	if get_node_or_null("Aura") == null:
		var aura: Polygon2D = Polygon2D.new()
		aura.name = "Aura"
		aura.color = Color(0.88, 0.16, 0.14, 0.28)
		aura.polygon = PackedVector2Array([
			Vector2(-18.0, 12.0),
			Vector2(0.0, -16.0),
			Vector2(18.0, 12.0),
			Vector2(10.0, 18.0),
			Vector2(-10.0, 18.0),
		])
		add_child(aura)
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(aura, "modulate:a", 0.52, 0.9)
		tween.tween_property(aura, "modulate:a", 0.20, 0.9)


func _refresh_visual_state() -> void:
	if _merchant_sprite != null:
		_merchant_sprite.modulate = Color(0.56, 0.42, 0.42, 0.94) if _all_offers_used() else Color.WHITE


func _open_ui() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.layer = 11
	add_child(_ui_canvas)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_canvas.add_child(_ui_root)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250.0
	panel.offset_top = -190.0
	panel.offset_right = 250.0
	panel.offset_bottom = 190.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(panel)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(8.0, 8.0)
	close_button.custom_minimum_size = Vector2(32.0, 32.0)
	close_button.pressed.connect(_close_ui)
	panel.add_child(close_button)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Demon Merchant"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "\u4ee5\u8840\u70ba\u4ee3\u50f9..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1.0, 0.56, 0.52, 1.0)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())
	_copper_button = _add_action_row(vbox, ITEM_DATABASE.get_item_icon("copper"), "Sacrifice 10% max HP - Gain 50 copper", _on_copper_trade_pressed)
	_equipment_button = _add_action_row(vbox, ITEM_DATABASE.get_equipment_icon("weapon", "Rare"), "Sacrifice 20% max HP - Gain a Rare item", _on_equipment_trade_pressed)
	_buff_button = _add_action_row(vbox, null, "Sacrifice 30% max HP - Gain a powerful buff", _on_buff_trade_pressed)
	vbox.add_child(HSeparator.new())

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.46, 1.0))
	vbox.add_child(_message_label)

	var footer: HBoxContainer = HBoxContainer.new()
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var footer_close_button: Button = Button.new()
	footer_close_button.text = "Close"
	footer_close_button.pressed.connect(_close_ui)
	footer.add_child(footer_close_button)
	vbox.add_child(footer)

	_refresh_offer_buttons()
	UI_AUDIO_CLICK_HOOK.attach(_ui_root)
	AudioManager.play_sfx("ui_open")


func _add_action_row(parent: Control, icon: Texture2D, description: String, callback: Callable) -> Button:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(30.0, 30.0)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)
	var label: Label = Label.new()
	label.text = description
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var action_button: Button = Button.new()
	action_button.text = "Trade"
	action_button.pressed.connect(callback)
	row.add_child(action_button)
	parent.add_child(row)
	return action_button


func _on_copper_trade_pressed() -> void:
	if bool(_offer_state.get("copper", false)):
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(0.10)
	if sacrificed_hp <= 0:
		return
	_offer_state["copper"] = true
	_grant_item_reward("copper", 50)
	_show_floating_text("-%d Max HP" % sacrificed_hp, Color(1.0, 0.45, 0.45, 1.0))
	_show_status_message("Your blood becomes 50 copper", Color(1.0, 0.82, 0.45, 1.0))
	_refresh_offer_buttons()


func _on_equipment_trade_pressed() -> void:
	if bool(_offer_state.get("equipment", false)):
		return
	var equipment: Dictionary = _generate_rare_equipment()
	if equipment.is_empty():
		_set_message("The demon has no worthy prize today")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(0.20)
	if sacrificed_hp <= 0:
		return
	_offer_state["equipment"] = true
	_grant_stack_reward(equipment)
	_show_floating_text("-%d Max HP" % sacrificed_hp, Color(1.0, 0.45, 0.45, 1.0))
	_show_status_message("The demon leaves behind a Rare item", Color(0.78, 0.88, 1.0, 1.0))
	_refresh_offer_buttons()


func _on_buff_trade_pressed() -> void:
	if bool(_offer_state.get("buff", false)):
		return
	var buff_id: String = _pick_strong_buff_id()
	if buff_id == "":
		_set_message("The demon refuses this bargain")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(0.30)
	if sacrificed_hp <= 0:
		return
	if _current_player == null or not _current_player.has_method("apply_buff") or not bool(_current_player.apply_buff(buff_id)):
		_set_message("The demon refuses this bargain")
		return
	_offer_state["buff"] = true
	var buff_name: String = LocaleManager.L("buff_%s_name" % buff_id)
	_show_floating_text("-%d Max HP" % sacrificed_hp, Color(1.0, 0.45, 0.45, 1.0))
	_show_status_message("The demon grants %s" % buff_name, Color(0.88, 0.72, 1.0, 1.0))
	_refresh_offer_buttons()


func _apply_hp_sacrifice(percent: float) -> int:
	if _current_player == null or not _current_player.has_method("sacrifice_max_hp_percent_for_run"):
		return 0
	var sacrificed_hp: int = int(_current_player.sacrifice_max_hp_percent_for_run(percent))
	if sacrificed_hp <= 0:
		_set_message("Your life cannot endure this price")
		return 0
	_set_message("")
	return sacrificed_hp


func _generate_rare_equipment() -> Dictionary:
	var equipment: Dictionary = {}
	for _attempt_index: int in range(8):
		equipment = DUNGEON_LOOT.generate_dungeon_equipment(maxi(floor_number, 1), rng)
		if str(equipment.get("rarity", "")) == "Rare":
			return equipment
	return DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(maxi(floor_number, 1), "Rare", rng)


func _pick_strong_buff_id() -> String:
	var available_ids: Array[String] = []
	for buff_id: String in STRONG_BUFF_IDS:
		if BUFF_SYSTEM.get_buff(buff_id).is_empty():
			continue
		available_ids.append(buff_id)
	if available_ids.is_empty():
		return ""
	return available_ids[rng.randi_range(0, available_ids.size() - 1)]


func _grant_item_reward(item_id: String, quantity: int) -> void:
	var inventory: Variant = _get_inventory()
	if inventory != null and inventory.has_method("add_item") and bool(inventory.add_item(item_id, quantity)):
		if _current_player != null and _current_player.has_method("record_dungeon_loot"):
			_current_player.record_dungeon_loot(item_id, quantity)
		return
	_spawn_item_drop(item_id, quantity)
	_show_status_message("Inventory full, reward dropped nearby", Color(1.0, 0.86, 0.52, 1.0))


func _grant_stack_reward(stack_data: Dictionary) -> void:
	var inventory: Variant = _get_inventory()
	if inventory != null and inventory.has_method("add_stack") and bool(inventory.add_stack(stack_data)):
		if _current_player != null and _current_player.has_method("record_dungeon_loot"):
			_current_player.record_dungeon_loot(str(stack_data.get("id", "")), int(stack_data.get("quantity", 1)))
		return
	_spawn_stack_drop(stack_data)
	_show_status_message("Inventory full, reward dropped nearby", Color(1.0, 0.86, 0.52, 1.0))


func _spawn_item_drop(item_id: String, quantity: int) -> void:
	if loot_root == null:
		loot_root = get_parent()
	if loot_root == null:
		return
	var drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	if drop == null:
		return
	drop.global_position = global_position + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
	if drop.has_method("setup"):
		drop.setup(item_id, quantity)
	loot_root.add_child(drop)


func _spawn_stack_drop(stack_data: Dictionary) -> void:
	if loot_root == null:
		loot_root = get_parent()
	if loot_root == null:
		return
	var drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	if drop == null:
		return
	drop.global_position = global_position + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
	if drop.has_method("setup_stack"):
		drop.setup_stack(stack_data)
	loot_root.add_child(drop)


func _refresh_offer_buttons() -> void:
	if _copper_button != null:
		var copper_used: bool = bool(_offer_state.get("copper", false))
		_copper_button.disabled = copper_used
		_copper_button.text = "Sold Out" if copper_used else "Trade"
	if _equipment_button != null:
		var equipment_used: bool = bool(_offer_state.get("equipment", false))
		_equipment_button.disabled = equipment_used
		_equipment_button.text = "Sold Out" if equipment_used else "Trade"
	if _buff_button != null:
		var buff_used: bool = bool(_offer_state.get("buff", false))
		_buff_button.disabled = buff_used
		_buff_button.text = "Sold Out" if buff_used else "Trade"
	_refresh_visual_state()


func _all_offers_used() -> bool:
	return bool(_offer_state.get("copper", false)) and bool(_offer_state.get("equipment", false)) and bool(_offer_state.get("buff", false))


func _get_inventory() -> Variant:
	if _current_player == null:
		return null
	return _current_player.get("inventory")


func _show_status_message(message: String, color: Color) -> void:
	if _current_player != null and _current_player.has_method("show_status_message"):
		_current_player.show_status_message(message, color, 2.6)


func _show_floating_text(message: String, color: Color) -> void:
	if _current_player != null and _current_player.has_method("_show_floating_text"):
		_current_player._show_floating_text(global_position, message, color)


func _set_message(message: String) -> void:
	if _message_label != null:
		_message_label.text = message


func _close_ui() -> void:
	var player_ref: Variant = _current_player
	if _ui_canvas != null and is_instance_valid(_ui_canvas):
		_ui_canvas.queue_free()
		_ui_canvas = null
		_ui_root = null
		_message_label = null
		AudioManager.play_sfx("ui_close")
	if player_ref != null and is_instance_valid(player_ref):
		if player_ref.has_method("set_ui_blocked"):
			player_ref.set_ui_blocked(false)
		if "in_menu" in player_ref:
			player_ref.in_menu = false
	_current_player = null
