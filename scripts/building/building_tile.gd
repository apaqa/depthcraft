extends "res://scripts/building/building_base.gd"
class_name BuildingTile


func configure_tile(building: Dictionary, target_system, tile_pos: Vector2i, data: Dictionary = {}) -> void:
	name = "%s_%d_%d" % [str(building.get("id", "building")), tile_pos.x, tile_pos.y]
	global_position = target_system.get_preview_world_position(tile_pos, target_system.get_building_tile_size_for_id(str(building.get("id", ""))))
	z_index = 0

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.texture = building.get("preview_texture", null)
	sprite.scale = building.get("preview_scale", Vector2.ONE) as Vector2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if bool(building.get("has_collision", false)):
		if collision == null:
			collision = CollisionShape2D.new()
			collision.name = "CollisionShape2D"
			add_child(collision)
		var shape := RectangleShape2D.new()
		var tile_size: Vector2i = target_system.get_building_tile_size_for_id(str(building.get("id", "")))
		shape.size = Vector2(tile_size.x * 16, tile_size.y * 16)
		collision.shape = shape
	else:
		if collision != null:
			collision.queue_free()

	initialize_building(building, target_system, tile_pos, data)
