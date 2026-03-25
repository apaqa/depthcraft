extends Area2D
class_name LootDrop

const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")

@export var item_id: String = "talent_shard"
@export var quantity: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer


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
	_update_icon()


func _update_icon() -> void:
	if sprite == null:
		return
	var item_data: Dictionary = ITEM_DATABASE.get_item(item_id)
	sprite.texture = item_data.get("icon", null)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("get"):
		return
	var inventory = body.get("inventory")
	if inventory == null:
		return
	if inventory.add_item(item_id, quantity):
		if body.has_method("_show_floating_text"):
			body._show_floating_text(global_position, "+%d %s" % [quantity, str(ITEM_DATABASE.get_item(item_id).get("name", item_id))], Color(1.0, 0.95, 0.45, 1.0))
		queue_free()
