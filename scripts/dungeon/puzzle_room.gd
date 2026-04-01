extends Node2D
class_name PuzzleRoom

const TILE_SIZE := 16.0
const BACKDROP_FILL_COLOR := Color(0.22, 0.42, 0.85, 0.28)
const BACKDROP_BORDER_COLOR := Color(0.58, 0.78, 1.0, 0.92)
const SWITCH_IDLE_COLOR := Color(0.18, 0.25, 0.46, 0.95)
const SWITCH_ACTIVE_COLOR := Color(0.78, 0.92, 1.0, 0.98)
const DUNGEON_CHEST_SCENE := preload("res://scenes/dungeon/dungeon_chest.tscn")

var _room: Rect2i
var _loot_root: Node = null
var _floor_number: int = 1
var _switch_count: int = 4
var _next_switch_index: int = 0
var _completed: bool = false
var _built: bool = false
var _switch_visuals: Array[Polygon2D] = []


func setup(room: Rect2i, target_loot_root: Node, target_floor_number: int, rng: RandomNumberGenerator = null) -> void:
	_room = room
	_loot_root = target_loot_root
	_floor_number = target_floor_number
	_switch_count = 3 if _rng_randf(rng) < 0.5 else 4
	_build_room()


func _ready() -> void:
	_build_room()


func _build_room() -> void:
	if _built or _room.size == Vector2i.ZERO:
		return
	_built = true
	_add_backdrop()
	_add_hint_label()
	_add_switches()


func _add_backdrop() -> void:
	var room_start := Vector2(_room.position.x * TILE_SIZE, _room.position.y * TILE_SIZE)
	var room_end := Vector2(_room.end.x * TILE_SIZE, _room.end.y * TILE_SIZE)

	var fill := Polygon2D.new()
	fill.z_index = -2
	fill.color = BACKDROP_FILL_COLOR
	fill.polygon = PackedVector2Array([
		room_start,
		Vector2(room_end.x, room_start.y),
		room_end,
		Vector2(room_start.x, room_end.y),
	])
	add_child(fill)

	var border := Line2D.new()
	border.z_index = -1
	border.width = 2.0
	border.default_color = BACKDROP_BORDER_COLOR
	border.closed = true
	border.points = PackedVector2Array([
		room_start + Vector2(2.0, 2.0),
		Vector2(room_end.x - 2.0, room_start.y + 2.0),
		room_end - Vector2(2.0, 2.0),
		Vector2(room_start.x + 2.0, room_end.y - 2.0),
	])
	add_child(border)


func _add_hint_label() -> void:
	var label := Label.new()
	label.position = Vector2(_room.position.x * TILE_SIZE + 8.0, _room.position.y * TILE_SIZE + 6.0)
	label.size = Vector2(maxf(_room.size.x * TILE_SIZE - 16.0, 48.0), 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = LocaleManager.L("puzzle_order") % " -> ".join(PackedStringArray(_build_order_labels()))
	label.label_settings = _create_label_settings(Color(0.9, 0.96, 1.0, 1.0), Color(0.04, 0.08, 0.18, 1.0), 12)
	add_child(label)


func _add_switches() -> void:
	var center := _room_center_world()
	var room_radius := minf(_room.size.x * TILE_SIZE, _room.size.y * TILE_SIZE) * 0.3
	var offset_radius := clampf(room_radius, 18.0, 32.0)
	var offsets: Array[Vector2] = [
		Vector2(0.0, -offset_radius),
		Vector2(offset_radius, 0.0),
		Vector2(0.0, offset_radius),
		Vector2(-offset_radius, 0.0),
	]
	for switch_index in range(_switch_count):
		_add_switch(center + offsets[switch_index], switch_index)


func _add_switch(switch_position: Vector2, switch_index: int) -> void:
	var switch_area := Area2D.new()
	switch_area.position = switch_position
	switch_area.monitoring = true
	switch_area.monitorable = false
	switch_area.collision_layer = 0
	switch_area.collision_mask = 2
	switch_area.body_entered.connect(_on_switch_body_entered.bind(switch_index))
	add_child(switch_area)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	switch_area.add_child(collision)

	var plate := Polygon2D.new()
	plate.color = SWITCH_IDLE_COLOR
	plate.polygon = PackedVector2Array([
		Vector2(-9.0, -9.0),
		Vector2(9.0, -9.0),
		Vector2(9.0, 9.0),
		Vector2(-9.0, 9.0),
	])
	switch_area.add_child(plate)
	_switch_visuals.append(plate)

	var inset := Polygon2D.new()
	inset.color = SWITCH_IDLE_COLOR.lightened(0.18)
	inset.polygon = PackedVector2Array([
		Vector2(-5.0, -5.0),
		Vector2(5.0, -5.0),
		Vector2(5.0, 5.0),
		Vector2(-5.0, 5.0),
	])
	switch_area.add_child(inset)

	var number_label := Label.new()
	number_label.position = Vector2(-8.0, -12.0)
	number_label.size = Vector2(16.0, 16.0)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.text = str(switch_index + 1)
	number_label.label_settings = _create_label_settings(Color.WHITE, Color(0.05, 0.07, 0.16, 1.0), 11)
	switch_area.add_child(number_label)


func _on_switch_body_entered(body: Node, switch_index: int) -> void:
	if _completed or body == null or not body.is_in_group("player"):
		return
	if switch_index < _next_switch_index:
		return
	if switch_index == _next_switch_index:
		_activate_switch(switch_index)
		_next_switch_index += 1
		if _next_switch_index >= _switch_count:
			_complete_puzzle()
		return
	# Wrong order: deal 5 damage and reset
	if body.has_method("take_damage"):
		body.take_damage(5, Vector2.ZERO)
	_reset_switches()


func _activate_switch(switch_index: int) -> void:
	if switch_index < 0 or switch_index >= _switch_visuals.size():
		return
	_switch_visuals[switch_index].color = SWITCH_ACTIVE_COLOR


func _reset_switches() -> void:
	_next_switch_index = 0
	for plate in _switch_visuals:
		plate.color = SWITCH_IDLE_COLOR


func _complete_puzzle() -> void:
	if _completed:
		return
	_completed = true
	var chest = DUNGEON_CHEST_SCENE.instantiate()
	chest.global_position = _room_center_world()
	if chest.has_method("setup"):
		chest.setup(_loot_root, _floor_number)
	add_child(chest)


func _room_center_world() -> Vector2:
	var center_tile := _room.position + _room.size / 2
	return Vector2(center_tile.x * TILE_SIZE + 8.0, center_tile.y * TILE_SIZE + 8.0)


func _build_order_labels() -> Array[String]:
	var labels: Array[String] = []
	for switch_index in range(_switch_count):
		labels.append(str(switch_index + 1))
	return labels


func _create_label_settings(font_color: Color, outline_color: Color, font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_color = font_color
	settings.outline_color = outline_color
	settings.outline_size = 2
	settings.font_size = font_size
	return settings


func _rng_randf(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()
