extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")

var _failures: PackedStringArray = []


func _initialize() -> void:
	test_initial_position()
	test_default_speed()
	test_default_sprint_speed()
	test_collision_shape_uses_feet_box()
	test_diagonal_normalization()
	test_zero_input_returns_zero_vector()
	test_velocity_zero_when_idle()
	test_velocity_uses_custom_speed()
	test_sprite_flips_left()
	_report_results()


func test_initial_position() -> void:
	var player := PLAYER_SCENE.instantiate()
	_assert(player.position == Vector2.ZERO, "Player should start at Vector2.ZERO in its own scene.")


func test_default_speed() -> void:
	var player := PLAYER_SCENE.instantiate()
	_assert(is_equal_approx(player.speed, 80.0), "Player speed should default to 80.0.")


func test_default_sprint_speed() -> void:
	var player := PLAYER_SCENE.instantiate()
	_assert(is_equal_approx(player.sprint_speed, 140.0), "Player sprint speed should default to 140.0.")


func test_collision_shape_uses_feet_box() -> void:
	var player := PLAYER_SCENE.instantiate()
	var collision_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var rectangle: RectangleShape2D = collision_shape.shape
	_assert(collision_shape.position == Vector2(0, 6), "Player collision should sit exactly at the feet position.")
	_assert(rectangle.size == Vector2(6, 4), "Player collision should use the tiny feet-only rectangle.")


func test_diagonal_normalization() -> void:
	var input_vector := PLAYER_SCRIPT.compute_input_vector(0.0, 1.0, 1.0, 0.0)
	_assert(is_equal_approx(input_vector.length(), 1.0), "Diagonal input should normalize to length 1.0.")


func test_zero_input_returns_zero_vector() -> void:
	var input_vector := PLAYER_SCRIPT.compute_input_vector(0.0, 0.0, 0.0, 0.0)
	_assert(input_vector == Vector2.ZERO, "Zero input should return Vector2.ZERO.")


func test_velocity_zero_when_idle() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.apply_input_direction(Vector2.ZERO)
	_assert(player.velocity == Vector2.ZERO, "Player velocity should be zero with no input.")


func test_velocity_uses_custom_speed() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.apply_input_direction(Vector2.RIGHT, player.sprint_speed)
	_assert(player.velocity == Vector2.RIGHT * player.sprint_speed, "Player velocity should use the provided sprint speed.")


func test_sprite_flips_left() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.apply_input_direction(Vector2.LEFT)
	_assert(player.get_node("AnimatedSprite2D").flip_h, "Player sprite should flip when moving left.")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("All player tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	quit(1)
