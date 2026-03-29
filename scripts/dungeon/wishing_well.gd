extends Area2D
class_name WishingWell

const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")
const UI_AUDIO_CLICK_HOOK: Script = preload("res://scripts/ui/ui_audio_click_hook.gd")
const WELL_TEXTURE: Texture2D = preload("res://assets/floor_gargoyle_blue_basin.png")
const HEART_ICON: Texture2D = preload("res://assets/ui_heart_full.png")

const PANEL_BG_COLOR: Color = Color(0.05, 0.1, 0.2, 0.9)
const PANEL_BORDER_COLOR: Color = Color(0.38, 0.68, 0.96, 1.0)
const TITLE_COLOR: Color = Color(0.72, 0.9, 1.0, 1.0)
const SUCCESS_COLOR: Color = Color(0.72, 0.92, 1.0, 1.0)
const ERROR_COLOR: Color = Color(1.0, 0.52, 0.56, 1.0)
const SMALL_BUFF_POOL: Array[Dictionary] = [
	{
		"id": "small_attack",
		"description": "投入 10 銅幣 -> 隨機小 buff（攻擊 +3，本層）",
		"result_text": "本層攻擊 +3",
		"effects": {"attack": 3.0},
	},
	{
		"id": "small_defense",
		"description": "投入 10 銅幣 -> 隨機小 buff（防禦 +2，本層）",
		"result_text": "本層防禦 +2",
		"effects": {"defense": 2.0},
	},
	{
		"id": "small_speed",
		"description": "投入 10 銅幣 -> 隨機小 buff（速度 +5%，本層）",
		"result_text": "本層速度 +5%",
		"effects": {"speed_multiplier": 0.05},
	},
]
const MEDIUM_BUFF_POOL: Array[Dictionary] = [
	{
		"id": "medium_attack",
		"description": "投入 1 銀幣 -> 隨機中 buff（攻擊 +8，整次 run）",
		"result_text": "本次 run 攻擊 +8",
		"effects": {"attack": 8.0},
	},
	{
		"id": "medium_defense",
		"description": "投入 1 銀幣 -> 隨機中 buff（防禦 +6，整次 run）",
		"result_text": "本次 run 防禦 +6",
		"effects": {"defense": 6.0},
	},
	{
		"id": "medium_crit",
		"description": "投入 1 銀幣 -> 隨機中 buff（暴擊 +5%，整次 run）",
		"result_text": "本次 run 暴擊 +5%",
		"effects": {"crit_chance": 0.05},
	},
]
const CURSE_POOL: Array[Dictionary] = [
	{
		"id": "curse_attack",
		"name": "虛弱詛咒",
		"effects": {"attack": -5.0},
	},
	{
		"id": "curse_defense",
		"name": "脆弱詛咒",
		"effects": {"defense": -4.0},
	},
	{
		"id": "curse_speed",
		"name": "遲滯詛咒",
		"effects": {"speed_multiplier": -0.08},
	},
	{
		"id": "curse_vitality",
		"name": "枯萎詛咒",
		"effects": {"max_hp": -12.0},
	},
]

var loot_root: Node = null
var floor_number: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_used: bool = false
var _current_player: Variant = null
var _ui_canvas: CanvasLayer = null
var _ui_root: Control = null
var _message_label: Label = null
var _well_sprite: Sprite2D = null
var _well_light: PointLight2D = null


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
	return "按 E 觸碰許願池"


func interact(player: Variant) -> void:
	if player == null:
		return
	if _is_used:
		if player.has_method("show_status_message"):
			player.show_status_message("許願池已枯竭", ERROR_COLOR, 2.0)
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


func _build_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 18.0
		collision.shape = shape
		add_child(collision)

	_well_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _well_sprite == null:
		_well_sprite = Sprite2D.new()
		_well_sprite.name = "Sprite2D"
		_well_sprite.texture = WELL_TEXTURE
		_well_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_well_sprite.z_index = -1
		add_child(_well_sprite)

	_well_light = get_node_or_null("PointLight2D") as PointLight2D
	if _well_light == null:
		_well_light = PointLight2D.new()
		_well_light.name = "PointLight2D"
		_well_light.texture = _build_light_texture()
		_well_light.texture_scale = 1.6
		_well_light.energy = 0.5
		_well_light.color = Color(0.62, 0.84, 1.0, 1.0)
		_well_light.position = Vector2(0.0, -10.0)
		add_child(_well_light)


func _build_light_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 96
	texture.height = 96
	return texture


func _refresh_visual_state() -> void:
	if _well_sprite != null:
		_well_sprite.modulate = Color(0.72, 0.8, 0.9, 0.88) if _is_used else Color.WHITE
	if _well_light != null:
		_well_light.energy = 0.1 if _is_used else 0.5


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
	backdrop.color = Color(0.0, 0.0, 0.0, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(backdrop)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.3
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.7
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
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title: Label = Label.new()
	title.text = "許願池"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	layout.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "選一個願望，讓水面回應你的代價。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	layout.add_child(subtitle)

	layout.add_child(HSeparator.new())

	var option_box: VBoxContainer = VBoxContainer.new()
	option_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_box.add_theme_constant_override("separation", 8)
	layout.add_child(option_box)

	option_box.add_child(_build_option_row(ITEM_DATABASE.get_item_icon("copper"), "投入 10 銅幣 -> 隨機小 buff", Callable(self, "_on_offer_copper_pressed")))
	option_box.add_child(_build_option_row(ITEM_DATABASE.get_item_icon("silver"), "投入 1 銀幣 -> 隨機中 buff", Callable(self, "_on_offer_silver_pressed")))
	option_box.add_child(_build_option_row(ITEM_DATABASE.get_item_icon("gold"), "投入 1 金幣 -> 必得稀有祝福", Callable(self, "_on_offer_gold_pressed")))
	option_box.add_child(_build_option_row(HEART_ICON, "獻祭 10% 生命上限 -> 50% 得祝福 / 50% 得詛咒", Callable(self, "_on_offer_blood_pressed")))

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", ERROR_COLOR)
	layout.add_child(_message_label)

	UI_AUDIO_CLICK_HOOK.attach(_ui_root)
	AudioManager.play_sfx("ui_open")


func _build_option_row(icon: Texture2D, description: String, callback: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = icon
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(26.0, 26.0)
	row.add_child(icon_rect)

	var description_label: Label = Label.new()
	description_label.text = description
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(description_label)

	var wish_button: Button = Button.new()
	wish_button.text = "許願"
	wish_button.custom_minimum_size = Vector2(84.0, 30.0)
	wish_button.pressed.connect(callback)
	row.add_child(wish_button)

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


func _on_offer_copper_pressed() -> void:
	if not _spend_currency("copper", 10):
		_set_message("需要 10 銅幣。")
		return
	var buff_data: Dictionary = SMALL_BUFF_POOL[rng.randi_range(0, SMALL_BUFF_POOL.size() - 1)]
	if _current_player == null or not _current_player.has_method("apply_floor_stat_modifier"):
		_refund_currency("copper", 10)
		_set_message("目前無法接受本層 buff。")
		return
	_current_player.apply_floor_stat_modifier(str(buff_data.get("id", "")), buff_data.get("effects", {}))
	_complete_use("願望實現：%s" % str(buff_data.get("result_text", "")), SUCCESS_COLOR)


func _on_offer_silver_pressed() -> void:
	if not _spend_currency("silver", 1):
		_set_message("需要 1 銀幣。")
		return
	var buff_data: Dictionary = MEDIUM_BUFF_POOL[rng.randi_range(0, MEDIUM_BUFF_POOL.size() - 1)]
	if _current_player == null or not _current_player.has_method("apply_run_stat_modifier"):
		_refund_currency("silver", 1)
		_set_message("目前無法接受本次 run buff。")
		return
	_current_player.apply_run_stat_modifier(str(buff_data.get("id", "")), buff_data.get("effects", {}))
	_complete_use("願望實現：%s" % str(buff_data.get("result_text", "")), SUCCESS_COLOR)


func _on_offer_gold_pressed() -> void:
	if not _spend_currency("gold", 1):
		_set_message("需要 1 金幣。")
		return
	var rare_blessings: Array[String] = _get_rare_blessing_ids()
	if rare_blessings.is_empty():
		_refund_currency("gold", 1)
		_set_message("祝福池暫時沒有稀有祝福。")
		return
	var blessing_id: String = rare_blessings[rng.randi_range(0, rare_blessings.size() - 1)]
	if _current_player == null or not _current_player.has_method("apply_buff") or not bool(_current_player.apply_buff(blessing_id)):
		_refund_currency("gold", 1)
		_set_message("稀有祝福沒有成功附著。")
		return
	var blessing_name: String = LocaleManager.L("buff_%s_name" % blessing_id)
	_complete_use("願望實現：%s" % blessing_name, Color(1.0, 0.88, 0.42, 1.0))


func _on_offer_blood_pressed() -> void:
	if _current_player == null or not _current_player.has_method("sacrifice_max_hp_percent_for_run"):
		_set_message("目前無法以生命許願。")
		return
	var blessing_result: bool = rng.randf() <= 0.5
	var blessing_id: String = ""
	var blessing_name: String = ""
	var curse_data: Dictionary = {}
	if blessing_result:
		var blessing_pool: Array[Dictionary] = BUFF_SYSTEM.get_buff_pool()
		if blessing_pool.is_empty() or not _current_player.has_method("apply_buff"):
			_set_message("池水沒有回應。")
			return
		var blessing_entry: Dictionary = blessing_pool[rng.randi_range(0, blessing_pool.size() - 1)]
		blessing_id = str(blessing_entry.get("id", ""))
		if blessing_id == "":
			_set_message("池水沒有回應。")
			return
		blessing_name = LocaleManager.L("buff_%s_name" % blessing_id)
	else:
		if not _current_player.has_method("apply_run_stat_modifier"):
			_set_message("詛咒沒有成功附著。")
			return
		curse_data = CURSE_POOL[rng.randi_range(0, CURSE_POOL.size() - 1)]
	if int(_current_player.sacrifice_max_hp_percent_for_run(0.10)) <= 0:
		_set_message("你的生命上限已不足以再獻祭。")
		return
	if blessing_result:
		if not bool(_current_player.apply_buff(blessing_id)):
			_set_message("祝福沒有成功附著。")
			return
		_complete_use("血之願實現：%s" % blessing_name, SUCCESS_COLOR)
		return
	_current_player.apply_run_stat_modifier(str(curse_data.get("id", "")), curse_data.get("effects", {}))
	_complete_use("血之願反噬：%s" % str(curse_data.get("name", "")), Color(0.92, 0.44, 0.88, 1.0))


func _get_rare_blessing_ids() -> Array[String]:
	var blessing_ids: Array[String] = []
	for buff_entry: Dictionary in BUFF_SYSTEM.get_buff_pool():
		var buff_id: String = str(buff_entry.get("id", ""))
		if buff_id == "":
			continue
		if BUFF_SYSTEM.get_buff_tier(buff_id) >= 1:
			blessing_ids.append(buff_id)
	return blessing_ids


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
		_current_player.show_status_message(message, color, 2.6)


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
