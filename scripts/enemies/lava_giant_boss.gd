extends BossEnemy
class_name LavaGiantBoss

const LAVA_PATCH_SCRIPT: Script = preload("res://scripts/dungeon/lava_patch.gd")
const LAVA_TRAIL_INTERVAL: float = 0.34

var _lava_trail_cooldown_left: float = 0.0


func _ready() -> void:
	super._ready()
	scale = Vector2.ONE * 2.0
	if animated_sprite != null:
		animated_sprite.modulate = Color(1.0, 0.45, 0.2, 1.0)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	max_hp = int(round(float(max_hp) * 1.25))
	current_hp = max_hp
	damage = int(round(float(damage) * 1.15))
	speed = 26.0
	detection_range = 210.0
	attack_range = 34.0
	attack_cooldown = 1.0
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	_lava_trail_cooldown_left = max(_lava_trail_cooldown_left - delta, 0.0)
	super._physics_process(delta)
	if ai_paused or is_dead:
		return
	if velocity.length() > 12.0 and _lava_trail_cooldown_left <= 0.0:
		_spawn_lava_patch(global_position)
		_lava_trail_cooldown_left = LAVA_TRAIL_INTERVAL


func _perform_aoe() -> void:
	super._perform_aoe()
	for patch_index: int in range(6):
		var angle: float = TAU * float(patch_index) / 6.0
		_spawn_lava_patch(global_position + Vector2.RIGHT.rotated(angle) * 30.0)


func _spawn_lava_patch(world_position: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var lava_patch: Node = LAVA_PATCH_SCRIPT.new()
	parent_node.add_child(lava_patch)
	lava_patch.global_position = world_position
	if lava_patch.has_method("setup"):
		lava_patch.setup(max(int(round(float(damage) * 0.32)), 8), 6.0, 1.0)
