extends Control
class_name TavernUI

const TavernSlots = preload("res://scripts/world/tavern_slots.gd")
const TavernPachinko = preload("res://scripts/world/tavern_pachinko.gd")

var _player: Node = null
var _facility: Node = null
var _slots_panel: Control = null
var _pachinko_panel: Control = null
var _active_tab: String = "slots"
var _slots_tab_btn: Button = null
var _pachinko_tab_btn: Button = null
var _panel_container: PanelContainer = null
var _built: bool = false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open_for_player(player: Node, facility: Node) -> void:
	_player = player
	_facility = facility
	if not _built:
		_build_ui()
	if _slots_panel != null and _slots_panel.has_method("setup"):
		_slots_panel.setup(player)
	if _pachinko_panel != null and _pachinko_panel.has_method("setup"):
		_pachinko_panel.setup(player)
	_switch_tab("slots")
	visible = true


func close_menu() -> void:
	visible = false


func _build_ui() -> void:
	_built = true
	_panel_container = PanelContainer.new()
	_panel_container.layout_mode = 1
	_panel_container.anchor_left = 0.1
	_panel_container.anchor_top = 0.08
	_panel_container.anchor_right = 0.9
	_panel_container.anchor_bottom = 0.92
	_panel_container.offset_left = 0.0
	_panel_container.offset_top = 0.0
	_panel_container.offset_right = 0.0
	_panel_container.offset_bottom = 0.0
	add_child(_panel_container)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel_container.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# Title row
	var title_hbox: HBoxContainer = HBoxContainer.new()
	root_vbox.add_child(title_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "地下酒館"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.modulate = Color(1.0, 0.85, 0.5, 1.0)
	title_hbox.add_child(title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(close_menu)
	title_hbox.add_child(close_btn)

	# Tab bar
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root_vbox.add_child(tab_bar)

	_slots_tab_btn = Button.new()
	_slots_tab_btn.text = "老虎機"
	_slots_tab_btn.custom_minimum_size = Vector2(100.0, 30.0)
	_slots_tab_btn.pressed.connect(_on_slots_tab_pressed)
	tab_bar.add_child(_slots_tab_btn)

	_pachinko_tab_btn = Button.new()
	_pachinko_tab_btn.text = "彈珠台"
	_pachinko_tab_btn.custom_minimum_size = Vector2(100.0, 30.0)
	_pachinko_tab_btn.pressed.connect(_on_pachinko_tab_pressed)
	tab_bar.add_child(_pachinko_tab_btn)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(spacer)

	var sep: HSeparator = HSeparator.new()
	root_vbox.add_child(sep)

	# Content area
	var content_area: Control = Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_area)

	_slots_panel = TavernSlots.new()
	_slots_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(_slots_panel)

	_pachinko_panel = TavernPachinko.new()
	_pachinko_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(_pachinko_panel)


func _on_slots_tab_pressed() -> void:
	_switch_tab("slots")


func _on_pachinko_tab_pressed() -> void:
	_switch_tab("pachinko")


func _switch_tab(tab: String) -> void:
	_active_tab = tab
	if _slots_panel != null:
		_slots_panel.visible = (tab == "slots")
	if _pachinko_panel != null:
		_pachinko_panel.visible = (tab == "pachinko")
	_apply_tab_styles()


func _apply_tab_styles() -> void:
	if _slots_tab_btn != null:
		if _active_tab == "slots":
			_slots_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			_slots_tab_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
	if _pachinko_tab_btn != null:
		if _active_tab == "pachinko":
			_pachinko_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			_pachinko_tab_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
