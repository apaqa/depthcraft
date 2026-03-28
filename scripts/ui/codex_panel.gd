extends Control

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")

const ENEMY_DISPLAY_NAMES: Dictionary = {
	"goblin": "哥布林",
	"orc": "半獸人",
	"shield_orc": "盾牌半獸人",
	"bat": "蝙蝠",
	"slime": "史萊姆",
	"shadow": "暗影",
	"gargoyle": "石像鬼",
	"mimic": "擬態寶箱",
	"skeleton": "骷髏",
	"ranged": "弓箭手",
	"raid": "突擊兵",
	"elite": "精英",
	"boss": "BOSS",
	"necromancer": "死靈法師",
	"lava_giant": "熔岩巨人",
	"abyss_eye": "深淵之眼",
	"shadow_assassin": "暗影刺客",
}

signal panel_closed

var _tab_buttons: Array[Button] = []
var _current_tab: String = "monster"
var _scroll: ScrollContainer = null
var _list_container: VBoxContainer = null
var _bg: PanelContainer = null

const TABS: Array[String] = ["monster", "equipment", "material"]
const TAB_LABELS: Array[String] = ["怪物", "裝備", "材料"]


func _ready() -> void:
	_build_ui()
	visible = false


func open_panel() -> void:
	visible = true
	_build_list()


func close_panel() -> void:
	visible = false
	emit_signal("panel_closed")


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(dim)

	_bg = PanelContainer.new()
	_bg.anchor_left = 0.1
	_bg.anchor_top = 0.1
	_bg.anchor_right = 0.9
	_bg.anchor_bottom = 0.9
	_bg.offset_left = 0.0
	_bg.offset_top = 0.0
	_bg.offset_right = 0.0
	_bg.offset_bottom = 0.0
	add_child(_bg)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.5, 0.2, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_bg.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(vbox)

	# Title bar
	var title_bar: HBoxContainer = HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0.0, 36.0)
	vbox.add_child(title_bar)

	var title_label: Label = Label.new()
	title_label.text = "圖鑑"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	title_bar.add_child(title_label)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)

	# Tab row
	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.custom_minimum_size = Vector2(0.0, 32.0)
	vbox.add_child(tab_row)

	for i: int in range(TABS.size()):
		var tab_id: String = TABS[i]
		var btn: Button = Button.new()
		btn.text = TAB_LABELS[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (tab_id == _current_tab)
		btn.pressed.connect(_on_tab_pressed.bind(tab_id))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# Scroll area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_container)


func _on_tab_pressed(tab_id: String) -> void:
	_current_tab = tab_id
	for i: int in range(TABS.size()):
		_tab_buttons[i].button_pressed = (TABS[i] == tab_id)
	_build_list()


func _on_close_pressed() -> void:
	close_panel()


func _build_list() -> void:
	for child: Node in _list_container.get_children():
		child.queue_free()
	match _current_tab:
		"monster":
			_build_monster_list()
		"equipment":
			_build_item_list(["equipment"])
		"material":
			_build_item_list(["resource", "consumable"])


func _build_monster_list() -> void:
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex == null:
		_add_placeholder("CodexManager 未載入")
		return
	var known: Array[String] = codex.get_all_monster_kinds()
	if known.is_empty():
		_add_placeholder("尚未遇到任何怪物")
		return
	for kind: String in known:
		var entry: Dictionary = codex.get_monster_entry(kind) as Dictionary
		var display_name: String = str(ENEMY_DISPLAY_NAMES.get(kind, kind))
		var killed: int = int(entry.get("killed", 0))
		var seen: int = int(entry.get("seen", 0))
		_add_monster_row(display_name, kind, killed, seen)


func _add_monster_row(display_name: String, kind: String, killed: int, seen: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 28.0)

	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	row.add_child(name_label)

	var stats_label: Label = Label.new()
	stats_label.text = "擊殺: %d  遭遇: %d" % [killed, seen]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	row.add_child(stats_label)

	_list_container.add_child(row)
	_add_separator()


func _build_item_list(type_filter: Array[String]) -> void:
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex == null:
		_add_placeholder("CodexManager 未載入")
		return
	var known_ids: Array[String] = codex.get_all_item_ids()
	var shown: int = 0
	for item_id: String in known_ids:
		var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
		if item_data.is_empty():
			continue
		var item_type: String = str(item_data.get("type", ""))
		var matched: bool = false
		for t: String in type_filter:
			if item_type == t:
				matched = true
				break
		if not matched:
			continue
		var entry: Dictionary = codex.get_item_entry(item_id) as Dictionary
		var seen: int = int(entry.get("seen", 0))
		_add_item_row(item_data, seen)
		shown += 1
	if shown == 0:
		_add_placeholder("尚未發現任何物品")


func _add_item_row(item_data: Dictionary, seen: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 28.0)

	var item_id: String = str(item_data.get("id", ""))
	var rarity: String = str(item_data.get("rarity", "Common"))
	var color: Color = ITEM_DATABASE.get_item_color(item_id)

	var name_label: Label = Label.new()
	name_label.text = ITEM_DATABASE.get_display_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	row.add_child(name_label)

	var type_label: Label = Label.new()
	var item_type: String = str(item_data.get("type", ""))
	var slot_name: String = str(item_data.get("slot", ""))
	var type_text: String = slot_name if slot_name != "" else item_type
	type_label.text = type_text
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	row.add_child(type_label)

	var seen_label: Label = Label.new()
	seen_label.text = "  ×%d" % seen
	seen_label.add_theme_font_size_override("font_size", 12)
	seen_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55, 1.0))
	row.add_child(seen_label)

	_list_container.add_child(row)
	_add_separator()


func _add_placeholder(msg: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
	_list_container.add_child(lbl)


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	_list_container.add_child(sep)
