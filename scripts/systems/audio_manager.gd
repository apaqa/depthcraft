extends Node

## AudioManager — BGM crossfade + SFX object pool
## AutoLoad this as "AudioManager" in project.godot.
##
## Usage:
##   AudioManager.play_bgm("dungeon_bgm")
##   AudioManager.play_sfx("ui_click")
##   AudioManager.play_sfx("enemy_hit", global_position)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const CROSSFADE_DURATION: float = 1.5
const SFX_POOL_SIZE: int = 8
const UI_SFX_POOL_SIZE: int = 4
const BGM_DEFAULT_VOLUME_DB: float = 0.0
const BGM_SILENT_DB: float = -80.0

# ---------------------------------------------------------------------------
# BGM players — A/B pattern for crossfading
# ---------------------------------------------------------------------------

var _bgm_player_a: AudioStreamPlayer = null
var _bgm_player_b: AudioStreamPlayer = null

## Points to whichever player is currently audible
var _active_bgm_player: AudioStreamPlayer = null
## Points to whichever player is fading out / idle
var _inactive_bgm_player: AudioStreamPlayer = null

var _current_bgm_name: String = ""
var _crossfade_tween: Tween = null

# ---------------------------------------------------------------------------
# SFX pools
# ---------------------------------------------------------------------------

## Positional (2D) SFX pool
var _sfx_pool: Array[AudioStreamPlayer2D] = []
## Non-positional pool for UI sounds
var _ui_sfx_pool: Array[AudioStreamPlayer] = []

# ---------------------------------------------------------------------------
# Sound dictionaries  (null = placeholder, assign real AudioStream later)
# ---------------------------------------------------------------------------

## SFX mapping: sound_name -> AudioStream
var _sfx_dict: Dictionary = {}
## BGM mapping: theme_name -> AudioStream
var _bgm_dict: Dictionary = {}

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	_setup_bgm_players()
	_setup_sfx_pool()
	_build_sound_dictionary()


func _setup_bgm_players() -> void:
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_a.bus = "Master"
	_bgm_player_b.bus = "Master"
	_bgm_player_a.volume_db = BGM_SILENT_DB
	_bgm_player_b.volume_db = BGM_SILENT_DB
	add_child(_bgm_player_a)
	add_child(_bgm_player_b)
	_active_bgm_player = _bgm_player_a
	_inactive_bgm_player = _bgm_player_b


func _setup_sfx_pool() -> void:
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

	for i: int in range(UI_SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_ui_sfx_pool.append(player)


## Populate the dictionaries with null placeholders.
## Replace null with preload("res://audio/...") when assets are ready.
func _build_sound_dictionary() -> void:
	# --- UI sounds ---
	_sfx_dict["ui_click"]         = null  # e.g. preload("res://audio/sfx/ui_click.ogg")
	_sfx_dict["ui_hover"]         = null
	_sfx_dict["ui_confirm"]       = null
	_sfx_dict["ui_cancel"]        = null

	# --- Combat sounds ---
	_sfx_dict["weapon_swing"]     = null  # e.g. preload("res://audio/sfx/swing_light.ogg")
	_sfx_dict["weapon_swing_heavy"] = null
	_sfx_dict["enemy_hit"]        = null  # e.g. preload("res://audio/sfx/impact_flesh.ogg")
	_sfx_dict["enemy_death"]      = null
	_sfx_dict["player_hurt"]      = null

	# --- World sounds ---
	_sfx_dict["footstep"]         = null
	_sfx_dict["door_open"]        = null
	_sfx_dict["item_pickup"]      = null
	_sfx_dict["coin_pickup"]      = null
	_sfx_dict["crafting_success"] = null
	_sfx_dict["level_up"]         = null

	# --- BGM ---
	_bgm_dict["dungeon_bgm"]      = null  # e.g. preload("res://audio/bgm/dungeon.ogg")
	_bgm_dict["overworld_bgm"]    = null  # e.g. preload("res://audio/bgm/overworld.ogg")
	_bgm_dict["boss_bgm"]         = null
	_bgm_dict["menu_bgm"]         = null


# ---------------------------------------------------------------------------
# BGM API
# ---------------------------------------------------------------------------

## Play a background music track by name with a crossfade.
## If the same track is already playing nothing happens.
func play_bgm(theme_name: String) -> void:
	if not _bgm_dict.has(theme_name) or _bgm_dict[theme_name] == null:
		push_warning("AudioManager: missing sound: " + str(theme_name))
		return
	if theme_name == _current_bgm_name:
		return

	_current_bgm_name = theme_name

	# Kill any in-progress crossfade
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
		_crossfade_tween = null

	# Swap roles: the currently-silent player becomes the new active one
	var tmp: AudioStreamPlayer = _active_bgm_player
	_active_bgm_player = _inactive_bgm_player
	_inactive_bgm_player = tmp

	# Wire the new stream (may be null placeholder)
	var stream: AudioStream = _bgm_dict[theme_name] as AudioStream
	_active_bgm_player.stream = stream
	_active_bgm_player.volume_db = BGM_SILENT_DB

	if stream != null:
		_active_bgm_player.play()

	# Crossfade tween
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(
		_active_bgm_player, "volume_db", BGM_DEFAULT_VOLUME_DB, CROSSFADE_DURATION
	)
	_crossfade_tween.tween_property(
		_inactive_bgm_player, "volume_db", BGM_SILENT_DB, CROSSFADE_DURATION
	)
	_crossfade_tween.finished.connect(_on_crossfade_finished)


## Stop the currently-playing BGM, optionally fading out.
func stop_bgm(fade_out: bool = true) -> void:
	_current_bgm_name = ""

	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
		_crossfade_tween = null

	if not fade_out:
		_active_bgm_player.stop()
		_inactive_bgm_player.stop()
		_active_bgm_player.volume_db = BGM_SILENT_DB
		_inactive_bgm_player.volume_db = BGM_SILENT_DB
		return

	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(_active_bgm_player, "volume_db", BGM_SILENT_DB, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(_inactive_bgm_player, "volume_db", BGM_SILENT_DB, CROSSFADE_DURATION)
	_crossfade_tween.finished.connect(_stop_all_bgm_players)


func _on_crossfade_finished() -> void:
	_inactive_bgm_player.stop()
	_inactive_bgm_player.volume_db = BGM_SILENT_DB


func _stop_all_bgm_players() -> void:
	_active_bgm_player.stop()
	_inactive_bgm_player.stop()
	_active_bgm_player.volume_db = BGM_SILENT_DB
	_inactive_bgm_player.volume_db = BGM_SILENT_DB


# ---------------------------------------------------------------------------
# SFX API
# ---------------------------------------------------------------------------

## Play a sound effect.
## Pass a non-zero `position` for a spatialised 2-D sound;
## omit (or pass Vector2.ZERO) for a global / UI sound.
func play_sfx(sound_name: String, position: Vector2 = Vector2.ZERO) -> void:
	if not _sfx_dict.has(sound_name) or _sfx_dict[sound_name] == null:
		push_warning("AudioManager: missing sound: " + str(sound_name))
		return

	var stream: AudioStream = _sfx_dict[sound_name] as AudioStream

	if position == Vector2.ZERO:
		_play_ui_sfx_stream(stream)
	else:
		_play_positional_sfx_stream(stream, position)


func _play_positional_sfx_stream(stream: AudioStream, position: Vector2) -> void:
	var player: AudioStreamPlayer2D = _get_free_sfx_player()
	player.stream = stream
	player.global_position = position
	player.play()


func _play_ui_sfx_stream(stream: AudioStream) -> void:
	var player: AudioStreamPlayer = _get_free_ui_sfx_player()
	player.stream = stream
	player.play()


func _get_free_sfx_player() -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in _sfx_pool:
		if not player.playing:
			return player
	# All slots busy — steal the oldest (index 0) to avoid silence
	return _sfx_pool[0]


func _get_free_ui_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _ui_sfx_pool:
		if not player.playing:
			return player
	return _ui_sfx_pool[0]


# ---------------------------------------------------------------------------
# Volume helpers
# ---------------------------------------------------------------------------

## Set master bus volume in dB (0 = full, -80 = silent).
func set_master_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(0, volume_db)


## Mute / unmute the master bus.
func set_master_mute(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)


# ---------------------------------------------------------------------------
# Runtime asset registration
# ---------------------------------------------------------------------------

## Register (or replace) an SFX entry at runtime.
## Useful when DLC or generated content is loaded after startup.
func register_sfx(sound_name: String, stream: AudioStream) -> void:
	_sfx_dict[sound_name] = stream


## Register (or replace) a BGM entry at runtime.
func register_bgm(theme_name: String, stream: AudioStream) -> void:
	_bgm_dict[theme_name] = stream


## Returns the name of the currently active BGM track, or "" if none.
func get_current_bgm() -> String:
	return _current_bgm_name
