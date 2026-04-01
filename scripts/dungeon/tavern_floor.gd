extends Node2D

## Underground tavern — Floor 0, fixed layout, no random generation.
## Serves as a preparation lobby between the overworld and the dungeon.
##
## Layout (20 x 15 tiles):
##   Row 0        : top wall (wall_top)
##   Rows 1-5     : upper rooms
##       Cols 1-8   = bartender room (bar crates + dwarf)
##       Col  9     = vertical wall, gap rows 3-4
##       Cols 10-18 = gambler room (lizard + merchant)
##   Row 6        : horizontal wall, gaps cols 4-5 / 14-15
##   Rows 7-13    : lower open area
##       Left side  = spawn + return-to-surface stairs
##       Right wall = dungeon entrance (embedded, scaled up)
##       Right side = teleporter next to dungeon entrance
##   Row 14       : bottom wall

signal enter_dungeon_requested(floor_number: int)
signal return_to_surface_requested

const TILE: int = 32
const ROOM_W: int = 20
const ROOM_H: int = 15

const STAIRWAY_SCENE: PackedScene = preload("res://scenes/dungeon/stairway.tscn")
const DUNGEON_MERCHANT_SCRIPT: Script = preload("res://scripts/dungeon/dungeon_merchant.gd")
const FLOOR_TELEPORTER_SCRIPT: Script = preload("res://scripts/dungeon/floor_teleporter_npc.gd")
const CLASS_MASTER_SCRIPT: Script = preload("res://scripts/dungeon/class_master_npc.gd")

const TEX_FLOOR: Texture2D = preload("res://assets/floor_5.png")
const TEX_WALL_MID: Texture2D = preload("res://assets/wall_mid.png")
const TEX_WALL_TOP: Texture2D = preload("res://assets/wall_top_center.png")
const TEX_CRATE: Texture2D = preload("res://assets/crate.png")
const TEX_DWARF: Texture2D = preload("res://assets/dwarf_m_idle_anim_f0.png")
const TEX_LIZARD: Texture2D = preload("res://assets/lizard_m_idle_anim_f0.png")
const TEX_DOC: Texture2D = preload("res://assets/doc_idle_anim_f0.png")
const TEX_WIZARD: Texture2D = preload("res://assets/wizzard_m_idle_anim_f0.png")

# 16 px textures scaled 2x to fill 32 px grid — eliminates black gaps
const TILE_SCALE: Vector2 = Vector2(2.0, 2.0)


func _ready() -> void:
	_build_room()
	_build_npcs()
	_build_stairways()
	_maybe_spawn_dark_wizard()


func get_spawn_position() -> Vector2:
	# Left side, near the return-to-surface stairs
	return Vector2(float(2 * TILE), float(9 * TILE))


func place_player(new_player: Node, spawn_pos: Vector2) -> void:
	new_player.reparent(self)
	new_player.global_position = spawn_pos if spawn_pos.length_squared() > 0.0 else get_spawn_position()


# ---------------------------------------------------------------------------
# Room construction
# ---------------------------------------------------------------------------

func _build_room() -> void:
	# Dark background to cover any sub-pixel seams
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.1, 1.0)
	bg.size = Vector2(float(ROOM_W * TILE), float(ROOM_H * TILE))
	bg.z_index = -1
	add_child(bg)

	# Collect wall positions
	var walls: Dictionary = {}
	_define_walls(walls)

	# Floor — fill entire interior; walls draw on top
	for ty: int in range(1, ROOM_H - 1):
		for tx: int in range(1, ROOM_W - 1):
			_place_tile(TEX_FLOOR, Vector2(float(tx * TILE), float(ty * TILE)))

	# Walls
	for pos: Variant in walls.keys():
		var v: Vector2i = pos as Vector2i
		var tex: Texture2D = TEX_WALL_TOP if v.y == 0 else TEX_WALL_MID
		_add_wall_tile(tex, Vector2(float(v.x * TILE), float(v.y * TILE)), Vector2(float(TILE), float(TILE)))

	# Bar counter — crates in upper-left room
	for bx: int in range(2, 8):
		_place_tile(TEX_CRATE, Vector2(float(bx * TILE), float(2 * TILE)))

	# Tavern sign on top wall
	var sign_lbl: Label = Label.new()
	sign_lbl.text = "地下酒館 — Floor 0"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 18)
	sign_lbl.modulate = Color(1.0, 0.85, 0.4, 1.0)
	sign_lbl.position = Vector2(float(ROOM_W * TILE) * 0.5 - 88.0, 4.0)
	sign_lbl.z_index = 2
	add_child(sign_lbl)


func _define_walls(walls: Dictionary) -> void:
	# --- outer border ---
	for x: int in range(ROOM_W):
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, ROOM_H - 1)] = true
	for y: int in range(1, ROOM_H - 1):
		walls[Vector2i(0, y)] = true
	# Right wall with gap for dungeon entrance (rows 8-10 open)
	for y: int in range(1, ROOM_H - 1):
		if y == 8 or y == 9 or y == 10:
			continue
		walls[Vector2i(ROOM_W - 1, y)] = true

	# --- upper vertical divider: col 9, rows 1-5, gap rows 3-4 ---
	for y: int in [1, 2, 5]:
		walls[Vector2i(9, y)] = true

	# --- horizontal divider row 6, gaps at cols 4-5 and 14-15 ---
	for x: int in range(1, ROOM_W - 1):
		if x == 4 or x == 5 or x == 14 or x == 15:
			continue
		walls[Vector2i(x, 6)] = true


# ---------------------------------------------------------------------------
# Tile helpers
# ---------------------------------------------------------------------------

func _place_tile(tex: Texture2D, pos: Vector2) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = TILE_SCALE
	spr.centered = false
	spr.position = pos
	add_child(spr)


func _add_wall_tile(tex: Texture2D, pos: Vector2, size: Vector2) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.scale = TILE_SCALE
	spr.centered = false
	spr.position = pos
	spr.z_index = 1
	add_child(spr)

	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos + size * 0.5
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


# ---------------------------------------------------------------------------
# NPCs
# ---------------------------------------------------------------------------

func _build_npcs() -> void:
	# Upper-left room — bartender merchant (dwarf sprite, tavern-specific items)
	var bartender: Area2D = Area2D.new()
	bartender.set_script(DUNGEON_MERCHANT_SCRIPT)
	bartender.position = Vector2(float(4 * TILE), float(4 * TILE))
	bartender.set("override_title", "酒保 — 買賣")
	bartender.set("override_items", [
		{"id": "stew", "quantity": 1, "price": 12},
		{"id": "bread", "quantity": 2, "price": 3},
		{"id": "bandage", "quantity": 3, "price": 2},
	])
	# Pre-add dwarf Sprite2D so DungeonMerchant._ensure_visuals() keeps it
	var bar_spr: Sprite2D = Sprite2D.new()
	bar_spr.name = "Sprite2D"
	bar_spr.texture = TEX_DWARF
	bar_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bartender.add_child(bar_spr)
	add_child(bartender)

	# Upper-right room — gambler (lizard) — opens slot machine / pachinko tabs
	_add_tavern_npc(
		Vector2(float(13 * TILE), float(3 * TILE)),
		"pachinko", "賭徒", "[E] 賭徒 — 試試手氣", TEX_LIZARD
	)

	# Upper-right room — tavern merchant (consumables only, no dungeon specials)
	var merchant: Area2D = Area2D.new()
	merchant.set_script(DUNGEON_MERCHANT_SCRIPT)
	merchant.position = Vector2(float(16 * TILE), float(3 * TILE))
	merchant.set("override_items", [
		{"id": "bandage", "quantity": 1, "price": 5},
		{"id": "bread", "quantity": 1, "price": 5},
		{"id": "torch", "quantity": 3, "price": 6},
	])
	add_child(merchant)

	# Right side — floor teleporter, next to dungeon entrance
	var teleporter: Node2D = Node2D.new()
	teleporter.set_script(FLOOR_TELEPORTER_SCRIPT)
	teleporter.position = Vector2(float(16 * TILE), float(9 * TILE))
	add_child(teleporter)
	if teleporter.has_signal("floor_selected"):
		teleporter.floor_selected.connect(_on_teleporter_floor_selected)

	# Lower corridor — class master NPC
	var class_master: Area2D = Area2D.new()
	class_master.set_script(CLASS_MASTER_SCRIPT)
	class_master.position = Vector2(float(10 * TILE), float(10 * TILE))
	var cm_sprite: Sprite2D = Sprite2D.new()
	cm_sprite.texture = TEX_DOC
	cm_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cm_sprite.position = Vector2(0.0, -24.0)
	class_master.add_child(cm_sprite)
	var cm_lbl: Label = Label.new()
	cm_lbl.text = "職業大師"
	cm_lbl.add_theme_font_size_override("font_size", 11)
	cm_lbl.modulate = Color(0.9, 0.85, 0.5, 1.0)
	cm_lbl.position = Vector2(-22.0, -55.0)
	class_master.add_child(cm_lbl)
	add_child(class_master)


func _add_tavern_npc(
	world_pos: Vector2,
	npc_type: String,
	npc_name: String,
	prompt: String,
	tex: Texture2D
) -> void:
	var npc_node: TavernNpc = TavernNpc.new()
	npc_node.npc_type = npc_type
	npc_node.prompt_text = prompt
	npc_node.position = world_pos + Vector2(float(TILE) * 0.5, 0.0)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(1.0, 1.0)
	sprite.position = Vector2(0.0, -24.0)
	npc_node.add_child(sprite)

	var name_lbl: Label = Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(1.0, 1.0, 0.75, 1.0)
	name_lbl.position = Vector2(-22.0, -55.0)
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


# ---------------------------------------------------------------------------
# Stairways
# ---------------------------------------------------------------------------

func _build_stairways() -> void:
	# Left side — up stairs (return to surface), near spawn
	var up_stair: Node = STAIRWAY_SCENE.instantiate()
	up_stair.position = Vector2(float(2 * TILE), float(11 * TILE))
	up_stair.set("stair_variant", "up")
	up_stair.set("prompt_text", "[E] 返回地表")
	add_child(up_stair)
	if up_stair.has_signal("descend_requested"):
		up_stair.descend_requested.connect(_on_up_stair_activated)

	var up_lbl: Label = Label.new()
	up_lbl.text = "[E] 返回地表"
	up_lbl.add_theme_font_size_override("font_size", 10)
	up_lbl.modulate = Color(0.75, 0.90, 1.0, 1.0)
	up_lbl.position = Vector2(float(2 * TILE) - 22.0, float(11 * TILE) - 34.0)
	add_child(up_lbl)

	# Right wall — down stairs (enter dungeon), embedded in wall gap
	var down_stair: Node = STAIRWAY_SCENE.instantiate()
	# Position at the right wall opening (rows 8-10)
	down_stair.position = Vector2(float(18 * TILE) + 16.0, float(9 * TILE))
	down_stair.set("prompt_text", "[E] 進入地牢")
	add_child(down_stair)
	if down_stair.has_signal("descend_requested"):
		down_stair.descend_requested.connect(_on_down_stair_activated)
	# Scale the stairway sprite to fill the wall opening (3 tiles tall)
	var stair_sprite: Node = down_stair.get_node_or_null("Sprite2D")
	if stair_sprite != null:
		stair_sprite.set("scale", Vector2(2.0, 2.0))

	var down_lbl: Label = Label.new()
	down_lbl.text = "[E] 進入地牢"
	down_lbl.add_theme_font_size_override("font_size", 10)
	down_lbl.modulate = Color(1.0, 0.90, 0.50, 1.0)
	down_lbl.position = Vector2(float(17 * TILE), float(8 * TILE) - 10.0)
	add_child(down_lbl)


func _on_down_stair_activated() -> void:
	enter_dungeon_requested.emit(1)


func _on_up_stair_activated() -> void:
	return_to_surface_requested.emit()


# ---------------------------------------------------------------------------
# Dark wizard (20 % spawn chance)
# ---------------------------------------------------------------------------

func _maybe_spawn_dark_wizard() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() >= 0.20:
		return
	# Spawns in the corridor area
	_add_dark_wizard(Vector2(float(10 * TILE), float(9 * TILE)))


func _add_dark_wizard(world_pos: Vector2) -> void:
	var npc_node: TavernNpc = TavernNpc.new()
	npc_node.npc_type = "dark_wizard"
	npc_node.prompt_text = "[E] 除咒（2 金幣）"
	npc_node.position = world_pos

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = TEX_WIZARD
	sprite.scale = Vector2(1.0, 1.0)
	sprite.position = Vector2(0.0, -24.0)
	npc_node.add_child(sprite)

	var name_lbl: Label = Label.new()
	name_lbl.text = "暗黑巫師"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.85, 0.55, 1.0, 1.0)
	name_lbl.position = Vector2(-22.0, -55.0)
	npc_node.add_child(name_lbl)

	var area: Area2D = Area2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = circle
	area.add_child(col_shape)
	npc_node.add_child(area)

	add_child(npc_node)
