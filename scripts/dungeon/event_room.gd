extends Area2D
class_name EventRoom

const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")
const BUFF_SYSTEM := preload("res://scripts/dungeon/buff_system.gd")

const PROMPT_READY := "[E] Investigate the mysterious altar"
const PROMPT_USED := "[E] The altar has gone silent"

enum EventType {
	GAMBLE,
	CURSE,
	TREASURE,
}

static var _altar_texture: Texture2D = null

@export var floor_number: int = 1

var loot_root: Node = null
var rng := RandomNumberGenerator.new()
var is_used: bool = false
var pending_event_type: int = -1

var sprite: Sprite2D = null
var title_label: Label = null


func _ready() -> void:
	monitoring = true
	monitorable = true
	_build_visuals()
	_refresh_visual_state()


func setup(target_loot_root: Node, target_floor_number: int, seed_value: int) -> void:
	loot_root = target_loot_root
	floor_number = target_floor_number
	rng.seed = seed_value


func get_interaction_prompt() -> String:
	return PROMPT_USED if is_used else PROMPT_READY


func interact(player) -> void:
	if is_used or player == null:
		return
	if pending_event_type < 0:
		pending_event_type = rng.randi_range(0, 2)

	var did_resolve := false
	match pending_event_type:
		EventType.GAMBLE:
			did_resolve = _resolve_gamble(player)
		EventType.CURSE:
			did_resolve = _resolve_curse(player)
		EventType.TREASURE:
			did_resolve = _resolve_treasure(player)

	if not did_resolve:
		return

	is_used = true
	_refresh_visual_state()


func _build_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 14.0
		collision.shape = shape
		add_child(collision)

	if get_node_or_null("Aura") == null:
		var aura := Polygon2D.new()
		aura.name = "Aura"
		aura.color = Color(0.56, 0.18, 0.78, 0.30)
		aura.polygon = PackedVector2Array([
			Vector2(-18, -8),
			Vector2(0, -20),
			Vector2(18, -8),
			Vector2(12, 12),
			Vector2(-12, 12),
		])
		add_child(aura)
		var tween := create_tween().set_loops()
		tween.tween_property(aura, "modulate:a", 0.55, 0.8)
		tween.tween_property(aura, "modulate:a", 0.22, 0.8)

	sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = _get_altar_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)

	title_label = get_node_or_null("TitleLabel")
	if title_label == null:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.position = Vector2(-52, -34)
		title_label.size = Vector2(104, 18)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.add_theme_color_override("font_color", Color(0.93, 0.82, 1.0, 1.0))
		title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 1.0))
		title_label.add_theme_constant_override("outline_size", 2)
		add_child(title_label)


func _refresh_visual_state() -> void:
	if sprite != null:
		sprite.modulate = Color(0.56, 0.56, 0.64, 0.95) if is_used else Color(1.0, 1.0, 1.0, 1.0)
	if title_label != null:
		title_label.text = "Dormant Altar" if is_used else "Mysterious Altar"


func _resolve_gamble(player) -> bool:
	var inventory = player.get("inventory")
	if inventory == null or not inventory.has_method("pay_copper"):
		return false
	if not inventory.pay_copper(50):
		_show_status(player, "The altar demands 50 copper.", Color(1.0, 0.66, 0.35, 1.0))
		return false

	_show_floating_text(player, "-50 Copper", Color(1.0, 0.72, 0.32, 1.0))
	if rng.randf() <= 0.5:
		_spawn_item_drop("copper", 200)
		_show_status(player, "Jackpot. The altar pays out.", Color(1.0, 0.92, 0.42, 1.0))
	else:
		_show_status(player, "The altar keeps your offering.", Color(0.75, 0.72, 0.82, 1.0))
	return true


func _resolve_curse(player) -> bool:
	var max_hp := int(player.get("max_hp"))
	var current_hp := int(player.get("current_hp"))
	var health_cost := maxi(int(ceil(float(max_hp) * 0.20)), 1)
	if current_hp <= health_cost:
		_show_status(player, "You need more HP to survive the ritual.", Color(1.0, 0.45, 0.45, 1.0))
		return false

	player.set("current_hp", current_hp - health_cost)
	if player.has_signal("hp_changed"):
		player.emit_signal("hp_changed", int(player.get("current_hp")), max_hp)
	_show_floating_text(player, "-%d HP" % health_cost, Color(1.0, 0.45, 0.45, 1.0))

	var buff_pool := BUFF_SYSTEM.get_buff_pool()
	if buff_pool.is_empty():
		return true
	var buff: Dictionary = buff_pool[rng.randi_range(0, buff_pool.size() - 1)]
	var buff_id := str(buff.get("id", ""))
	if buff_id != "" and player.has_method("apply_buff"):
		player.apply_buff(buff_id)
	var display_name := buff_id.replace("_", " ").capitalize()
	_show_status(player, "A curse becomes a blessing: %s." % display_name, Color(0.72, 1.0, 0.78, 1.0))
	return true


func _resolve_treasure(player) -> bool:
	var equipment := DUNGEON_LOOT.generate_dungeon_equipment(max(floor_number, 1), rng)
	_spawn_stack_drop(equipment)
	_show_status(player, "Treasure erupts from the altar.", Color(0.72, 0.92, 1.0, 1.0))
	return true


func _spawn_item_drop(item_id: String, quantity: int) -> void:
	if loot_root == null:
		loot_root = get_parent()
	if loot_root == null:
		return
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	drop.setup(item_id, quantity)
	loot_root.add_child(drop)


func _spawn_stack_drop(stack_data: Dictionary) -> void:
	if loot_root == null:
		loot_root = get_parent()
	if loot_root == null:
		return
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	drop.setup_stack(stack_data)
	loot_root.add_child(drop)


func _show_status(player, message: String, color: Color) -> void:
	if player != null and player.has_method("show_status_message"):
		player.show_status_message(message, color, 2.2)


func _show_floating_text(player, message: String, color: Color) -> void:
	if player != null and player.has_method("_show_floating_text"):
		player._show_floating_text(global_position, message, color)


static func _get_altar_texture() -> Texture2D:
	if _altar_texture != null:
		return _altar_texture

	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(14, 22):
		for x in range(5, 19):
			image.set_pixel(x, y, Color(0.22, 0.18, 0.32, 1.0))
	for y in range(10, 14):
		for x in range(8, 16):
			image.set_pixel(x, y, Color(0.30, 0.24, 0.44, 1.0))
	for y in range(5, 10):
		for x in range(7, 17):
			var pixel_color := Color(0.44, 0.24, 0.62, 1.0)
			if x >= 10 and x <= 13 and y <= 7:
				pixel_color = Color(0.88, 0.66, 1.0, 1.0)
			image.set_pixel(x, y, pixel_color)
	for y in range(3, 6):
		for x in range(10, 14):
			image.set_pixel(x, y, Color(0.96, 0.86, 1.0, 0.95))

	_altar_texture = ImageTexture.create_from_image(image)
	return _altar_texture
