extends Object
class_name GiftBoxSystem

## Static utility — gift box definitions, loot tables, and loot rolling.
## All methods are static; never instantiate this class.

const BOX_ICONS: Dictionary = {
	"giftbox_bronze": preload("res://assets/icons/kyrise/gift_01a.png"),
	"giftbox_silver": preload("res://assets/icons/kyrise/gift_01b.png"),
	"giftbox_gold": preload("res://assets/icons/kyrise/gift_01c.png"),
	"giftbox_mystic": preload("res://assets/icons/kyrise/gift_01d.png"),
	"giftbox_cursed": preload("res://assets/icons/kyrise/gift_01e.png"),
	"giftbox_celestial": preload("res://assets/icons/kyrise/gift_01f.png"),
}

const BOX_OPEN_ICONS: Dictionary = {
	"giftbox_bronze": preload("res://assets/icons/kyrise/giftopen_01a.png"),
	"giftbox_silver": preload("res://assets/icons/kyrise/giftopen_01b.png"),
	"giftbox_gold": preload("res://assets/icons/kyrise/giftopen_01c.png"),
	"giftbox_mystic": preload("res://assets/icons/kyrise/giftopen_01d.png"),
	"giftbox_cursed": preload("res://assets/icons/kyrise/giftopen_01e.png"),
	"giftbox_celestial": preload("res://assets/icons/kyrise/giftopen_01f.png"),
}

## price in copper, color for UI
const BOX_DATA: Dictionary = {
	"giftbox_bronze": {
		"name_key": "giftbox_bronze_name",
		"desc_key": "giftbox_bronze_desc",
		"price": 80,
		"color": Color(0.80, 0.55, 0.25, 1.0),
	},
	"giftbox_silver": {
		"name_key": "giftbox_silver_name",
		"desc_key": "giftbox_silver_desc",
		"price": 500,
		"color": Color(0.75, 0.82, 0.90, 1.0),
	},
	"giftbox_gold": {
		"name_key": "giftbox_gold_name",
		"desc_key": "giftbox_gold_desc",
		"price": 2500,
		"color": Color(1.0, 0.82, 0.20, 1.0),
	},
	"giftbox_mystic": {
		"name_key": "giftbox_mystic_name",
		"desc_key": "giftbox_mystic_desc",
		"price": 8000,
		"color": Color(0.55, 0.30, 1.0, 1.0),
	},
	"giftbox_cursed": {
		"name_key": "giftbox_cursed_name",
		"desc_key": "giftbox_cursed_desc",
		"price": 3000,
		"color": Color(0.70, 0.20, 0.20, 1.0),
	},
	"giftbox_celestial": {
		"name_key": "giftbox_celestial_name",
		"desc_key": "giftbox_celestial_desc",
		"price": 50000,
		"color": Color(0.85, 0.95, 1.0, 1.0),
	},
}

## Each entry: [weight: int, loot: Dictionary]
## loot "type" values: "item", "blessing_choice", "blessing_scroll",
##                     "random_buff", "curse_debuff", "nothing"
const LOOT_TABLES: Dictionary = {
	"giftbox_bronze": [
		[30, {"type": "item", "id": "copper", "qty": 50}],
		[25, {"type": "item", "id": "copper", "qty": 20}],
		[20, {"type": "item", "id": "gem_green", "qty": 1}],
		[15, {"type": "item", "id": "bandage", "qty": 1}],
		[10, {"type": "nothing"}],
	],
	"giftbox_silver": [
		[20, {"type": "item", "id": "silver", "qty": 3}],
		[15, {"type": "item", "id": "gem_green", "qty": 2}],
		[15, {"type": "item", "id": "gem_blue", "qty": 1}],
		[25, {"type": "random_buff"}],
		[15, {"type": "item", "id": "bandage", "qty": 2}],
		[10, {"type": "nothing"}],
	],
	"giftbox_gold": [
		[10, {"type": "item", "id": "gold", "qty": 1}],
		[25, {"type": "item", "id": "gem_blue", "qty": 2}],
		[20, {"type": "item", "id": "gem_purple", "qty": 1}],
		[20, {"type": "random_buff"}],
		[10, {"type": "item", "id": "silver", "qty": 8}],
		[5, {"type": "item", "id": "gem_purple", "qty": 2}],
		[10, {"type": "nothing"}],
	],
	"giftbox_mystic": [
		[25, {"type": "item", "id": "gem_purple", "qty": 1}],
		[20, {"type": "item", "id": "gem_blue", "qty": 3}],
		[20, {"type": "item", "id": "gem_purple", "qty": 2}],
		[15, {"type": "random_buff"}],
		[15, {"type": "item", "id": "gem_blue", "qty": 5}],
		[5, {"type": "nothing"}],
	],
	"giftbox_cursed": [
		[12, {"type": "item", "id": "gem_purple", "qty": 1}],
		[5, {"type": "item", "id": "gem_red", "qty": 1}],
		[15, {"type": "item", "id": "gem_blue", "qty": 2}],
		[15, {"type": "item", "id": "gold", "qty": 1}],
		[13, {"type": "item", "id": "silver", "qty": 10}],
		[15, {"type": "item", "id": "copper", "qty": 200}],
		[25, {"type": "nothing"}],
	],
	"giftbox_celestial": [
		[15, {"type": "item", "id": "gem_red", "qty": 1}],
		[15, {"type": "item", "id": "gem_purple", "qty": 3}],
		[20, {"type": "item", "id": "gem_red", "qty": 2}],
		[20, {"type": "item", "id": "gem_purple", "qty": 4}],
		[15, {"type": "item", "id": "gold", "qty": 2}],
		[10, {"type": "item", "id": "gold", "qty": 3}],
		[5, {"type": "nothing"}],
	],
}

## Returns one loot Dictionary selected by weighted random from the table.
static func roll_loot(box_id: String) -> Dictionary:
	var table: Array = LOOT_TABLES.get(box_id, []) as Array
	if table.is_empty():
		return {"type": "nothing"}
	var total_weight: int = 0
	for entry: Variant in table:
		total_weight += int((entry as Array)[0])
	if total_weight <= 0:
		return {"type": "nothing"}
	var r: int = randi() % total_weight
	var accum: int = 0
	for entry: Variant in table:
		var pair: Array = entry as Array
		accum += int(pair[0])
		if r < accum:
			return pair[1] as Dictionary
	return {"type": "nothing"}
