extends DungeonMerchant
class_name SecretMerchant

func setup(floor_number: int, rng: RandomNumberGenerator = null) -> void:
	_floor_number = max(floor_number, 1)
	_equipment_offer = DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(_floor_number + 2, "Rare", rng)
	_equipment_price = _calculate_equipment_price(_floor_number + 2, _equipment_offer) + 40


func _ready() -> void:
	super._ready()
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.modulate = Color(0.72, 0.86, 1.0, 1.0)
	if get_node_or_null("SecretSigil") == null:
		var sigil: Polygon2D = Polygon2D.new()
		sigil.name = "SecretSigil"
		sigil.color = Color(0.54, 0.82, 1.0, 0.72)
		sigil.polygon = PackedVector2Array([
			Vector2(-8.0, -18.0),
			Vector2(0.0, -26.0),
			Vector2(8.0, -18.0),
			Vector2(0.0, -10.0),
		])
		add_child(sigil)
