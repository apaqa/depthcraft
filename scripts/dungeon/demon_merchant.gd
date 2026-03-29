extends Area2D
class_name DemonMerchant

const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")
const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const LEGENDARY_ITEMS: Script = preload("res://scripts/dungeon/legendary_items.gd")
const LOOT_DROP_SCENE: PackedScene = preload("res://scenes/dungeon/loot_drop.tscn")
const UI_AUDIO_CLICK_HOOK: Script = preload("res://scripts/ui/ui_audio_click_hook.gd")
const MERCHANT_TEXTURE: Texture2D = preload("res://assets/npc_trickster.png")

const PANEL_BG_COLOR: Color = Color(0.08, 0.02, 0.08, 0.9)
const PANEL_BORDER_COLOR: Color = Color(0.62, 0.22, 0.78, 0.95)
const TITLE_COLOR: Color = Color(0.84, 0.42, 1.0, 1.0)
const STATUS_ERROR_COLOR: Color = Color(1.0, 0.52, 0.6, 1.0)
const STATUS_SUCCESS_COLOR: Color = Color(0.94, 0.8, 1.0, 1.0)
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand"]
const OFFER_POOL: Array[Dictionary] = [
	{
		"id": "epic_equipment",
		"cost_percent": 10,
		"cost_text": "代價：10% 生命上限",
		"reward_text": "獲得：隨機紫色裝備",
	},
	{
		"id": "silver",
		"cost_percent": 15,
		"cost_text": "代價：15% 生命上限",
		"reward_text": "獲得：50 銀幣",
	},
	{
		"id": "legendary_equipment",
		"cost_percent": 20,
		"cost_text": "代價：20% 生命上限",
		"reward_text": "獲得：隨機傳奇裝備",
	},
	{
		"id": "blessing",
		"cost_percent": 5,
		"cost_text": "代價：5% 生命上限",
		"reward_text": "獲得：隨機祝福",
	},
	{
		"id": "repair_all",
		"cost_percent": 25,
		"cost_text": "代價：25% 生命上限",
		"reward_text": "獲得：全部裝備修復至滿耐久",
	},
]

var loot_root: Node = null
var floor_number: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_player: Variant = null
var _ui_canvas: CanvasLayer = null
var _ui_root: Control = null
var _message_label: Label = null
var _merchant_sprite: Sprite2D = null
var _offer_buttons: Dictionary = {}
var _offer_state: Dictionary = {}
var _selected_offers: Array[Dictionary] = []


func setup(target_loot_root: Node, target_floor_number: int, seed_value: int) -> void:
	loot_root = target_loot_root
	floor_number = maxi(target_floor_number, 1)
	rng.seed = seed_value
	_roll_offers()


func _ready() -> void:
	monitoring = true
	monitorable = true
	if _selected_offers.is_empty():
		_roll_offers()
	_build_visuals()
	_refresh_visual_state()


func _exit_tree() -> void:
	_close_ui()


func get_interaction_prompt() -> String:
	if _all_offers_used():
		return "惡魔商人已無可交易"
	return "按 E 與惡魔商人交易"


func interact(player: Variant) -> void:
	if player == null:
		return
	if _all_offers_used():
		if player.has_method("show_status_message"):
			player.show_status_message("惡魔商人已無可交易", STATUS_ERROR_COLOR, 2.0)
		return
	if _ui_canvas != null:
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


func _roll_offers() -> void:
	var candidates: Array[Dictionary] = []
	for offer_data: Dictionary in OFFER_POOL:
		candidates.append(offer_data.duplicate(true))
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var current_offer: Dictionary = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = current_offer
	_selected_offers.clear()
	_offer_state.clear()
	for offer_index: int in range(mini(3, candidates.size())):
		var chosen_offer: Dictionary = candidates[offer_index]
		var offer_id: String = str(chosen_offer.get("id", ""))
		if offer_id == "":
			continue
		_selected_offers.append(chosen_offer)
		_offer_state[offer_id] = false


func _build_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 18.0
		collision.shape = shape
		add_child(collision)

	_merchant_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _merchant_sprite == null:
		_merchant_sprite = Sprite2D.new()
		_merchant_sprite.name = "Sprite2D"
		_merchant_sprite.texture = MERCHANT_TEXTURE
		_merchant_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_merchant_sprite.position = Vector2(0.0, -4.0)
		add_child(_merchant_sprite)

	if get_node_or_null("Aura") == null:
		var aura: Polygon2D = Polygon2D.new()
		aura.name = "Aura"
		aura.color = Color(0.7, 0.16, 0.86, 0.24)
		aura.polygon = PackedVector2Array([
			Vector2(-22.0, 12.0),
			Vector2(-14.0, -10.0),
			Vector2(14.0, -10.0),
			Vector2(22.0, 12.0),
			Vector2(0.0, 20.0),
		])
		add_child(aura)
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(aura, "modulate:a", 0.48, 0.9)
		tween.tween_property(aura, "modulate:a", 0.16, 0.9)


func _refresh_visual_state() -> void:
	if _merchant_sprite == null:
		return
	if _all_offers_used():
		_merchant_sprite.modulate = Color(0.7, 0.7, 0.7, 0.85)
	else:
		_merchant_sprite.modulate = Color.WHITE


func _open_ui() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.layer = 11
	add_child(_ui_canvas)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_canvas.add_child(_ui_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.42)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(backdrop)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.2
	panel.anchor_top = 0.25
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.75
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_BG_COLOR, PANEL_BORDER_COLOR))
	_ui_root.add_child(panel)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.anchor_left = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_right = 1.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -42.0
	close_button.offset_top = 10.0
	close_button.offset_right = -10.0
	close_button.offset_bottom = 42.0
	close_button.pressed.connect(_close_ui)
	panel.add_child(close_button)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(HSeparator.new())

	var list_box: VBoxContainer = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	layout.add_child(list_box)

	_offer_buttons.clear()
	for offer_data: Dictionary in _selected_offers:
		list_box.add_child(_build_offer_row(offer_data))

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", STATUS_ERROR_COLOR)
	layout.add_child(_message_label)

	var footer: HBoxContainer = HBoxContainer.new()
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_footer_button: Button = Button.new()
	close_footer_button.text = "關閉"
	close_footer_button.pressed.connect(_close_ui)
	footer.add_child(close_footer_button)
	layout.add_child(footer)

	_refresh_offer_buttons()
	UI_AUDIO_CLICK_HOOK.attach(_ui_root)
	AudioManager.play_sfx("ui_open")


func _build_header() -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)

	var portrait_frame: Panel = Panel.new()
	portrait_frame.custom_minimum_size = Vector2(58.0, 58.0)
	portrait_frame.add_theme_stylebox_override("panel", _build_panel_style(Color(0.12, 0.04, 0.14, 0.96), Color(0.54, 0.22, 0.74, 1.0)))
	header.add_child(portrait_frame)

	var portrait_icon: TextureRect = TextureRect.new()
	portrait_icon.texture = MERCHANT_TEXTURE
	portrait_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_icon.offset_left = 6.0
	portrait_icon.offset_top = 6.0
	portrait_icon.offset_right = -6.0
	portrait_icon.offset_bottom = -6.0
	portrait_frame.add_child(portrait_icon)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	header.add_child(text_box)

	var title: Label = Label.new()
	title.text = "惡魔商人"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	text_box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "以生命上限交換深淵的貨物。"
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.76, 1.0, 1.0))
	text_box.add_child(subtitle)

	return header


func _build_offer_row(offer_data: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var cost_label: Label = Label.new()
	cost_label.text = str(offer_data.get("cost_text", ""))
	cost_label.custom_minimum_size = Vector2(170.0, 32.0)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cost_label)

	var arrow_label: Label = Label.new()
	arrow_label.text = "->"
	arrow_label.custom_minimum_size = Vector2(18.0, 32.0)
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow_label)

	var reward_label: Label = Label.new()
	reward_label.text = str(offer_data.get("reward_text", ""))
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(reward_label)

	var trade_button: Button = Button.new()
	trade_button.text = "交易"
	trade_button.custom_minimum_size = Vector2(86.0, 32.0)
	trade_button.pressed.connect(_on_trade_pressed.bind(str(offer_data.get("id", ""))))
	row.add_child(trade_button)
	_offer_buttons[str(offer_data.get("id", ""))] = trade_button

	return row


func _build_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _on_trade_pressed(offer_id: String) -> void:
	if offer_id == "" or bool(_offer_state.get(offer_id, false)):
		return

	var offer_data: Dictionary = _get_offer_data(offer_id)
	if offer_data.is_empty():
		return

	match offer_id:
		"epic_equipment":
			_trade_for_epic_equipment(offer_data)
		"silver":
			_trade_for_silver(offer_data)
		"legendary_equipment":
			_trade_for_legendary_equipment(offer_data)
		"blessing":
			_trade_for_blessing(offer_data)
		"repair_all":
			_trade_for_repair(offer_data)


func _trade_for_epic_equipment(offer_data: Dictionary) -> void:
	var equipment: Dictionary = _generate_epic_equipment()
	if equipment.is_empty():
		_set_message("惡魔商人今天沒有拿出像樣的紫色裝備。")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(float(offer_data.get("cost_percent", 0.0)) / 100.0)
	if sacrificed_hp <= 0:
		return
	_offer_state[str(offer_data.get("id", ""))] = true
	_grant_stack_reward(equipment)
	_show_floating_text("-%d%% 上限" % int(offer_data.get("cost_percent", 0)), TITLE_COLOR)
	_show_status_message("惡魔商人遞來一件紫色裝備。", STATUS_SUCCESS_COLOR)
	_set_message("交易完成。")
	_refresh_offer_buttons()


func _trade_for_silver(offer_data: Dictionary) -> void:
	var sacrificed_hp: int = _apply_hp_sacrifice(float(offer_data.get("cost_percent", 0.0)) / 100.0)
	if sacrificed_hp <= 0:
		return
	_offer_state[str(offer_data.get("id", ""))] = true
	_grant_item_reward("silver", 50)
	_show_floating_text("-15% 上限", TITLE_COLOR)
	_show_status_message("你以生命換來了 50 銀幣。", Color(0.92, 0.88, 0.64, 1.0))
	_set_message("交易完成。")
	_refresh_offer_buttons()


func _trade_for_legendary_equipment(offer_data: Dictionary) -> void:
	var legendary_item: Dictionary = LEGENDARY_ITEMS.get_random_legendary(rng)
	if legendary_item.is_empty():
		_set_message("惡魔商人今天沒有拿出傳奇裝備。")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(float(offer_data.get("cost_percent", 0.0)) / 100.0)
	if sacrificed_hp <= 0:
		return
	_offer_state[str(offer_data.get("id", ""))] = true
	_grant_stack_reward(legendary_item)
	_show_floating_text("-20% 上限", TITLE_COLOR)
	_show_status_message("惡魔商人拿出了一件傳奇裝備。", Color(1.0, 0.72, 0.28, 1.0))
	_set_message("交易完成。")
	_refresh_offer_buttons()


func _trade_for_blessing(offer_data: Dictionary) -> void:
	var buff_pool: Array[Dictionary] = BUFF_SYSTEM.get_buff_pool()
	if buff_pool.is_empty():
		_set_message("深淵此刻沒有回應任何祝福。")
		return
	var buff_entry: Dictionary = buff_pool[rng.randi_range(0, buff_pool.size() - 1)]
	var buff_id: String = str(buff_entry.get("id", ""))
	if buff_id == "":
		_set_message("深淵此刻沒有回應任何祝福。")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(float(offer_data.get("cost_percent", 0.0)) / 100.0)
	if sacrificed_hp <= 0:
		return
	if _current_player == null or not _current_player.has_method("apply_buff") or not bool(_current_player.apply_buff(buff_id)):
		_set_message("祝福交易失敗。")
		return
	_offer_state[str(offer_data.get("id", ""))] = true
	var buff_name: String = LocaleManager.L("buff_%s_name" % buff_id)
	_show_floating_text("-5% 上限", TITLE_COLOR)
	_show_status_message("你獲得了祝福：%s" % buff_name, STATUS_SUCCESS_COLOR)
	_set_message("交易完成。")
	_refresh_offer_buttons()


func _trade_for_repair(offer_data: Dictionary) -> void:
	if _current_player == null:
		return
	var equipment_system: Variant = _current_player.get("equipment_system")
	var inventory: Variant = _current_player.get("inventory")
	if equipment_system == null or not equipment_system.has_method("repair_all_equipment") or not equipment_system.has_method("get_total_repairable_item_count"):
		_set_message("沒有可用的裝備修復能力。")
		return
	var repairable_count: int = int(equipment_system.call("get_total_repairable_item_count", inventory))
	if repairable_count <= 0:
		_set_message("目前沒有需要修復的裝備。")
		return
	var sacrificed_hp: int = _apply_hp_sacrifice(float(offer_data.get("cost_percent", 0.0)) / 100.0)
	if sacrificed_hp <= 0:
		return
	var repaired_count: int = int(equipment_system.call("repair_all_equipment", inventory))
	if repaired_count <= 0:
		_set_message("修復失敗。")
		return
	_offer_state[str(offer_data.get("id", ""))] = true
	_show_floating_text("-25% 上限", TITLE_COLOR)
	_show_status_message("惡魔商人修復了你的所有裝備。", STATUS_SUCCESS_COLOR)
	_set_message("交易完成。")
	_refresh_offer_buttons()


func _get_offer_data(offer_id: String) -> Dictionary:
	for offer_data: Dictionary in _selected_offers:
		if str(offer_data.get("id", "")) == offer_id:
			return offer_data
	return {}


func _apply_hp_sacrifice(percent: float) -> int:
	if _current_player == null or not _current_player.has_method("sacrifice_max_hp_percent_for_run"):
		return 0
	var sacrificed_hp: int = int(_current_player.sacrifice_max_hp_percent_for_run(percent))
	if sacrificed_hp <= 0:
		_set_message("你的生命上限已無法再承受這筆交易。")
		return 0
	_set_message("")
	return sacrificed_hp


func _generate_epic_equipment() -> Dictionary:
	if EQUIPMENT_SLOTS.is_empty():
		return {}
	var slot_index: int = rng.randi_range(0, EQUIPMENT_SLOTS.size() - 1)
	var slot_name: String = EQUIPMENT_SLOTS[slot_index]
	return DUNGEON_LOOT._build_equipment(slot_name, "Epic", maxi(floor_number, 1), rng)


func _grant_item_reward(item_id: String, quantity: int) -> void:
	var inventory: Variant = _get_inventory()
	if inventory != null and inventory.has_method("add_item") and bool(inventory.add_item(item_id, quantity)):
		if _current_player != null and _current_player.has_method("record_dungeon_loot"):
			_current_player.record_dungeon_loot(item_id, quantity)
		return
	_spawn_item_drop(item_id, quantity)
	_show_status_message("背包已滿，獎勵掉落在附近。", Color(1.0, 0.84, 0.54, 1.0))


func _grant_stack_reward(stack_data: Dictionary) -> void:
	var inventory: Variant = _get_inventory()
	if inventory != null and inventory.has_method("add_stack") and bool(inventory.add_stack(stack_data)):
		if _current_player != null and _current_player.has_method("record_dungeon_loot"):
			_current_player.record_dungeon_loot(str(stack_data.get("id", "")), int(stack_data.get("quantity", 1)))
		return
	_spawn_stack_drop(stack_data)
	_show_status_message("背包已滿，獎勵掉落在附近。", Color(1.0, 0.84, 0.54, 1.0))


func _spawn_item_drop(item_id: String, quantity: int) -> void:
	if loot_root == null:
		loot_root = get_parent()
	if loot_root == null:
		return
	var drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	if drop == null:
		return
	drop.global_position = global_position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0))
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
	drop.global_position = global_position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0))
	if drop.has_method("setup_stack"):
		drop.setup_stack(stack_data)
	loot_root.add_child(drop)


func _refresh_offer_buttons() -> void:
	for offer_id_variant: Variant in _offer_buttons.keys():
		var offer_id: String = str(offer_id_variant)
		var trade_button: Button = _offer_buttons[offer_id] as Button
		if trade_button == null:
			continue
		var already_traded: bool = bool(_offer_state.get(offer_id, false))
		trade_button.disabled = already_traded
		trade_button.text = "已交易" if already_traded else "交易"
	_refresh_visual_state()


func _all_offers_used() -> bool:
	for offer_data: Dictionary in _selected_offers:
		var offer_id: String = str(offer_data.get("id", ""))
		if not bool(_offer_state.get(offer_id, false)):
			return false
	return not _selected_offers.is_empty()


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
