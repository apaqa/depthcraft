extends Node2D

@onready var hud: Control = $HUDCanvas/HUD
@onready var level_root: Node2D = $LevelRoot

const BUILDING_SAVE := preload("res://scripts/building/building_save.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_level.tscn")
const OVERWORLD_SCENE := preload("res://scenes/overworld/test_overworld.tscn")

var player
var current_level = null
var current_level_id: String = "dungeon"
var dungeon_run_snapshot: Array = []


func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	player.portal_requested.connect(_on_player_portal_requested)
	player.died.connect(_on_player_died)
	level_root.add_child(player)

	if hud.has_method("bind_player"):
		hud.bind_player(player)

	change_level(current_level_id)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_reset"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_reset_save"):
		get_tree().paused = false
		BUILDING_SAVE.clear_save()
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


func change_level(level_id: String) -> void:
	var next_scene := _get_level_scene(level_id)
	if next_scene == null:
		return

	if current_level != null:
		if player.get_parent() == current_level:
			player.reparent(level_root)
		current_level.queue_free()

	current_level = next_scene.instantiate()
	current_level_id = level_id
	level_root.add_child(current_level)
	if current_level.has_method("place_player"):
		current_level.place_player(player)
	else:
		player.reparent(level_root)

	if player.building_system.has_method("set_active_level"):
		player.building_system.set_active_level(current_level_id, current_level)

	if current_level.has_signal("floor_changed") and not current_level.floor_changed.is_connected(_on_floor_changed):
		current_level.floor_changed.connect(_on_floor_changed)
	if current_level.has_signal("kills_changed") and not current_level.kills_changed.is_connected(_on_kills_changed):
		current_level.kills_changed.connect(_on_kills_changed)
	if current_level.has_signal("return_to_surface_requested") and not current_level.return_to_surface_requested.is_connected(_on_return_to_surface_requested):
		current_level.return_to_surface_requested.connect(_on_return_to_surface_requested)

	if level_id == "dungeon":
		dungeon_run_snapshot = player.inventory.get_state()
		_on_floor_changed(int(current_level.get("current_floor")))
		_on_kills_changed(int(current_level.get("total_kills")))
	else:
		_on_floor_changed(0)
		_on_kills_changed(0)

	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_process_input(true)
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.heal_to_full()


func _get_level_scene(level_id: String) -> PackedScene:
	match level_id:
		"dungeon":
			return DUNGEON_SCENE
		"overworld":
			return OVERWORLD_SCENE
		_:
			return null


func _on_player_portal_requested(target_level_id: String) -> void:
	call_deferred("change_level", target_level_id)


func _on_floor_changed(current_floor: int) -> void:
	if hud.has_method("update_floor_label"):
		hud.update_floor_label(current_floor)


func _on_kills_changed(kills: int) -> void:
	if hud.has_method("update_kills_label"):
		hud.update_kills_label(kills)


func _on_return_to_surface_requested() -> void:
	change_level("overworld")


func _on_player_died() -> void:
	if current_level_id == "dungeon":
		player.inventory.load_state(dungeon_run_snapshot)
		change_level("overworld")
