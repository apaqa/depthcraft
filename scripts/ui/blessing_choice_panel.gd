extends Control
class_name BlessingChoicePanel

signal blessing_chosen(blessing_id: String)

const THEME_ICONS: Dictionary = {
	"fire": preload("res://assets/icons/kyrise/crystal_01b.png"),
	"ice": preload("res://assets/icons/kyrise/crystal_01a.png"),
	"poison": preload("res://assets/icons/kyrise/crystal_01d.png"),
	"crit": preload("res://assets/icons/kyrise/crystal_01e.png"),
	"lifesteal": preload("res://assets/icons/kyrise/crystal_01c.png"),
	"generic": preload("res://assets/icons/kyrise/gem_01a.png"),
	"speed": preload("res://assets/icons/kyrise/gem_01b.png"),
}
const THEME_BG_COLORS: Dictionary = {
	"fire": Color(0.3, 0.05, 0.0, 0.8),
	"ice": Color(0.0, 0.1, 0.3, 0.8),
	"poison": Color(0.0, 0.2, 0.0, 0.8),
	"crit": Color(0.3, 0.2, 0.0, 0.8),
	"lifesteal": Color(0.25, 0.0, 0.05, 0.8),
	"generic": Color(0.15, 0.15, 0.15, 0.8),
	"speed": Color(0.1, 0.15, 0.25, 0.8),
}

var _input_lock_until: int = 0
var _choice_made: bool = false
var _reroll_count: int = 0
var _reroll_player: Variant = null
var _reroll_callable: Callable = Callable()


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func open_with_choices(choices: Array[Dictionary]) -> void:
	_choice_made = false
	_input_lock_until = Time.get_ticks_msec() + 200
	_rebuild_ui(choices)
	visible = true


func set_reroll_context(player: Variant, reroll_callable: Callable, reroll_count: int) -> void:
	_reroll_player = player
	_reroll_callable = reroll_callable
	_reroll_count = reroll_count


func reset_reroll() -> void:
	_reroll_count = 0
	_reroll_player = null
	_reroll_callable = Callable()


func close_panel() -> void:
	visible = false
	_choice_made = true


func _close_without_choosing() -> void:
	_choice_made = true
	visible = false
	get_tree().paused = false
	blessing_chosen.emit("")


func _rebuild_ui(choices: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()

	# Fullscreen backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(backdrop)

	# Center container — tall enough for title + 260px cards + buttons
	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -320.0
	center.offset_right = 320.0
	center.offset_top = -220.0
	center.offset_bottom = 220.0
	center.add_theme_constant_override("separation", 12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(center)

	# Title
	var title: Label = Label.new()
	title.text = LocaleManager.L("blessing_select_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(title)

	# Card row
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 14)
	card_row.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(card_row)

	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		card_row.add_child(_build_card(choice))

	if choices.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "..."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.process_mode = Node.PROCESS_MODE_ALWAYS
		center.add_child(empty_label)

	# Footer row: reroll + skip
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	footer.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(footer)

	if _reroll_callable.is_valid() and _reroll_player != null:
		var shard_cost: int = _get_reroll_cost()
		var reroll_btn: Button = Button.new()
		reroll_btn.text = "重抽  -%d 天賦碎片" % shard_cost
		reroll_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		reroll_btn.focus_mode = Control.FOCUS_NONE
		reroll_btn.pressed.connect(_on_reroll_pressed)
		footer.add_child(reroll_btn)

	var skip_btn: Button = Button.new()
	skip_btn.text = "放棄 (ESC)"
	skip_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.modulate = Color(0.65, 0.65, 0.65, 1.0)
	skip_btn.pressed.connect(_close_without_choosing)
	footer.add_child(skip_btn)


func _build_card(data: Dictionary) -> Control:
	var blessing_id: String = str(data.get("id", ""))
	var theme: String = str(data.get("theme", "generic"))
	var card_color: Color = Color(0.3, 0.3, 0.4, 1.0)
	var color_val: Variant = data.get("color", null)
	if color_val is Color:
		card_color = color_val
	var bg_color: Color = THEME_BG_COLORS.get(theme, THEME_BG_COLORS.get("generic", Color(0.15, 0.15, 0.15, 0.8))) as Color

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(170, 250)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	# Critical: must be ALWAYS so _gui_input routes correctly when tree is paused
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var normal_style: StyleBoxFlat = _make_card_style(card_color, 0.12)
	normal_style.bg_color = bg_color
	var hover_style: StyleBoxFlat = _make_card_style(card_color, 0.28)
	hover_style.bg_color = bg_color.lightened(0.15)
	var pressed_style: StyleBoxFlat = _make_card_style(card_color, 0.06)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	btn.pressed.connect(_on_card_pressed.bind(blessing_id))

	# Content layout inside button — all children MOUSE_FILTER_IGNORE so clicks reach btn
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner)

	# Icon
	var icon_texture: Texture2D = THEME_ICONS.get(theme, THEME_ICONS.get("generic", null)) as Texture2D
	if icon_texture != null:
		var icon_container: CenterContainer = CenterContainer.new()
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon)
		inner.add_child(icon_container)

	# Name
	var display_name: String = LocaleManager.L(str(data.get("name", blessing_id)))
	var stacks: int = int(data.get("current_stacks", 0))
	if stacks > 0:
		display_name += " Lv.%d->%d" % [stacks, stacks + 1]
	var name_lbl: Label = Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", card_color.lightened(0.5))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	# Tier / category
	var tier: String = str(data.get("tier", "sub"))
	var tier_text: String = LocaleManager.L("blessing_cat_main") if tier == "main" else LocaleManager.L("blessing_cat_sub")
	var cat_text: String = LocaleManager.L(str(data.get("category", "")))
	var tier_lbl: Label = Label.new()
	tier_lbl.text = "[%s] %s" % [cat_text, tier_text]
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = Color(0.65, 0.65, 0.7, 1.0)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tier_lbl)

	# Description
	var description: String = LocaleManager.L(str(data.get("description", "")))
	var desc_lbl: Label = Label.new()
	desc_lbl.text = description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(0.75, 0.78, 0.85, 1.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	# Border (drawn on top of content, IGNORE so clicks pass through to btn)
	var border: Control = Control.new()
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.draw.connect(func() -> void:
		var rect: Rect2 = border.get_rect().grow(-2.0)
		border.draw_rect(rect.grow(2), card_color.darkened(0.3), false, 2.0)
		border.draw_rect(rect, card_color, false, 2.0)
		border.draw_rect(rect.grow(-2), card_color.lightened(0.3), false, 1.0)
	)
	border.resized.connect(border.queue_redraw)
	btn.add_child(border)

	return btn


func _get_reroll_cost() -> int:
	match _reroll_count:
		0:
			return 1
		1:
			return 3
		2:
			return 6
		_:
			return 10


func _on_reroll_pressed() -> void:
	if _choice_made:
		return
	var shard_cost: int = _get_reroll_cost()
	var inv: Variant = _reroll_player.get("inventory") if _reroll_player != null else null
	if inv == null:
		return
	var have: int = int(inv.get_item_count("talent_shard")) if inv.has_method("get_item_count") else 0
	if have < shard_cost:
		return
	inv.remove_item("talent_shard", shard_cost)
	_reroll_count += 1
	var raw: Variant = _reroll_callable.call()
	var new_choices: Array[Dictionary] = []
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary:
				new_choices.append(entry as Dictionary)
	_rebuild_ui(new_choices)


func _on_card_pressed(blessing_id: String) -> void:
	if _choice_made:
		return
	if Time.get_ticks_msec() < _input_lock_until:
		return
	_choice_made = true
	close_panel()
	blessing_chosen.emit(blessing_id)


func _make_card_style(accent: Color, tint: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = Color(0.13, 0.14, 0.19, 0.96)
	var tinted: Color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 0.96)
	style.bg_color = bg.lerp(tinted, clampf(tint, 0.0, 1.0))
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_without_choosing()
		get_viewport().set_input_as_handled()
