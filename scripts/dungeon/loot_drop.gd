extends Area2D
class_name LootDrop

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")

@export var item_id: String = "talent_shard"
@export var quantity: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var stack_data: Dictionary = {}


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not lifetime_timer.timeout.is_connected(queue_free):
		lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()
	_update_icon()


func setup(drop_item_id: String, drop_quantity: int) -> void:
	item_id = drop_item_id
	quantity = drop_quantity
	stack_data.clear()
	_update_icon()


func setup_stack(drop_stack: Dictionary) -> void:
	stack_data = drop_stack.duplicate(true)
	item_id = str(stack_data.get("id", ""))
	quantity = int(stack_data.get("quantity", 1))
	_update_icon()


func _update_icon() -> void:
	if sprite == null:
		return
	var item_data: Dictionary = stack_data if not stack_data.is_empty() else ITEM_DATABASE.get_item(item_id)
	if item_data.is_empty():
		sprite.modulate = DUNGEON_LOOT.get_item_display_color(stack_data)
		return
	sprite.texture = item_data.get("icon", null)
	sprite.modulate = DUNGEON_LOOT.get_item_display_color(item_data) if str(item_data.get("type", "")) == "equipment" else Color.WHITE


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
			body._show_floating_text(global_position, "+%d %s" % [quantity, item_name], Color(1.0, 0.95, 0.45, 1.0))
		queue_free()
