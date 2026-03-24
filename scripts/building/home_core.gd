extends StaticBody2D
class_name HomeCore

signal core_placed(position: Vector2)

var is_placed: bool = false
var core_position: Vector2 = Vector2.ZERO


func place_at(world_position: Vector2) -> void:
	global_position = world_position
	core_position = world_position
	is_placed = true
	core_placed.emit(world_position)
