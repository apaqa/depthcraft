extends RefCounted
class_name WorldGenerator

const MAP_SIZE := Vector2i(200, 200)
const TILE_SIZE := 16
const CENTER := Vector2i(100, 100)
const SAFE_RADIUS := 15
const WATER_BORDER := 2

var forest_clusters: Array = []
var mountain_clusters: Array = []
var lake_clusters: Array = []
var dungeon_entrance_tile: Vector2i = Vector2i(100, 65)

var _rng: RandomNumberGenerator


func generate(seed_val: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val if seed_val != 0 else randi()
	_generate_biomes()
	_pick_dungeon_position()


func _generate_biomes() -> void:
	var forest_count := _rng.randi_range(3, 5)
	for _i in range(forest_count):
		forest_clusters.append(_random_cluster(20, 30))

	var mountain_count := _rng.randi_range(2, 4)
	for _i in range(mountain_count):
		mountain_clusters.append(_random_cluster(15, 25))

	var lake_count := _rng.randi_range(1, 2)
	for _i in range(lake_count):
		lake_clusters.append(_random_cluster(5, 10))


func _random_cluster(min_radius: int, max_radius: int) -> Dictionary:
	var radius := _rng.randi_range(min_radius, max_radius)
	var margin := WATER_BORDER + radius + 5
	var cx := _rng.randi_range(margin, MAP_SIZE.x - margin)
	var cy := _rng.randi_range(margin, MAP_SIZE.y - margin)
	return {"center": Vector2i(cx, cy), "radius": radius}


func _pick_dungeon_position() -> void:
	var offset := _rng.randi_range(30, 40)
	dungeon_entrance_tile = Vector2i(CENTER.x, CENTER.y - offset)


func get_tile_type(tile: Vector2i) -> String:
	if tile.x < WATER_BORDER or tile.x >= MAP_SIZE.x - WATER_BORDER \
			or tile.y < WATER_BORDER or tile.y >= MAP_SIZE.y - WATER_BORDER:
		return "water"
	var tile_f := Vector2(tile)
	if tile_f.distance_to(Vector2(CENTER)) <= float(SAFE_RADIUS):
		return "safe"
	for lake in lake_clusters:
		if tile_f.distance_to(Vector2(lake.center)) <= float(lake.radius):
			return "lake"
	for cluster in forest_clusters:
		if tile_f.distance_to(Vector2(cluster.center)) <= float(cluster.radius):
			return "forest"
	for cluster in mountain_clusters:
		if tile_f.distance_to(Vector2(cluster.center)) <= float(cluster.radius):
			return "mountain"
	return "plains"


func get_spawn_pixel() -> Vector2:
	return Vector2(CENTER * TILE_SIZE)


func get_dungeon_entrance_pixel() -> Vector2:
	return Vector2(dungeon_entrance_tile * TILE_SIZE)


func sample_positions_in_cluster(cluster: Dictionary, count: int) -> Array:
	var positions: Array = []
	var cx := float(cluster.center.x * TILE_SIZE)
	var cy := float(cluster.center.y * TILE_SIZE)
	var rad := float(cluster.radius * TILE_SIZE)
	for _i in range(count):
		var angle := _rng.randf() * TAU
		var dist := sqrt(_rng.randf()) * rad
		positions.append(Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist))
	return positions


func sample_plains_positions(count: int) -> Array:
	var positions: Array = []
	var attempts := 0
	while positions.size() < count and attempts < count * 10:
		attempts += 1
		var tx := _rng.randi_range(WATER_BORDER + 2, MAP_SIZE.x - WATER_BORDER - 3)
		var ty := _rng.randi_range(WATER_BORDER + 2, MAP_SIZE.y - WATER_BORDER - 3)
		if get_tile_type(Vector2i(tx, ty)) == "plains":
			positions.append(Vector2(tx * TILE_SIZE, ty * TILE_SIZE))
	return positions
