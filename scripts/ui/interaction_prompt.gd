extends Label


func _ready() -> void:
	anchor_left = 0.3
	anchor_right = 0.7
	anchor_top = 0.85
	anchor_bottom = 0.95
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", max(get_theme_font_size("font_size"), 16))
	visible = false


func show_prompt(prompt_text: String) -> void:
	text = prompt_text
	visible = true


func hide_prompt() -> void:
	text = ""
	visible = false

