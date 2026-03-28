extends Area2D
class_name TimedTreasureRoom

const COUNTDOWN_DURATION: float = 12.0
const LOCKDOWN_DURATION: float = 6.0

var room_rect: Rect2i = Rect2i()
var door_tiles: Array[Vector2i] = []
var active_player: Node = null

var _timer_started: bool = false
var _doors_closed: bool = false
var _resolved: bool = false
var _countdown_left: float = COUNTDOWN_DURATION
var _lockdown_left: float = 0.0

var trigger_shape: CollisionShape2D = null
var door_root: Node2D = null
var timer_label: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_build_nodes()
	_sync_trigger_shape()
	set_process(false)


func setup(target_room: Rect2i, target_door_tiles: Array[Vector2i]) -> void:
	room_rect = target_room
	door_tiles.clear()
	for door_tile: Vector2i in target_door_tiles:
		door_tiles.append(door_tile)
	if is_node_ready():
		_sync_trigger_shape()


func _process(delta: float) -> void:
	if not _timer_started or _resolved:
		return
	if not _doors_closed:
		_countdown_left = max(_countdown_left - delta, 0.0)
		_update_timer_label("Seal in %d" % int(ceil(_countdown_left)))
		if _countdown_left <= 0.0:
			_close_doors()
			_doors_closed = true
			_lockdown_left = LOCKDOWN_DURATION
			if active_player != null and active_player.has_method("show_status_message"):
				active_player.show_status_message("Treasure vault sealed", Color(1.0, 0.66, 0.28, 1.0), 2.0)
	else:
		_lockdown_left = max(_lockdown_left - delta, 0.0)
		_update_timer_label("Locked %d" % int(ceil(_lockdown_left)))
		if _lockdown_left <= 0.0:
			_open_doors()
			_update_timer_label("")
			_resolved = true
			set_process(false)


func _on_body_entered(body: Node) -> void:
	if _timer_started or body == null or not body.is_in_group("player"):
		return
	active_player = body
	_timer_started = true
	_countdown_left = COUNTDOWN_DURATION
	set_process(true)
	if active_player.has_method("show_status_message"):
		active_player.show_status_message("Grab what you can", Color(1.0, 0.88, 0.38, 1.0), 2.0)


func _build_nodes() -> void:
	trigger_shape = get_node_or_null("CollisionShape2D")
	if trigger_shape == null:
		trigger_shape = CollisionShape2D.new()
		trigger_shape.name = "CollisionShape2D"
		add_child(trigger_shape)

	door_root = get_node_or_null("DoorRoot")
	if door_root == null:
		door_root = Node2D.new()
		door_root.name = "DoorRoot"
		door_root.z_index = 4
		add_child(door_root)

	timer_label = get_node_or_null("TimerLabel")
	if timer_label == null:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.size = Vector2(120.0, 18.0)
		timer_label.position = Vector2(-60.0, -34.0)
		timer_label.add_theme_font_size_override("font_size", 12)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56, 1.0))
		timer_label.add_theme_color_override("font_outline_color", Color(0.24, 0.12, 0.02, 1.0))
		timer_label.add_theme_constant_override("outline_size", 2)
		add_child(timer_label)


func _sync_trigger_shape() -> void:
	if trigger_shape == null or room_rect.size == Vector2i.ZERO:
		return
	var world_size: Vector2 = Vector2(room_rect.size.x * 16, room_rect.size.y * 16)
	global_position = Vector2(room_rect.position.x * 16, room_rect.position.y * 16) + world_size * 0.5
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(max(world_size.x - 12.0, 16.0), max(world_size.y - 12.0, 16.0))
	trigger_shape.shape = shape


func _close_doors() -> void:
	if door_root == null:
		return
	for child: Node in door_root.get_children():
		child.queue_free()
	for door_tile: Vector2i in door_tiles:
		door_root.add_child(_create_door_blocker(door_tile))


func _open_doors() -> void:
	if door_root == null:
		return
	for child: Node in door_root.get_children():
		child.queue_free()


func _create_door_blocker(tile_pos: Vector2i) -> Node2D:
	var blocker_root: Node2D = Node2D.new()
	blocker_root.global_position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)

	var blocker_body: StaticBody2D = StaticBody2D.new()
	blocker_body.collision_layer = 1
	blocker_body.collision_mask = 0
	blocker_root.add_child(blocker_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(16.0, 16.0)
	collision_shape.shape = shape
	blocker_body.add_child(collision_shape)

	var panel: Polygon2D = Polygon2D.new()
	panel.polygon = PackedVector2Array([
		Vector2(-7.0, -7.0),
		Vector2(7.0, -7.0),
		Vector2(7.0, 7.0),
		Vector2(-7.0, 7.0),
	])
	panel.color = Color(0.86, 0.58, 0.16, 0.96)
	blocker_root.add_child(panel)

	var bar: Line2D = Line2D.new()
	bar.width = 2.0
	bar.default_color = Color(1.0, 0.95, 0.72, 1.0)
	bar.points = PackedVector2Array([Vector2(-5.0, 0.0), Vector2(5.0, 0.0)])
	blocker_root.add_child(bar)

	return blocker_root


func _update_timer_label(text_value: String) -> void:
	if timer_label == null:
		return
	timer_label.text = text_value
