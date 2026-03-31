extends Area2D
class_name OverworldAltar

const BUFF_SYSTEM: Script = preload("res://scripts/dungeon/buff_system.gd")

# Altar effect data: permanent flat bonuses or debuffs applied to player_stats
const BLESSING_POOL: Array[Dictionary] = [
	{"id": "bless_atk", "zh": "攻擊祝福", "en": "Blessing of Might", "type": "blessing", "stat": "attack_bonus", "value": 3},
	{"id": "bless_def", "zh": "防禦祝福", "en": "Blessing of Iron", "type": "blessing", "stat": "defense_bonus", "value": 3},
	{"id": "bless_hp", "zh": "生命祝福", "en": "Blessing of Vitality", "type": "blessing", "stat": "max_hp_bonus", "value": 10},
	{"id": "bless_spd", "zh": "速度祝福", "en": "Blessing of Wind", "type": "blessing", "stat": "speed_bonus", "value": 10},
	{"id": "bless_loot", "zh": "財富祝福", "en": "Blessing of Fortune", "type": "blessing", "stat": "loot_bonus", "value": 1},
]
const CURSE_POOL: Array[Dictionary] = [
	{"id": "curse_atk", "zh": "弱化詛咒", "en": "Curse of Weakness", "type": "curse", "stat": "attack_bonus", "value": -2},
	{"id": "curse_def", "zh": "脆弱詛咒", "en": "Curse of Frailty", "type": "curse", "stat": "defense_bonus", "value": -2},
	{"id": "curse_hp", "zh": "失血詛咒", "en": "Curse of Drain", "type": "curse", "stat": "max_hp_bonus", "value": -8},
]

var _used: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _effect: Dictionary = {}
var _altar_sprite: Sprite2D = null
var _cost_type: String = ""
var _cost_amount: int = 0


func _ready() -> void:
	monitoring = true
	monitorable = true
	_roll_cost()
	_roll_effect()
	_build_visuals()


func _roll_cost() -> void:
	if _rng.randf() < 0.5:
		_cost_type = "gold"
		_cost_amount = int(_rng.randf_range(10.0, 200.0))
	else:
		_cost_type = "hp"
		_cost_amount = _rng.randi_range(5, 20)


func _roll_effect() -> void:
	# 60% blessing, 40% curse
	if _rng.randf() < 0.6:
		var idx: int = _rng.randi() % BLESSING_POOL.size()
		_effect = BLESSING_POOL[idx].duplicate(true)
	else:
		var idx: int = _rng.randi() % CURSE_POOL.size()
		_effect = CURSE_POOL[idx].duplicate(true)


func _build_visuals() -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = preload("res://assets/column (2).png")
	spr.scale = Vector2(1.5, 1.5)
	spr.position = Vector2(0.0, -20.0)
	add_child(spr)
	_altar_sprite = spr

	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(24.0, 32.0)
	col_shape.shape = rect_shape
	col_shape.position = Vector2(0.0, -14.0)
	add_child(col_shape)


func get_interaction_prompt() -> String:
	if _used:
		return ""
	if _cost_type == "gold":
		return "[E] 暗黑祭壇 — %d 銅幣" % _cost_amount
	return "[E] 暗黑祭壇 — 獻祭 %d 生命上限" % _cost_amount


func interact(player: Variant) -> void:
	if _used or player == null:
		return
	if not _pay_cost(player):
		return
	_used = true
	_apply_effect(player)
	queue_free()


func _pay_cost(player: Variant) -> bool:
	if _cost_type == "gold":
		var inv: Node = player.get("inventory")
		if inv == null:
			return false
		if not inv.has_item("copper", _cost_amount):
			if player.has_method("show_status_message"):
				player.show_status_message("銅幣不足", Color(1.0, 0.4, 0.4, 1.0))
			return false
		inv.remove_item("copper", _cost_amount)
		return true
	# hp cost
	var player_stats: Node = null
	if player.has_method("get_node_or_null"):
		player_stats = player.get_node_or_null("PlayerStats")
	if player_stats == null:
		return false
	var cur_max_hp: int = int(player_stats.get("base_max_hp")) if player_stats.get("base_max_hp") != null else 100
	if cur_max_hp - _cost_amount < 10:
		if player.has_method("show_status_message"):
			player.show_status_message("生命上限不足", Color(1.0, 0.4, 0.4, 1.0))
		return false
	player_stats.set("base_max_hp", cur_max_hp - _cost_amount)
	if player_stats.has_signal("stats_changed"):
		player_stats.emit_signal("stats_changed")
	return true


func _apply_effect(player: Variant) -> void:
	if _effect.is_empty():
		return
	var stat: String = str(_effect.get("stat", ""))
	var value: int = int(_effect.get("value", 0))
	var is_blessing: bool = str(_effect.get("type", "")) == "blessing"
	var effect_name: String = str(_effect.get("zh", ""))

	# Apply permanent stat on player_stats (flat additive)
	var player_stats: Node = null
	if player.has_method("get_node_or_null"):
		player_stats = player.get_node_or_null("PlayerStats")
	if player_stats != null and player_stats.has_method("add_permanent_bonus"):
		player_stats.call("add_permanent_bonus", stat, value)
	elif player_stats != null:
		_apply_stat_fallback(player_stats, stat, value)

	if player.has_method("show_status_message"):
		var sign_str: String = "+" if value >= 0 else ""
		if is_blessing:
			player.show_status_message("黑暗中傳來低語...", Color(1.0, 0.9, 0.3, 1.0))
			player.show_status_message("%s %s%d" % [effect_name, sign_str, value], Color(0.3, 0.9, 0.3, 1.0))
		else:
			player.show_status_message("交易的代價...", Color(0.9, 0.3, 0.3, 1.0))
			player.show_status_message("%s %s%d" % [effect_name, sign_str, value], Color(0.9, 0.3, 0.3, 1.0))


func _apply_stat_fallback(player_stats: Node, stat: String, value: int) -> void:
	match stat:
		"attack_bonus":
			var cur: int = int(player_stats.get("base_attack")) if player_stats.get("base_attack") != null else 0
			player_stats.set("base_attack", cur + value)
		"defense_bonus":
			var cur: int = int(player_stats.get("base_defense")) if player_stats.get("base_defense") != null else 0
			player_stats.set("base_defense", cur + value)
		"max_hp_bonus":
			var cur: int = int(player_stats.get("base_max_hp")) if player_stats.get("base_max_hp") != null else 100
			player_stats.set("base_max_hp", maxi(cur + value, 10))
		"speed_bonus":
			var cur: float = float(player_stats.get("base_speed")) if player_stats.get("base_speed") != null else 80.0
			player_stats.set("base_speed", maxf(cur + float(value), 20.0))
		"loot_bonus":
			var cur: float = float(player_stats.get("loot_bonus")) if player_stats.get("loot_bonus") != null else 0.0
			player_stats.set("loot_bonus", cur + float(value))
	if player_stats.has_signal("stats_changed"):
		player_stats.emit_signal("stats_changed")
