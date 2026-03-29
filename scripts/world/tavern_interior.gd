extends Node2D
class_name TavernInterior

## Walkable tavern interior scene.
## 15x10 tile room with 3 interactable NPCs and an exit door.

signal exit_tavern_requested

const TILE: int = 32
const ROOM_W: int = 15
const ROOM_H: int = 10
const DOOR_TILES: int = 3
const DOOR_X: int = (ROOM_W - DOOR_TILES) / 2 * TILE  # 192 px
const DOOR_W: int = DOOR_TILES * TILE                  # 96 px

const FLOOR_COLOR: Color = Color(0.22, 0.15, 0.10, 1.0)
const WALL_COLOR: Color = Color(0.30, 0.20, 0.13, 1.0)
const WALL_TOP_COLOR: Color = Color(0.38, 0.24, 0.14, 1.0)
const DOOR_COLOR: Color = Color(0.50, 0.33, 0.18, 1.0)


func _ready() -> void:
	_build_room()
	_build_npcs()
	_build_exit_npc()


func get_spawn_position() -> Vector2:
	return Vector2(float(ROOM_W * TILE) * 0.5, float((ROOM_H - 3) * TILE))


func _build_room() -> void:
	# Floor
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.size = Vector2(float(ROOM_W * TILE), float(ROOM_H * TILE))
	add_child(floor_rect)

	# Walls (visual + physics)
	_add_wall(
		Vector2.ZERO,
		Vector2(float(ROOM_W * TILE), float(TILE)),
		WALL_TOP_COLOR
	)
	_add_wall(
		Vector2(0.0, float(TILE)),
		Vector2(float(TILE), float((ROOM_H - 2) * TILE)),
		WALL_COLOR
	)
	_add_wall(
		Vector2(float((ROOM_W - 1) * TILE), float(TILE)),
		Vector2(float(TILE), float((ROOM_H - 2) * TILE)),
		WALL_COLOR
	)
	# Bottom wall — left of door
	_add_wall(
		Vector2(0.0, float((ROOM_H - 1) * TILE)),
		Vector2(float(DOOR_X), float(TILE)),
		WALL_COLOR
	)
	# Bottom wall — right of door
	_add_wall(
		Vector2(float(DOOR_X + DOOR_W), float((ROOM_H - 1) * TILE)),
		Vector2(float(ROOM_W * TILE) - float(DOOR_X + DOOR_W), float(TILE)),
		WALL_COLOR
	)

	# Door visual (no collision — acts as exit zone)
	var door_vis: ColorRect = ColorRect.new()
	door_vis.color = DOOR_COLOR
	door_vis.size = Vector2(float(DOOR_W), float(TILE))
	door_vis.position = Vector2(float(DOOR_X), float((ROOM_H - 1) * TILE))
	add_child(door_vis)

	# Bar counter (decorative)
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(0.42, 0.26, 0.12, 1.0)
	bar.size = Vector2(float(ROOM_W * TILE) - float(2 * TILE) - 10.0, float(TILE / 2) + 6.0)
	bar.position = Vector2(float(TILE) + 5.0, float(2 * TILE) - 2.0)
	add_child(bar)

	# Tavern sign
	var sign_lbl: Label = Label.new()
	sign_lbl.text = "地下酒館"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 18)
	sign_lbl.modulate = Color(1.0, 0.85, 0.4, 1.0)
	sign_lbl.position = Vector2(float(ROOM_W * TILE) * 0.5 - 50.0, 4.0)
	add_child(sign_lbl)


func _add_wall(pos: Vector2, size: Vector2, color: Color) -> void:
	var vis: ColorRect = ColorRect.new()
	vis.color = color
	vis.size = size
	vis.position = pos
	add_child(vis)
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos + size * 0.5
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _build_npcs() -> void:
	_add_npc(
		Vector2(float(3 * TILE), float(3 * TILE)),
		"slots", "酒保", "[E] 老虎機", Color(0.85, 0.6, 0.25, 1.0)
	)
	_add_npc(
		Vector2(float(7 * TILE), float(3 * TILE)),
		"pachinko", "賭徒", "[E] 彈珠台", Color(0.35, 0.65, 0.95, 1.0)
	)
	_add_npc(
		Vector2(float(11 * TILE), float(3 * TILE)),
		"merchant", "神秘商人", "[E] 交易", Color(0.65, 0.25, 0.85, 1.0)
	)


func _add_npc(world_pos: Vector2, npc_type: String, npc_name: String, prompt: String, color: Color) -> void:
	var npc_node: TavernNpc = TavernNpc.new()
	npc_node.npc_type = npc_type
	npc_node.prompt_text = prompt
	npc_node.position = world_pos + Vector2(float(TILE) * 0.5, 0.0)

	# Head
	var head: ColorRect = ColorRect.new()
	head.color = color.lightened(0.3)
	head.size = Vector2(18.0, 18.0)
	head.position = Vector2(-9.0, -58.0)
	npc_node.add_child(head)

	# Body
	var body_rect: ColorRect = ColorRect.new()
	body_rect.color = color
	body_rect.size = Vector2(22.0, 36.0)
	body_rect.position = Vector2(-11.0, -40.0)
	npc_node.add_child(body_rect)

	# Name label
	var name_lbl: Label = Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(1.0, 1.0, 0.75, 1.0)
	name_lbl.position = Vector2(-22.0, -75.0)
	npc_node.add_child(name_lbl)

	# Interaction detection area
	var area: Area2D = Area2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = circle
	area.add_child(col_shape)
	npc_node.add_child(area)

	add_child(npc_node)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			exit_tavern_requested.emit()
			get_viewport().set_input_as_handled()


func _build_exit_npc() -> void:
	var exit_node: TavernNpc = TavernNpc.new()
	exit_node.npc_type = "exit"
	exit_node.prompt_text = "[E] 離開酒館"
	exit_node.position = Vector2(
		float(ROOM_W * TILE) * 0.5,
		float((ROOM_H - 1) * TILE) + float(TILE) * 0.5
	)

	var lbl: Label = Label.new()
	lbl.text = "[E] 出口"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.9, 0.8, 0.5, 1.0)
	lbl.position = Vector2(-18.0, -12.0)
	exit_node.add_child(lbl)

	var area: Area2D = Area2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(float(DOOR_W) - 8.0, float(TILE) + 16.0)
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = rect_shape
	area.add_child(col_shape)
	exit_node.add_child(area)

	add_child(exit_node)
