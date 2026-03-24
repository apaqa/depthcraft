extends Control

@onready var hp_label: Label = $HPLabel


func _ready() -> void:
	update_hp(100, 100)


func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current, max_hp]
