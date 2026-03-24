extends Node

const BUILDINGS := {
	"wood_wall": {
		"id": "wood_wall",
		"name": "Wood Wall / 木墙",
		"cost": {"wood": 2},
		"has_collision": true,
		"tile_source_id": 106,
		"tile_atlas_coords": Vector2i.ZERO,
	},
	"wood_floor": {
		"id": "wood_floor",
		"name": "Wood Floor / 木地板",
		"cost": {"wood": 1},
		"has_collision": false,
		"tile_source_id": 3,
		"tile_atlas_coords": Vector2i.ZERO,
	},
	"stone_wall": {
		"id": "stone_wall",
		"name": "Stone Wall / 石墙",
		"cost": {"stone": 3},
		"has_collision": true,
		"tile_source_id": 107,
		"tile_atlas_coords": Vector2i.ZERO,
	},
	"stone_floor": {
		"id": "stone_floor",
		"name": "Stone Floor / 石地板",
		"cost": {"stone": 2},
		"has_collision": false,
		"tile_source_id": 4,
		"tile_atlas_coords": Vector2i.ZERO,
	},
	"wood_door": {
		"id": "wood_door",
		"name": "Wood Door / 木门",
		"cost": {"wood": 3},
		"has_collision": false,
		"tile_source_id": 108,
		"tile_atlas_coords": Vector2i.ZERO,
	},
}

const ORDER := ["wood_wall", "wood_floor", "stone_wall", "stone_floor", "wood_door"]


static func get_building(building_id: String) -> Dictionary:
	if not BUILDINGS.has(building_id):
		return {}
	return BUILDINGS[building_id].duplicate(true)


static func get_all_buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_id in ORDER:
		buildings.append(get_building(building_id))
	return buildings
