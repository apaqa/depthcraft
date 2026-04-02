extends Control

var snapshot: Dictionary = {}


func set_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot.duplicate(true)
	queue_redraw()


func _draw() -> void:
	var mode: String = snapshot.get("mode", "dungeon")
	if mode == "overworld":
		_draw_overworld()
	else:
		_draw_dungeon()


func _draw_overworld() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.04, 0.92), true)
	if snapshot.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)
		return
	var world_size: Vector2 = snapshot.get("world_size", Vector2(3200.0, 3200.0))
	var scale_x: float = size.x / max(world_size.x, 1.0)
	var scale_y: float = size.y / max(world_size.y, 1.0)

	for cluster: Dictionary in snapshot.get("forest_clusters", []):
		var c: Vector2 = cluster.get("center", Vector2.ZERO) as Vector2
		var r: float = max(float(cluster.get("radius", 0.0)) * scale_x, 3.0)
		draw_circle(Vector2(c.x * scale_x, c.y * scale_y), r, Color(0.18, 0.48, 0.18, 0.65))

	for cluster: Dictionary in snapshot.get("mountain_clusters", []):
		var c: Vector2 = cluster.get("center", Vector2.ZERO) as Vector2
		var r: float = max(float(cluster.get("radius", 0.0)) * scale_x, 3.0)
		draw_circle(Vector2(c.x * scale_x, c.y * scale_y), r, Color(0.45, 0.45, 0.45, 0.65))

	var entrance_pos: Vector2 = snapshot.get("dungeon_entrance_pos", Vector2.ZERO)
	if entrance_pos != Vector2.ZERO:
		var ep: Vector2 = Vector2(entrance_pos.x * scale_x, entrance_pos.y * scale_y)
		draw_circle(ep, 3.5, Color(0.9, 0.12, 0.12, 1.0))

	var merchant_pos: Vector2 = snapshot.get("merchant_pos", Vector2.ZERO)
	if merchant_pos != Vector2.ZERO:
		var mp: Vector2 = Vector2(merchant_pos.x * scale_x, merchant_pos.y * scale_y)
		draw_rect(Rect2(mp.x - 2.0, mp.y - 2.5, 4.0, 5.0), Color(1.0, 0.8, 0.1, 1.0), true)

	var home_core_pos: Vector2 = snapshot.get("home_core_pos", Vector2.ZERO)
	if home_core_pos != Vector2.ZERO:
		var hp: Vector2 = Vector2(home_core_pos.x * scale_x, home_core_pos.y * scale_y)
		draw_rect(Rect2(hp.x - 3.0, hp.y - 3.0, 6.0, 6.0), Color(1.0, 1.0, 1.0, 0.9), true)

	var player_pos: Vector2 = snapshot.get("player_pos", Vector2.ZERO)
	if player_pos != Vector2.ZERO:
		var pp: Vector2 = Vector2(player_pos.x * scale_x, player_pos.y * scale_y)
		draw_circle(pp, 3.5, Color(1.0, 1.0, 0.2, 1.0))

	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)


func _draw_dungeon() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.92), true)
	if snapshot.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)
		return
	var map_size: Vector2i = snapshot.get("map_size", Vector2i(1, 1))
	var scale_x: float = size.x / float(max(map_size.x, 1))
	var scale_y: float = size.y / float(max(map_size.y, 1))

	var rooms: Array = snapshot.get("rooms", [])
	var room_types: Array = snapshot.get("room_types", [])
	var boss_room_index: int = int(snapshot.get("boss_room_index", -1))
	var explored_rooms: Array = snapshot.get("explored_rooms", [])
	var visible_tiles: Array = snapshot.get("floor_tiles", [])
	var visible_tile_set: Dictionary = {}
	for tile_variant: Variant in visible_tiles:
		visible_tile_set[tile_variant] = true

	for tile: Vector2i in visible_tiles:
		draw_rect(Rect2(tile.x * scale_x, tile.y * scale_y, max(scale_x, 1.0), max(scale_y, 1.0)), Color(0.38, 0.4, 0.44, 1.0), true)
	for exp_idx: int in explored_rooms:
		if exp_idx < 0 or exp_idx >= rooms.size():
			continue
		var room: Rect2i = rooms[exp_idx] as Rect2i
		var rx: float = room.position.x * scale_x
		var ry: float = room.position.y * scale_y
		var rw: float = room.size.x * scale_x
		var rh: float = room.size.y * scale_y
		var room_color: Color = _room_color_for_type(room_types, exp_idx, boss_room_index)
		draw_rect(Rect2(rx, ry, rw, rh), room_color, true)
		draw_rect(Rect2(rx, ry, rw, rh), Color(0.65, 0.65, 0.75, 0.5), false, 1.0)

	for enemy_pos: Vector2 in snapshot.get("enemy_positions", []):
		var enemy_tile: Vector2 = Vector2(enemy_pos.x / 16.0, enemy_pos.y / 16.0)
		if not visible_tile_set.has(Vector2i(int(enemy_tile.x), int(enemy_tile.y))):
			continue
		draw_circle(Vector2(enemy_tile.x * scale_x, enemy_tile.y * scale_y), 2.5, Color(0.95, 0.24, 0.24, 1.0))
	for chest_pos: Vector2 in snapshot.get("chest_positions", []):
		var chest_tile: Vector2 = Vector2(chest_pos.x / 16.0, chest_pos.y / 16.0)
		if not visible_tile_set.has(Vector2i(int(chest_tile.x), int(chest_tile.y))):
			continue
		draw_rect(Rect2(chest_tile.x * scale_x - 1.5, chest_tile.y * scale_y - 1.5, 4.0, 4.0), Color(1.0, 0.9, 0.25, 1.0), true)
	var stair_tile: Vector2 = snapshot.get("stair_tile", Vector2.ZERO)
	if stair_tile != Vector2.ZERO and visible_tile_set.has(Vector2i(int(stair_tile.x), int(stair_tile.y))):
		draw_rect(Rect2(stair_tile.x * scale_x - 3.0, stair_tile.y * scale_y - 3.0, 6.0, 6.0), Color(0.3, 1.0, 0.5, 1.0), true)
	var spawn_tile: Vector2 = snapshot.get("spawn_tile", Vector2.ZERO)
	if visible_tile_set.has(Vector2i(int(spawn_tile.x), int(spawn_tile.y))):
		draw_circle(Vector2(spawn_tile.x * scale_x, spawn_tile.y * scale_y), 3.0, Color(0.35, 0.7, 1.0, 1.0))
	var player_tile: Vector2 = snapshot.get("player_tile", Vector2.ZERO)
	draw_rect(Rect2(player_tile.x * scale_x - 3.0, player_tile.y * scale_y - 3.0, 6.0, 6.0), Color(1.0, 1.0, 0.3, 1.0), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)


func _room_color_for_type(room_types: Array, room_idx: int, boss_room_index: int) -> Color:
	if room_idx == boss_room_index:
		return Color(0.65, 0.1, 0.1, 1.0)
	var room_type: String = str(room_types[room_idx]) if room_idx < room_types.size() else "normal"
	match room_type:
		"chest", "timed_treasure":
			return Color(0.52, 0.47, 0.18, 1.0)
		"merchant", "boss_merchant", "secret_merchant":
			return Color(0.18, 0.48, 0.28, 1.0)
		"event", "challenge", "puzzle":
			return Color(0.38, 0.22, 0.52, 1.0)
		"safe":
			return Color(0.18, 0.32, 0.52, 1.0)
		"elite":
			return Color(0.52, 0.22, 0.1, 1.0)
		"trap":
			return Color(0.70, 0.14, 0.14, 1.0)
		"elite_arena":
			return Color(0.45, 0.0, 0.0, 1.0)
		"shrine":
			return Color(0.22, 0.42, 0.85, 1.0)
		_:
			return Color(0.26, 0.28, 0.36, 1.0)
