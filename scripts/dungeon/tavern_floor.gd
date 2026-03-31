extends Node2D

## Underground tavern — Floor 0, fixed layout, no random generation.
## Serves as a preparation lobby between the overworld and the dungeon.

signal enter_dungeon_requested(floor_number: int)
signal return_to_surface_requested

const TILE: int = 32
const ROOM_W: int = 15
const ROOM_H: int = 10

const STAIRWAY_SCENE: PackedScene = preload("res://scenes/dungeon/stairway.tscn")
const DUNGEON_MERCHANT_SCRIPT: Script = preload("res://scripts/dungeon/dungeon_merchant.gd")
const FLOOR_TELEPORTER_SCRIPT: Script = preload("res://scripts/dungeon/floor_teleporter_npc.gd")

const FLOOR_COLOR: Color = Color(0.18, 0.14, 0.10, 1.0)
const WALL_COLOR: Color = Color(0.24, 0.17, 0.11, 1.0)
const WALL_TOP_COLOR: Color = Color(0.30, 0.21, 0.13, 1.0)


func _ready() -> void:
	_build_room()
	_build_npcs()
	_build_stairways()
	_maybe_spawn_dark_wizard()


func get_spawn_position() -> Vector2:
	return Vector2(float(ROOM_W * TILE) * 0.5, float((ROOM_H - 2) * TILE))


func place_player(new_player: Node, spawn_pos: Vector2) -> void:
	new_player.reparent(self)
	new_player.global_position = spawn_pos if spawn_pos.length_squared() > 0.0 else get_spawn_position()


func _build_room() -> void:
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.size = Vector2(float(ROOM_W * TILE), float(ROOM_H * TILE))
	add_child(floor_rect)

	# Top wall
	_add_wall(Vector2.ZERO, Vector2(float(ROOM_W * TILE), float(TILE)), WALL_TOP_COLOR)
	# Left wall
	_add_wall(Vector2(0.0, float(TILE)), Vector2(float(TILE), float((ROOM_H - 2) * TILE)), WALL_COLOR)
	# Right wall
	_add_wall(
		Vector2(float((ROOM_W - 1) * TILE), float(TILE)),
		Vector2(float(TILE), float((ROOM_H - 2) * TILE)),
		WALL_COLOR
	)
	# Bottom wall
	_add_wall(Vector2(0.0, float((ROOM_H - 1) * TILE)), Vector2(float(ROOM_W * TILE), float(TILE)), WALL_COLOR)

	# Bar counter (decorative)
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(0.35, 0.22, 0.10, 1.0)
	bar.size = Vector2(float(ROOM_W * TILE) - float(2 * TILE) - 10.0, float(TILE / 2) + 6.0)
	bar.position = Vector2(float(TILE) + 5.0, float(2 * TILE) - 2.0)
	add_child(bar)

	# Tavern sign
	var sign_lbl: Label = Label.new()
	sign_lbl.text = "地下酒館 — Floor 0"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 18)
	sign_lbl.modulate = Color(1.0, 0.85, 0.4, 1.0)
	sign_lbl.position = Vector2(float(ROOM_W * TILE) * 0.5 - 88.0, 4.0)
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
	# Slots bartender
	_add_tavern_npc(
		Vector2(float(2 * TILE), float(3 * TILE)),
		"slots", "酒保", "[E] 老虎機", Color(0.85, 0.60, 0.25, 1.0)
	)
	# Pachinko gambler
	_add_tavern_npc(
		Vector2(float(5 * TILE), float(3 * TILE)),
		"pachinko", "賭徒", "[E] 彈珠台", Color(0.35, 0.65, 0.95, 1.0)
	)

	# Dungeon merchant — Area2D with DungeonMerchant script, self-initialises in _ready
	var merchant: Area2D = Area2D.new()
	merchant.set_script(DUNGEON_MERCHANT_SCRIPT)
	merchant.position = Vector2(float(11 * TILE), float(3 * TILE))
	add_child(merchant)

	# Floor teleporter NPC
	var teleporter: Node2D = Node2D.new()
	teleporter.set_script(FLOOR_TELEPORTER_SCRIPT)
	teleporter.position = Vector2(float(8 * TILE), float(6 * TILE))
	add_child(teleporter)
	if teleporter.has_signal("floor_selected"):
		teleporter.floor_selected.connect(_on_teleporter_floor_selected)


func _add_tavern_npc(
	world_pos: Vector2,
	npc_type: String,
	npc_name: String,
	prompt: String,
	color: Color
) -> void:
	var npc_node: TavernNpc = TavernNpc.new()
	npc_node.npc_type = npc_type
	npc_node.prompt_text = prompt
	npc_node.position = world_pos + Vector2(float(TILE) * 0.5, 0.0)

	var head: ColorRect = ColorRect.new()
	head.color = color.lightened(0.3)
	head.size = Vector2(18.0, 18.0)
	head.position = Vector2(-9.0, -58.0)
	npc_node.add_child(head)

	var body_rect: ColorRect = ColorRect.new()
	body_rect.color = color
	body_rect.size = Vector2(22.0, 36.0)
	body_rect.position = Vector2(-11.0, -40.0)
	npc_node.add_child(body_rect)

	var name_lbl: Label = Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(1.0, 1.0, 0.75, 1.0)
	name_lbl.position = Vector2(-22.0, -75.0)
	npc_node.add_child(name_lbl)

	var area: Area2D = Area2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = circle
	area.add_child(col_shape)
	npc_node.add_child(area)

	add_child(npc_node)


func _on_teleporter_floor_selected(floor_number: int) -> void:
	enter_dungeon_requested.emit(floor_number)


func _build_stairways() -> void:
	# Down stairway — primary interact → enter dungeon Floor 1
	var down_stair: Node = STAIRWAY_SCENE.instantiate()
	down_stair.position = Vector2(float(4 * TILE), float(7 * TILE))
	down_stair.set("prompt_text", "[E] 進入地牢")
	add_child(down_stair)
	if down_stair.has_signal("descend_requested"):
		down_stair.descend_requested.connect(_on_down_stair_activated)

	var down_lbl: Label = Label.new()
	down_lbl.text = "[E] 進入地牢"
	down_lbl.add_theme_font_size_override("font_size", 10)
	down_lbl.modulate = Color(1.0, 0.90, 0.50, 1.0)
	down_lbl.position = Vector2(float(4 * TILE) - 22.0, float(7 * TILE) - 34.0)
	add_child(down_lbl)

	# Up stairway — primary interact → return to overworld
	var up_stair: Node = STAIRWAY_SCENE.instantiate()
	up_stair.position = Vector2(float(10 * TILE), float(7 * TILE))
	up_stair.set("stair_variant", "up")
	up_stair.set("prompt_text", "[E] 返回地表")
	add_child(up_stair)
	if up_stair.has_signal("descend_requested"):
		up_stair.descend_requested.connect(_on_up_stair_activated)

	var up_lbl: Label = Label.new()
	up_lbl.text = "[E] 返回地表"
	up_lbl.add_theme_font_size_override("font_size", 10)
	up_lbl.modulate = Color(0.75, 0.90, 1.0, 1.0)
	up_lbl.position = Vector2(float(10 * TILE) - 22.0, float(7 * TILE) - 34.0)
	add_child(up_lbl)


func _on_down_stair_activated() -> void:
	enter_dungeon_requested.emit(1)


func _on_up_stair_activated() -> void:
	return_to_surface_requested.emit()


func _maybe_spawn_dark_wizard() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() >= 0.20:
		return
	_add_dark_wizard(Vector2(float(6 * TILE), float(6 * TILE)))


func _add_dark_wizard(world_pos: Vector2) -> void:
	var color: Color = Color(0.40, 0.15, 0.55, 1.0)
	var npc_node: TavernNpc = TavernNpc.new()
	npc_node.npc_type = "dark_wizard"
	npc_node.prompt_text = "[E] 除咒（2 金幣）"
	npc_node.position = world_pos

	var head: ColorRect = ColorRect.new()
	head.color = color.lightened(0.2)
	head.size = Vector2(18.0, 18.0)
	head.position = Vector2(-9.0, -58.0)
	npc_node.add_child(head)

	var body_rect: ColorRect = ColorRect.new()
	body_rect.color = color
	body_rect.size = Vector2(22.0, 36.0)
	body_rect.position = Vector2(-11.0, -40.0)
	npc_node.add_child(body_rect)

	var name_lbl: Label = Label.new()
	name_lbl.text = "暗黑巫師"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.85, 0.55, 1.0, 1.0)
	name_lbl.position = Vector2(-22.0, -75.0)
	npc_node.add_child(name_lbl)

	var area: Area2D = Area2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = circle
	area.add_child(col_shape)
	npc_node.add_child(area)

	add_child(npc_node)
