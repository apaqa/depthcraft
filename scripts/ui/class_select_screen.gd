extends Control

signal class_chosen(class_id: String)

const CARD_COLORS := {
	"warrior": Color(0.65, 0.25, 0.15, 1.0),
	"mage": Color(0.25, 0.25, 0.65, 1.0),
	"ranger": Color(0.15, 0.55, 0.25, 1.0),
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.97)
	add_child(bg)

	var title := Label.new()
	title.text = LocaleManager.L("class_select_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 80.0
	title.offset_bottom = 130.0
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_child(title)

	var class_system = get_node_or_null("/root/ClassSystem")
	if class_system == null:
		return

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 28)
	card_row.set_anchors_preset(Control.PRESET_CENTER)
	card_row.offset_left = -360.0
	card_row.offset_right = 360.0
	card_row.offset_top = -120.0
	card_row.offset_bottom = 160.0
	add_child(card_row)

	for class_id in ["warrior", "mage", "ranger"]:
		var def: Dictionary = (class_system.CLASS_DEFS[class_id] as Dictionary).duplicate(true)
		card_row.add_child(_build_card(class_id, def))


func _build_card(class_id: String, def: Dictionary) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(210, 280)
	var base_color: Color = CARD_COLORS.get(class_id, Color(0.3, 0.3, 0.3)) as Color
	card.add_theme_stylebox_override("normal", _make_style(base_color, 0.22))
	card.add_theme_stylebox_override("hover", _make_style(base_color, 0.50))
	card.add_theme_stylebox_override("pressed", _make_style(base_color, 0.72))
	card.add_theme_stylebox_override("focus", _make_style(base_color, 0.22))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = LocaleManager.L(str(def.get("name_key", class_id)))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hp_delta: float = (float(def.get("hp_mult", 1.0)) - 1.0) * 100.0
	var atk_delta: float = (float(def.get("atk_mult", 1.0)) - 1.0) * 100.0
	var spd_delta: float = (float(def.get("spd_mult", 1.0)) - 1.0) * 100.0
	var cd_delta: float = (float(def.get("cd_mult", 1.0)) - 1.0) * 100.0

	for stat_text: String in [
		_fmt_stat("HP", hp_delta),
		_fmt_stat(LocaleManager.L("class_stat_atk"), atk_delta),
		_fmt_stat(LocaleManager.L("class_stat_spd"), spd_delta),
		_fmt_stat(LocaleManager.L("class_stat_cd"), cd_delta),
	]:
		var stat_label := Label.new()
		stat_label.text = stat_text
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.add_theme_font_size_override("font_size", 13)
		stat_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1))
		vbox.add_child(stat_label)

	var desc_label := Label.new()
	desc_label.text = LocaleManager.L(str(def.get("desc_key", "")))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.88, 0.72, 1))
	desc_label.custom_minimum_size = Vector2(185, 0)
	vbox.add_child(desc_label)

	card.pressed.connect(func() -> void: _on_card_pressed(class_id))
	return card


func _fmt_stat(label: String, delta: float) -> String:
	if absf(delta) < 0.1:
		return "%s: ±0%%" % label
	var sign_str: String = "+" if delta > 0.0 else ""
	return "%s: %s%.0f%%" % [label, sign_str, delta]


func _make_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	return style


func _on_card_pressed(class_id: String) -> void:
	var class_system = get_node_or_null("/root/ClassSystem")
	if class_system != null:
		class_system.save_class(class_id)
	class_chosen.emit(class_id)
