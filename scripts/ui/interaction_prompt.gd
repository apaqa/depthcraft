extends Label


func _ready() -> void:
	visible = false


func show_prompt(prompt_text: String) -> void:
	text = prompt_text
	visible = true


func hide_prompt() -> void:
	text = ""
	visible = false
