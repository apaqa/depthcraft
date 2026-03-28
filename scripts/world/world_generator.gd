extends RefCounted
class_name WorldGenerator

const MAP_SIZE: Vector2i = Vector2i(200, 200)
const TILE_SIZE: int = 16
const CENTER: Vector2i = Vector2i(100, 100)
const SAFE_RADIUS: int = 15
# Solid impassable border ring (10-15 tiles wide on each edge)
const BORDER_WIDTH: int = 12

# Legacy cluster arrays kept for resource-spawning compatibility
var forest_clusters: Array = []
var mountain_clusters: Array = []
var dungeon_entrance_tile: Vector2i = Vector2i(100, 65)

# New generation data
var road_tiles: Dictionary = {}
var decoration_positions: Array = []

var _rng: RandomNumberGenerator
var _height_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite


func generate(seed_val: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val if seed_val != 0 else randi()
	_setup_noise()
	_generate_clusters()
	_pick_dungeon_position()
	_generate_road()
	_generate_decorations()


# ---------------------------------------------------------------------------
# Noise setup (Perlin via FastNoiseLite)
# ---------------------------------------------------------------------------
func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_height_noise.seed = _rng.randi()
	_height_noise.frequency = 0.018
	_height_noise.fractal_octaves = 4

	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_moisture_noise.seed = _rng.randi()
	_moisture_noise.frequency = 0.014
	_moisture_noise.fractal_octaves = 3


# ---------------------------------------------------------------------------
# Cluster generation (kept for backward-compatible resource sampling)
# ---------------------------------------------------------------------------
func _generate_clusters() -> void:
	var forest_count: int = _rng.randi_range(3, 5)
	for _i in range(forest_count):
		forest_clusters.append(_random_cluster(20, 30))

	var mountain_count: int = _rng.randi_range(2, 4)
	for _i in range(mountain_count):
		mountain_clusters.append(_random_cluster(15, 25))


func _random_cluster(min_radius: int, max_radius: int) -> Dictionary:
	var radius: int = _rng.randi_range(min_radius, max_radius)
	var margin: int = BORDER_WIDTH + radius + 5
	var cx: int = _rng.randi_range(margin, MAP_SIZE.x - margin)
	var cy: int = _rng.randi_range(margin, MAP_SIZE.y - margin)
	return {"center": Vector2i(cx, cy), "radius": radius}


func _pick_dungeon_position() -> void:
	var offset: int = _rng.randi_range(30, 40)
	dungeon_entrance_tile = Vector2i(CENTER.x, CENTER.y - offset)


# ---------------------------------------------------------------------------
# Road generation: winding dirt path from home core north to dungeon entrance
# ---------------------------------------------------------------------------
func _generate_road() -> void:
	var start_y: int = dungeon_entrance_tile.y
	var end_y: int = CENTER.y
	var cur_x: int = CENTER.x
	var road_half: int = 1  # road is 3 tiles wide total (±1)

	for ty in range(start_y, end_y + 1):
		# Slight random lateral drift every few rows for a natural winding feel
		if _rng.randf() < 0.18:
			var drift: int = _rng.randi_range(-1, 1)
			cur_x = clampi(
				cur_x + drift,
				BORDER_WIDTH + 2,
				MAP_SIZE.x - BORDER_WIDTH - 3
			)
		for dx in range(-road_half, road_half + 1):
			road_tiles[Vector2i(cur_x + dx, ty)] = true


# ---------------------------------------------------------------------------
# Decoration scatter: pure visual objects on plains (no collision)
# ---------------------------------------------------------------------------
func _generate_decorations() -> void:
	var target: int = 300
	var attempts: int = 0
	var max_attempts: int = target * 20
	while decoration_positions.size() < target and attempts < max_attempts:
		attempts += 1
		var tx: int = _rng.randi_range(
			BORDER_WIDTH + 2,
			MAP_SIZE.x - BORDER_WIDTH - 3
		)
		var ty: int = _rng.randi_range(
			BORDER_WIDTH + 2,
			MAP_SIZE.y - BORDER_WIDTH - 3
		)
		var tile: Vector2i = Vector2i(tx, ty)
		if get_tile_type(tile) == "plains" and not road_tiles.has(tile):
			decoration_positions.append(tile)


# ---------------------------------------------------------------------------
# Tile classification (noise-driven with hard border)
# ---------------------------------------------------------------------------
func get_tile_type(tile: Vector2i) -> String:
	# Hard impassable border ring
	if tile.x < BORDER_WIDTH or tile.x >= MAP_SIZE.x - BORDER_WIDTH \
			or tile.y < BORDER_WIDTH or tile.y >= MAP_SIZE.y - BORDER_WIDTH:
		return "border"

	# Safe zone around home core (always clear)
	var tile_f: Vector2 = Vector2(float(tile.x), float(tile.y))
	if tile_f.distance_to(Vector2(float(CENTER.x), float(CENTER.y))) <= float(SAFE_RADIUS):
		return "safe"

	# Road overrides biome
	if road_tiles.has(tile):
		return "road"

	# Perlin-noise biome classification
	# height and moisture are both in roughly [-1, 1]
	var height: float = _height_noise.get_noise_2d(float(tile.x), float(tile.y))
	var moisture: float = _moisture_noise.get_noise_2d(float(tile.x), float(tile.y))

	if height > 0.35:
		return "mountain"
	if moisture > 0.20 and height > -0.10:
		return "forest"
	return "plains"


# ---------------------------------------------------------------------------
# Public query helpers
# ---------------------------------------------------------------------------
func is_road_tile(tile: Vector2i) -> bool:
	return road_tiles.has(tile)


func get_decoration_positions() -> Array:
	return decoration_positions


func get_spawn_pixel() -> Vector2:
	return Vector2(CENTER * TILE_SIZE)


func get_dungeon_entrance_pixel() -> Vector2:
	return Vector2(dungeon_entrance_tile * TILE_SIZE)


# ---------------------------------------------------------------------------
# Sampling helpers (unchanged API)
# ---------------------------------------------------------------------------
func sample_positions_in_cluster(cluster: Dictionary, count: int) -> Array:
	var positions: Array = []
	var cx: float = float(cluster.center.x * TILE_SIZE)
	var cy: float = float(cluster.center.y * TILE_SIZE)
	var rad: float = float(cluster.radius * TILE_SIZE)
	for _i in range(count):
		var angle: float = _rng.randf() * TAU
		var dist: float = sqrt(_rng.randf()) * rad
		positions.append(Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist))
	return positions


func sample_plains_positions(count: int) -> Array:
	var positions: Array = []
	var attempts: int = 0
	while positions.size() < count and attempts < count * 10:
		attempts += 1
		var tx: int = _rng.randi_range(
			BORDER_WIDTH + 2,
			MAP_SIZE.x - BORDER_WIDTH - 3
		)
		var ty: int = _rng.randi_range(
			BORDER_WIDTH + 2,
			MAP_SIZE.y - BORDER_WIDTH - 3
		)
		if get_tile_type(Vector2i(tx, ty)) == "plains":
			positions.append(Vector2(tx * TILE_SIZE, ty * TILE_SIZE))
	return positions
