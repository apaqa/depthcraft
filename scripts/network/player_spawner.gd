extends Node
class_name PlayerSpawner

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _players: Dictionary = {}


func spawn_player(peer_id: int, position: Vector2) -> void:
	if _players.has(peer_id):
		var existing: CharacterBody2D = _players[peer_id]
		if is_instance_valid(existing):
			existing.global_position = position
			return
	var player = PLAYER_SCENE.instantiate()
	var is_local_player := not multiplayer.has_multiplayer_peer() or peer_id == multiplayer.get_unique_id()
	player.name = str(peer_id)
	player.network_peer_id = peer_id
	player.load_persistent_state_on_ready = is_local_player
	player.set_multiplayer_authority(peer_id)
	player.global_position = position
	add_child(player)
	if player.has_method("configure_for_network_role"):
		player.configure_for_network_role(is_local_player)
	_players[peer_id] = player


func despawn_player(peer_id: int) -> void:
	var player = get_player(peer_id)
	if player != null and is_instance_valid(player):
		player.queue_free()
	_players.erase(peer_id)


func get_player(peer_id: int) -> CharacterBody2D:
	if not _players.has(peer_id):
		return null
	var player: CharacterBody2D = _players[peer_id]
	if player == null or not is_instance_valid(player):
		_players.erase(peer_id)
		return null
	return player


func get_player_ids() -> Array[int]:
	var player_ids: Array[int] = []
	for peer_id in _players.keys():
		player_ids.append(int(peer_id))
	player_ids.sort()
	return player_ids


func get_players() -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	for peer_id in get_player_ids():
		var player := get_player(peer_id)
		if player != null:
			result.append(player)
	return result
