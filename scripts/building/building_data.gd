extends Node

const WORKBENCH_SCENE_PATH := "res://scenes/building/facilities/workbench.tscn"
const STORAGE_CHEST_SCENE_PATH := "res://scenes/building/facilities/storage_chest.tscn"
const REPAIR_BENCH_SCENE_PATH := "res://scenes/building/facilities/repair_bench.tscn"
const WOOD_DOOR_SCENE_PATH := "res://scenes/building/facilities/wood_door.tscn"
const TALENT_ALTAR_SCENE_PATH := "res://scenes/building/facilities/talent_altar.tscn"
const FARM_PLOT_SCENE_PATH := "res://scenes/building/facilities/farm_plot.tscn"
const COOKING_BENCH_SCENE_PATH := "res://scenes/building/facilities/cooking_bench.tscn"
const FULL_TILE_ATLAS := Vector2i.ZERO
const CATEGORY_ORDER := ["structure", "door_window", "facility", "defense"]
const CATEGORY_DATA := {
	"structure": {"name": "建築", "items": ["wood_wall", "stone_wall", "wood_floor", "stone_floor"]},
	"door_window": {"name": "門窗", "items": ["wood_door"]},
	"facility": {"name": "設施", "items": ["workbench", "storage_chest", "repair_bench", "talent_altar", "cooking_bench", "farm_plot"]},
	"defense": {"name": "防禦", "items": []},
}

const BUILDINGS := {
	"wood_wall": {
		"id": "wood_wall",
		"name": "木牆",
		"category": "structure",
		"kind": "tile",
		"cost": {"wood": 2},
		"has_collision": true,
		"preview_texture": preload("res://assets/crate.png"),
		"tile_source_id": 106,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"wood_floor": {
		"id": "wood_floor",
		"name": "木地板",
		"category": "structure",
		"kind": "tile",
		"cost": {"wood": 1},
		"has_collision": false,
		"preview_texture": preload("res://assets/floor_5.png"),
		"tile_source_id": 3,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"stone_wall": {
		"id": "stone_wall",
		"name": "石牆",
		"category": "structure",
		"kind": "tile",
		"cost": {"stone": 3},
		"has_collision": true,
		"preview_texture": preload("res://assets/wall_missing_brick_1.png"),
		"tile_source_id": 107,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"stone_floor": {
		"id": "stone_floor",
		"name": "石地板",
		"category": "structure",
		"kind": "tile",
		"cost": {"stone": 2},
		"has_collision": false,
		"preview_texture": preload("res://assets/floor_8.png"),
		"tile_source_id": 4,
		"tile_atlas_coords": FULL_TILE_ATLAS,
	},
	"wood_door": {
		"id": "wood_door",
		"name": "木門",
		"category": "door_window",
		"kind": "facility",
		"cost": {"wood": 3},
		"tile_size": Vector2i(2, 2),
		"has_collision": false,
		"scene_path": WOOD_DOOR_SCENE_PATH,
		"preview_texture": preload("res://assets/door_closed.png"),
	},
	"workbench": {
		"id": "workbench",
		"name": "工作台",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 5},
		"scene_path": WORKBENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/crate.png"),
	},
	"storage_chest": {
		"id": "storage_chest",
		"name": "儲物箱",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 3},
		"scene_path": STORAGE_CHEST_SCENE_PATH,
		"preview_texture": preload("res://assets/chest_closed.png"),
	},
	"repair_bench": {
		"id": "repair_bench",
		"name": "修理台",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 5, "iron_ore": 3},
		"scene_path": REPAIR_BENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/boxes_stacked.png"),
	},
	"talent_altar": {
		"id": "talent_altar",
		"name": "天賦祭壇",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 10, "iron_ore": 5},
		"scene_path": TALENT_ALTAR_SCENE_PATH,
		"preview_texture": preload("res://assets/column.png"),
	},
	"farm_plot": {
		"id": "farm_plot",
		"name": "農田",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 2, "stone": 2},
		"scene_path": FARM_PLOT_SCENE_PATH,
		"preview_texture": preload("res://assets/floor_mud_mid_1.png"),
	},
	"cooking_bench": {
		"id": "cooking_bench",
		"name": "烹飪台",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 3, "wood": 2},
		"scene_path": COOKING_BENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/torch_no_flame.png"),
	},
}

const ORDER := ["wood_wall", "wood_floor", "stone_wall", "stone_floor", "wood_door", "workbench", "storage_chest", "repair_bench", "talent_altar", "farm_plot", "cooking_bench"]


static func get_building(building_id: String) -> Dictionary:
	if not BUILDINGS.has(building_id):
		return {}
	return BUILDINGS[building_id].duplicate(true)


static func get_all_buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_id in ORDER:
		buildings.append(get_building(building_id))
	return buildings


static func get_category_ids() -> PackedStringArray:
	return PackedStringArray(CATEGORY_ORDER)


static func get_category_name(category_id: String) -> String:
	return str((CATEGORY_DATA.get(category_id, {}) as Dictionary).get("name", category_id.capitalize()))


static func get_buildings_for_category(category_id: String) -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_id in (CATEGORY_DATA.get(category_id, {}) as Dictionary).get("items", []):
		buildings.append(get_building(str(building_id)))
	return buildings
