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
var _altar_sprite: ColorRect = null
var _label: Label = null


func _ready() -> void:
	monitoring = true
	monitorable = true
	_roll_effect()
	_build_visuals()


func _roll_effect() -> void:
	# 60% blessing, 40% curse
	if _rng.randf() < 0.6:
		var idx: int = _rng.randi() % BLESSING_POOL.size()
		_effect = BLESSING_POOL[idx].duplicate(true)
	else:
		var idx: int = _rng.randi() % CURSE_POOL.size()
		_effect = CURSE_POOL[idx].duplicate(true)


func _build_visuals() -> void:
	var is_blessing: bool = str(_effect.get("type", "blessing")) == "blessing"
	var altar_color: Color = Color(0.3, 0.5, 1.0, 0.85) if is_blessing else Color(0.6, 0.1, 0.6, 0.85)

	_altar_sprite = ColorRect.new()
	_altar_sprite.size = Vector2(20.0, 28.0)
	_altar_sprite.position = Vector2(-10.0, -28.0)
	_altar_sprite.color = altar_color
	add_child(_altar_sprite)

	_label = Label.new()
	_label.position = Vector2(-24.0, -44.0)
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.text = str(_effect.get("zh", "祭壇"))
	add_child(_label)

	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(24.0, 32.0)
	col_shape.shape = rect_shape
	col_shape.position = Vector2(0.0, -14.0)
	add_child(col_shape)


func get_interaction_prompt() -> String:
	if _used:
		return LocaleManager.L("altar_used")
	var effect_name: String = str(_effect.get("zh", "祭壇"))
	var type_text: String = LocaleManager.L("altar_curse") if str(_effect.get("type", "")) == "curse" else LocaleManager.L("altar_blessing")
	return "[E] %s: %s" % [type_text, effect_name]


func interact(player: Variant) -> void:
	if _used or player == null:
		return
	_used = true
	_apply_effect(player)
	_label.text = "✓"
	if _altar_sprite != null:
		_altar_sprite.color = Color(0.35, 0.35, 0.35, 0.6)


func _apply_effect(player: Variant) -> void:
	if _effect.is_empty():
		return
	var stat: String = str(_effect.get("stat", ""))
	var value: int = int(_effect.get("value", 0))
	var is_blessing: bool = str(_effect.get("type", "")) == "blessing"
	var msg_color: Color = Color(0.4, 0.8, 1.0, 1.0) if is_blessing else Color(0.9, 0.3, 0.9, 1.0)
	var effect_name: String = str(_effect.get("zh", ""))

	# Apply permanent stat on player_stats (flat additive)
	var player_stats: Node = null
	if player.has_method("get_node_or_null"):
		player_stats = player.get_node_or_null("PlayerStats")
	if player_stats != null and player_stats.has_method("add_permanent_bonus"):
		player_stats.call("add_permanent_bonus", stat, value)
	elif player_stats != null:
		# Fallback: directly modify a known stat property
		_apply_stat_fallback(player_stats, stat, value)

	if player.has_method("show_status_message"):
		var sign_str: String = "+" if value >= 0 else ""
		player.show_status_message("%s %s%d" % [effect_name, sign_str, value], msg_color)


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
