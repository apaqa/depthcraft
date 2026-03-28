extends Node

const WORKBENCH_SCENE_PATH = "res://scenes/building/facilities/workbench.tscn"
const STORAGE_CHEST_SCENE_PATH = "res://scenes/building/facilities/storage_chest.tscn"
const REPAIR_BENCH_SCENE_PATH = "res://scenes/building/facilities/repair_bench.tscn"
const WOOD_DOOR_SCENE_PATH = "res://scenes/building/facilities/wood_door.tscn"
const TALENT_ALTAR_SCENE_PATH = "res://scenes/building/facilities/talent_altar.tscn"
const FARM_PLOT_SCENE_PATH = "res://scenes/building/facilities/farm_plot.tscn"
const COOKING_BENCH_SCENE_PATH = "res://scenes/building/facilities/cooking_bench.tscn"
const BOUNTY_BOARD_SCENE_PATH = "res://scenes/building/facilities/bounty_board.tscn"
const TAVERN_SCENE_PATH = "res://scenes/building/facilities/tavern.tscn"
const HOME_CORE_SCENE_PATH = "res://scenes/building/home_core.tscn"
const FULL_TILE_ATLAS = Vector2i.ZERO
const CATEGORY_ORDER = ["structure", "door_window", "facility", "defense"]
const CATEGORY_DATA = {
	"structure": {"name": "build_cat_structure", "items": ["wood_wall", "stone_wall", "wood_floor", "stone_floor"]},
	"door_window": {"name": "build_cat_door_window", "items": ["wood_door"]},
	"facility": {"name": "build_cat_facility", "items": ["workbench", "storage_chest", "talent_altar", "cooking_bench", "farm_plot", "bounty_board", "tavern", "home_core"]},
	"defense": {"name": "build_cat_defense", "items": []},
}

const BUILDINGS = {
	"wood_wall": {
		"id": "wood_wall",
		"name": "wood_wall",
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
		"name": "wood_floor",
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
		"name": "stone_wall",
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
		"name": "stone_floor",
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
		"name": "wood_door",
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
		"name": "workbench",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 5},
		"scene_path": WORKBENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/boxes_stacked.png"),
	},
	"storage_chest": {
		"id": "storage_chest",
		"name": "storage_chest",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 3},
		"scene_path": STORAGE_CHEST_SCENE_PATH,
		"preview_texture": preload("res://assets/chest_closed.png"),
	},
	"repair_bench": {
		"id": "repair_bench",
		"name": "repair_bench",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 5, "iron_ore": 3},
		"scene_path": REPAIR_BENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/column_wall.png"),
	},
	"talent_altar": {
		"id": "talent_altar",
		"name": "talent_altar",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 10, "iron_ore": 5},
		"scene_path": TALENT_ALTAR_SCENE_PATH,
		"preview_texture": preload("res://assets/floor_gargoyle_red_basin.png"),
	},
	"farm_plot": {
		"id": "farm_plot",
		"name": "farm_plot",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 2, "stone": 2},
		"scene_path": FARM_PLOT_SCENE_PATH,
		"preview_texture": preload("res://assets/floor_mud_mid_1.png"),
	},
	"cooking_bench": {
		"id": "cooking_bench",
		"name": "cooking_bench",
		"category": "facility",
		"kind": "facility",
		"cost": {"stone": 3, "wood": 2},
		"scene_path": COOKING_BENCH_SCENE_PATH,
		"preview_texture": preload("res://assets/crate.png"),
	},
	"bounty_board": {
		"id": "bounty_board",
		"name": "Bounty Board",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 8, "stone": 4},
		"base_max_hp": 60,
		"scene_path": BOUNTY_BOARD_SCENE_PATH,
		"preview_texture": preload("res://assets/wall_banner_yellow.png"),
	},
	"tavern": {
		"id": "tavern",
		"name": "tavern",
		"category": "facility",
		"kind": "facility",
		"cost": {"wood": 10, "stone": 5, "copper": 20},
		"base_max_hp": 80,
		"scene_path": TAVERN_SCENE_PATH,
		"preview_texture": preload("res://assets/wall_banner_yellow.png"),
	},
	"home_core": {
		"id": "home_core",
		"name": "home_core",
		"category": "facility",
		"kind": "core",
		"cost": {"wood": 10, "stone": 5},
		"scene_path": HOME_CORE_SCENE_PATH,
		"preview_texture": preload("res://assets/column.png"),
	},
}

const ORDER = ["wood_wall", "wood_floor", "stone_wall", "stone_floor", "wood_door", "workbench", "storage_chest", "talent_altar", "farm_plot", "cooking_bench", "bounty_board", "tavern", "home_core"]


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
	var key: String = str((CATEGORY_DATA.get(category_id, {}) as Dictionary).get("name", category_id))
	return LocaleManager.L(key)


static func get_buildings_for_category(category_id: String) -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building_id in (CATEGORY_DATA.get(category_id, {}) as Dictionary).get("items", []):
		buildings.append(get_building(str(building_id)))
	return buildings


static func get_default_max_hp(building_id: String) -> int:
	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return 1
	if building.has("base_max_hp"):
		return maxi(int(building.get("base_max_hp", 1)), 1)
	if str(building.get("kind", "")) == "core":
		return 500
	var category: String = str(building.get("category", "facility"))
	match category:
		"structure":
			return 100
		"door_window":
			return 50
		"defense":
			return 150
		_:
			return 80
