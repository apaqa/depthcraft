extends Area2D
class_name LootDrop

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")

@export var item_id: String = "talent_shard"
@export var quantity: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var stack_data: Dictionary = {}
var _player_ref: Node = null
var _spawn_delay: float = 0.0


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not lifetime_timer.timeout.is_connected(queue_free):
		lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()
	_update_icon()
	_find_player.call_deferred()
	if _is_equipment():
		_setup_equipment_visuals()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]


func _physics_process(delta: float) -> void:
	if _spawn_delay > 0:
		_spawn_delay -= delta
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var dist := global_position.distance_to(_player_ref.global_position)
	var pickup_range := 30.0
	if _player_ref.has_method("get_loot_pickup_range"):
		pickup_range = _player_ref.get_loot_pickup_range()
	if dist < pickup_range and dist > 1.0:
		var dir = (_player_ref.global_position - global_position).normalized()
		global_position += dir * min(150.0 * delta, dist)


func setup(drop_item_id: String, drop_quantity: int) -> void:
	item_id = drop_item_id
	quantity = drop_quantity
	stack_data.clear()
	_update_icon()
	_spawn_delay = 0.5


func setup_stack(drop_stack: Dictionary) -> void:
	stack_data = drop_stack.duplicate(true)
	item_id = str(stack_data.get("id", ""))
	quantity = int(stack_data.get("quantity", 1))
	_update_icon()
	_spawn_delay = 0.5


func _is_equipment() -> bool:
	var data := stack_data if not stack_data.is_empty() else ITEM_DATABASE.get_item(item_id)
	return str(data.get("type", "")) == "equipment"


func _get_rarity() -> String:
	return str(stack_data.get("rarity", "Common"))


func _setup_equipment_visuals() -> void:
	if sprite != null:
		sprite.scale = Vector2(1.5, 1.5)
	var pillar_color := DUNGEON_LOOT.get_rarity_color(_get_rarity())
	var pillar := Polygon2D.new()
	pillar.polygon = PackedVector2Array([
		Vector2(-2, -44), Vector2(2, -44),
		Vector2(2, -4), Vector2(-2, -4),
	])
	pillar.color = pillar_color
	add_child(pillar)
	var tween := create_tween().set_loops()
	tween.tween_property(pillar, "modulate:a", 0.8, 0.6)
	tween.tween_property(pillar, "modulate:a", 0.3, 0.6)


func _update_icon() -> void:
	if sprite == null:
		return
	var item_data: Dictionary = stack_data if not stack_data.is_empty() else ITEM_DATABASE.get_item(item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item_data.is_empty():
		sprite.texture = null
		sprite.modulate = DUNGEON_LOOT.get_item_display_color(stack_data)
		return
	var icon: Texture2D = ITEM_DATABASE.get_stack_icon(item_data)
	if icon != null:
		sprite.texture = icon
		sprite.scale = Vector2.ONE
		sprite.modulate = DUNGEON_LOOT.get_item_display_color(item_data) if str(item_data.get("type", "")) == "equipment" else Color.WHITE
		return
	sprite.texture = null
	sprite.modulate = DUNGEON_LOOT.get_item_display_color(item_data)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("get"):
		return
	var inventory = body.get("inventory")
	if inventory == null:
		return
	var did_add := false
	if not stack_data.is_empty():
		did_add = inventory.add_stack(stack_data)
	else:
		did_add = inventory.add_item(item_id, quantity)
	if did_add:
		if body.has_method("record_dungeon_loot"):
			body.record_dungeon_loot(item_id, quantity)
		if body.has_method("_show_floating_text"):
			var item_name := str(stack_data.get("name", ITEM_DATABASE.get_item(item_id).get("name", item_id)))
			var text_color := Color(1.0, 0.95, 0.45, 1.0)
			if _is_equipment():
				text_color = DUNGEON_LOOT.get_rarity_color(_get_rarity())
			body._show_floating_text(global_position, "+%d %s" % [quantity, item_name], text_color)
		queue_free()
