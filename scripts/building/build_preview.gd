extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var building_system = null


func set_building_system(new_building_system) -> void:
	building_system = new_building_system


func _process(_delta: float) -> void:
	if building_system == null or not building_system.is_build_mode_active():
		visible = false
		return

	var texture: Texture2D = building_system.get_selected_building_texture()
	if texture == null:
		visible = false
		return

	var tile_pos: Vector2i = building_system.get_hovered_tile_pos()
	var tile_size: Vector2i = building_system.get_selected_building_tile_size()
	global_position = building_system.get_preview_world_position(tile_pos, tile_size)
	sprite.texture = texture
	sprite.modulate = building_system.get_preview_modulate(tile_pos)
	visible = true
