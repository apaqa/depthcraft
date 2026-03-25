extends Node

const WORKBENCH_SCENE_PATH := "res://scenes/building/facilities/workbench.tscn"
const STORAGE_CHEST_SCENE_PATH := "res://scenes/building/facilities/storage_chest.tscn"
const REPAIR_BENCH_SCENE_PATH := "res://scenes/building/facilities/repair_bench.tscn"
const WOOD_DOOR_SCENE_PATH := "res://scenes/building/facilities/wood_door.tscn"
const FULL_TILE_ATLAS := Vector2i.ZERO

const BUILDINGS := {
	"wood_wall": {
		"id": "wood_wall",
		"name": "Wood Wall",
		"kind": "tile",
		"cost": {"wood": 2},
		"has_collision": true,
		"preview_texture": preload("res://assets/crate.png"),
		"tile_source_id": 106,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"wood_floor": {
		"id": "wood_floor",
		"name": "Wood Floor",
		"kind": "tile",
		"cost": {"wood": 1},
		"has_collision": false,
		"preview_texture": preload("res://assets/floor_5.png"),
		"tile_source_id": 3,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"stone_wall": {
		"id": "stone_wall",
		"name": "Stone Wall",
		"kind": "tile",
		"cost": {"stone": 3},
		"has_collision": true,
		"preview_texture": preload("res://assets/wall_missing_brick_1.png"),
		"tile_source_id": 107,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"stone_floor": {
		"id": "stone_floor",
		"name": "Stone Floor",
		"kind": "tile",
		"cost": {"stone": 2},
		"has_collision": false,
		"preview_texture": preload("res://assets/floor_8.png"),
		"tile_source_id": 4,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"wood_door": {
		"id": "wood_door",
		"name": "Wood Door",
		"kind": "facility",
		"cost": {"wood": 3},
		"has_collision": false,
		"scene_path": WOOD_DOOR_SCENE_PATH,
		"preview_texture": preload("res://assets/door_closed.png"),
	},
	"workbench": {
		"id": "workbench",
		"name": "Workbench",
		"kind": "facility",
		"cost": {"wood": 5},
		"scene_path": WORKBENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/crate.png"),
	},
	"storage_chest": {
		"id": "storage_chest",
		"name": "Storage Chest",
		"kind": "facility",
		"cost": {"wood": 3},
		"scene_path": STORAGE_CHEST_SCENE_PATH,
		"preview_texture": preload("res://assets/chest_closed.png"),
	},
	"repair_bench": {
		"id": "repair_bench",
		"name": "Repair Bench",
		"kind": "facility",
		"cost": {"stone": 5, "iron_ore": 3},
		"scene_path": REPAIR_BENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/boxes_stacked.png"),
	},
}

const ORDER := ["wood_wall", "wood_floor", "stone_wall", "stone_floor", "wood_door", "workbench", "storage_chest", "repair_bench"]


static func get_building(building_id: String) -> Dictionary:
	if not BUILDINGS.has(building_id):
		return {}
	return BUILDINGS[building_id].duplicate(true)


static func get_all_buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_id in ORDER:
		buildings.append(get_building(building_id))
	return buildings
