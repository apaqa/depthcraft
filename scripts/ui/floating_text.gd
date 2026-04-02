extends Node2D

@export var display_text: String = ""
@export var text_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var font_size: int = 12

@onready var label: Label = $Label


func _ready() -> void:
	label.text = display_text
	label.modulate = text_color
	label.add_theme_font_size_override("font_size", font_size)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)

