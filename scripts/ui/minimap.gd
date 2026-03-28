extends Control

var snapshot: Dictionary = {}


func set_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot.duplicate(true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.92), true)
	if snapshot.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)
		return
	var map_size: Vector2i = snapshot.get("map_size", Vector2i(1, 1))
	var scale_x: float = size.x / float(max(map_size.x, 1))
	var scale_y: float = size.y / float(max(map_size.y, 1))
	for tile: Vector2i in snapshot.get("floor_tiles", []):
		draw_rect(Rect2(tile.x * scale_x, tile.y * scale_y, max(scale_x, 1.0), max(scale_y, 1.0)), Color(0.38, 0.4, 0.44, 1.0), true)
	for enemy_pos: Vector2 in snapshot.get("enemy_positions", []):
		var enemy_tile: Vector2 = Vector2(enemy_pos.x / 16.0, enemy_pos.y / 16.0)
		draw_circle(Vector2(enemy_tile.x * scale_x, enemy_tile.y * scale_y), 2.5, Color(0.95, 0.24, 0.24, 1.0))
	for chest_pos: Vector2 in snapshot.get("chest_positions", []):
		var chest_tile: Vector2 = Vector2(chest_pos.x / 16.0, chest_pos.y / 16.0)
		draw_rect(Rect2(chest_tile.x * scale_x - 1.5, chest_tile.y * scale_y - 1.5, 4.0, 4.0), Color(1.0, 0.9, 0.25, 1.0), true)
	var stair_tile: Vector2 = snapshot.get("stair_tile", Vector2.ZERO)
	if stair_tile != Vector2.ZERO:
		draw_rect(Rect2(stair_tile.x * scale_x - 3.0, stair_tile.y * scale_y - 3.0, 6.0, 6.0), Color(0.3, 1.0, 0.5, 1.0), true)
	var spawn_tile: Vector2 = snapshot.get("spawn_tile", Vector2.ZERO)
	draw_circle(Vector2(spawn_tile.x * scale_x, spawn_tile.y * scale_y), 3.0, Color(0.35, 0.7, 1.0, 1.0))
	var player_tile: Vector2 = snapshot.get("player_tile", Vector2.ZERO)
	draw_rect(Rect2(player_tile.x * scale_x - 3.0, player_tile.y * scale_y - 3.0, 6.0, 6.0), Color(1.0, 1.0, 0.3, 1.0), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)

