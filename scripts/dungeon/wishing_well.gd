extends Area2D
class_name WishingWell

const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")
const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")
const LOOT_DROP_SCENE: PackedScene = preload("res://scenes/dungeon/loot_drop.tscn")
const UI_AUDIO_CLICK_HOOK: Script = preload("res://scripts/ui/ui_audio_click_hook.gd")

var loot_root: Node = null
var floor_number: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_used: bool = false
var _current_player: Variant = null
var _ui_canvas: CanvasLayer = null
var _ui_root: Control = null
var _message_label: Label = null
var _well_sprite: AnimatedSprite2D = null


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
	if _is_used:
		return "Wishing well exhausted"
	return "Press E to make a wish"


func interact(player: Variant) -> void:
	if _is_used or _ui_canvas != null or player == null:
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

	if get_node_or_null("Aura") == null:
		var aura: Polygon2D = Polygon2D.new()
		aura.name = "Aura"
		aura.color = Color(0.32, 0.62, 1.0, 0.28)
		aura.polygon = PackedVector2Array([
			Vector2(-18.0, 10.0),
			Vector2(0.0, -18.0),
			Vector2(18.0, 10.0),
			Vector2(10.0, 18.0),
			Vector2(-10.0, 18.0),
		])
		add_child(aura)
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(aura, "modulate:a", 0.55, 0.8)
		tween.tween_property(aura, "modulate:a", 0.22, 0.8)

	_well_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _well_sprite == null:
		_well_sprite = AnimatedSprite2D.new()
		_well_sprite.name = "AnimatedSprite2D"
		_well_sprite.sprite_frames = _build_well_frames()
		_well_sprite.animation = &"default"
		_well_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_well_sprite.play()
		add_child(_well_sprite)


func _build_well_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 5.0)
	var frame_paths: PackedStringArray = PackedStringArray([
		"res://assets/wall_fountain_basin_blue_anim_f0.png",
		"res://assets/wall_fountain_basin_blue_anim_f1.png",
		"res://assets/wall_fountain_basin_blue_anim_f2.png",
	])
	for frame_path: String in frame_paths:
		var texture: Texture2D = load(frame_path) as Texture2D
		if texture != null:
			frames.add_frame("default", texture)
	return frames


func _refresh_visual_state() -> void:
	if _well_sprite != null:
		_well_sprite.modulate = Color(0.64, 0.72, 0.84, 0.92) if _is_used else Color.WHITE


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
	panel.offset_left = -230.0
	panel.offset_top = -180.0
	panel.offset_right = 230.0
	panel.offset_bottom = 180.0
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
	title.text = "Wishing Well"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Offer a coin and tempt fate."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.78, 0.86, 1.0, 1.0)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())
	_add_action_row(vbox, ITEM_DATABASE.get_item_icon("copper"), "10 copper - Gain a random buff", _on_offer_copper_pressed)
	_add_action_row(vbox, ITEM_DATABASE.get_item_icon("silver"), "1 silver - Restore 50% max HP", _on_offer_silver_pressed)
	_add_action_row(vbox, ITEM_DATABASE.get_item_icon("gold"), "1 gold - Gain a Rare+ item", _on_offer_gold_pressed)
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

	UI_AUDIO_CLICK_HOOK.attach(_ui_root)
	AudioManager.play_sfx("ui_open")


func _add_action_row(parent: Control, icon: Texture2D, description: String, callback: Callable) -> void:
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
	action_button.text = "Offer"
	action_button.pressed.connect(callback)
	row.add_child(action_button)
	parent.add_child(row)


func _on_offer_copper_pressed() -> void:
	if not _spend_currency("copper", 10):
		_set_message("Need 10 copper")
		return
	var buff_pool: Array[Dictionary] = BUFF_SYSTEM.get_buff_pool()
	if buff_pool.is_empty():
		_refund_currency("copper", 10)
		_set_message("No blessing answers your wish")
		return
	var buff_entry: Dictionary = buff_pool[rng.randi_range(0, buff_pool.size() - 1)]
	var buff_id: String = str(buff_entry.get("id", ""))
	if buff_id == "" or _current_player == null or not _current_player.has_method("apply_buff") or not bool(_current_player.apply_buff(buff_id)):
		_refund_currency("copper", 10)
		_set_message("The well remains silent")
		return
	var buff_name: String = LocaleManager.L("buff_%s_name" % buff_id)
	_show_floating_text("Blessing", Color(0.68, 0.96, 1.0, 1.0))
	_complete_use("The well grants %s" % buff_name, Color(0.68, 0.96, 1.0, 1.0))


func _on_offer_silver_pressed() -> void:
	if _current_player == null:
		return
	var current_hp: int = int(_current_player.get("current_hp"))
	var max_hp: int = int(_current_player.get("max_hp"))
	if current_hp >= max_hp:
		_set_message("HP is already full")
		return
	if not _spend_currency("silver", 1):
		_set_message("Need 1 silver")
		return
	var heal_amount: int = maxi(int(round(float(max_hp) * 0.5)), 1)
	if _current_player.has_method("heal"):
		_current_player.heal(heal_amount)
	_show_floating_text("+%d HP" % heal_amount, Color(0.42, 1.0, 0.54, 1.0))
	_complete_use("The water heals your wounds", Color(0.42, 1.0, 0.54, 1.0))


func _on_offer_gold_pressed() -> void:
	if not _spend_currency("gold", 1):
		_set_message("Need 1 gold")
		return
	var equipment: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(maxi(floor_number, 1), "Rare", rng)
	if equipment.is_empty():
		_refund_currency("gold", 1)
		_set_message("The well remains silent")
		return
	_grant_stack_reward(equipment)
	_complete_use("A treasure rises from the basin", Color(1.0, 0.9, 0.48, 1.0))


func _spend_currency(currency_id: String, amount: int) -> bool:
	var inventory: Variant = _get_inventory()
	if inventory == null:
		return false
	if not inventory.has_method("get_item_count") or not inventory.has_method("remove_item"):
		return false
	if int(inventory.get_item_count(currency_id)) < amount:
		return false
	return bool(inventory.remove_item(currency_id, amount))


func _refund_currency(currency_id: String, amount: int) -> void:
	var inventory: Variant = _get_inventory()
	if inventory == null or not inventory.has_method("add_item"):
		return
	inventory.add_item(currency_id, amount)


func _grant_stack_reward(stack_data: Dictionary) -> void:
	var inventory: Variant = _get_inventory()
	var stack_name: String = str(stack_data.get("name", "Treasure"))
	if inventory != null and inventory.has_method("add_stack") and bool(inventory.add_stack(stack_data)):
		if _current_player != null and _current_player.has_method("record_dungeon_loot"):
			_current_player.record_dungeon_loot(str(stack_data.get("id", "")), int(stack_data.get("quantity", 1)))
		_show_floating_text(stack_name, Color(1.0, 0.9, 0.48, 1.0))
		return
	_spawn_stack_drop(stack_data)
	_show_status_message("Inventory full, reward dropped nearby", Color(1.0, 0.86, 0.52, 1.0))


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


func _complete_use(message: String, color: Color) -> void:
	_is_used = true
	_refresh_visual_state()
	_show_status_message(message, color)
	_close_ui()


func _get_inventory() -> Variant:
	if _current_player == null:
		return null
	return _current_player.get("inventory")


func _show_status_message(message: String, color: Color) -> void:
	if _current_player != null and _current_player.has_method("show_status_message"):
		_current_player.show_status_message(message, color, 2.4)


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
