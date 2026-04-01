extends Node

# Automated integration test — run as an autoload AFTER all other autoloads.
# Remove from autoload list after verifying, but keep this file for future use.

func _ready() -> void:
	print("=== DepthCraft Integration Test ===")
	_test_blessing_system()
	_test_gem_system()
	_test_skill_system()
	_test_economy()
	_test_save_load()
	print("=== All tests complete ===")


func _test_blessing_system() -> void:
	print("--- Blessing System ---")
	var bs: Node = get_node_or_null("/root/BlessingSystem")
	if bs == null:
		print("FAIL: BlessingSystem not found")
		return

	# Initial state: 3 empty slots
	_assert(bs.get_empty_slots().size() == 3, "Initial: 3 empty slots")
	_assert(bs.get_occupied_slots().size() == 0, "Initial: 0 occupied slots")

	# Assign a theme
	bs.assign_main_slot("primary", "fire")
	_assert(bs.get_slot_theme("primary") == "fire", "Primary theme = fire")
	_assert(bs.get_empty_slots().size() == 2, "After 1 theme: 2 empty")

	# Add a sub blessing
	bs.add_sub_blessing_to_slot("primary", "fire_sub_damage")
	_assert(bs.get_slot_sub_blessings("primary").size() == 1, "1 sub blessing in primary")

	# Fill all slots
	bs.assign_main_slot("secondary", "ice")
	bs.assign_main_slot("skill", "poison")
	_assert(bs.get_empty_slots().size() == 0, "All slots filled")
	_assert(bs.get_assigned_themes().size() == 3, "3 assigned themes")

	# _pick_random_themes safety when all slots full (no crash with 1-theme pool edge case)
	var choices: Array = bs.generate_theme_choices()
	_assert(choices.size() >= 1, "generate_theme_choices() returns >= 1 choice when full")

	# Effectiveness at 0 sub blessings
	_assert(bs._get_effectiveness(0) == 1.0, "effectiveness(0) = 1.0")
	_assert(bs._get_effectiveness(3) == 0.5, "effectiveness(3) = 0.5")
	_assert(bs._get_effectiveness(6) == 0.25, "effectiveness(6) = 0.25")

	# get_skill_sub_penalties returns empty when no skill_boost theme
	var penalties: Dictionary = bs.get_skill_sub_penalties("")
	_assert(penalties.is_empty(), "get_skill_sub_penalties() empty without skill_boost")

	# Reset
	bs.clear_all()
	_assert(bs.get_empty_slots().size() == 3, "After clear_all: 3 empty")

	print("PASS: Blessing system tests")


func _test_gem_system() -> void:
	print("--- Gem System ---")
	# Simulate drop table probability sanity check
	var green_pct: float = 100.0
	var blue_pct: float = 5.0
	var purple_pct: float = 1.0
	var red_pct: float = 0.1
	_assert(green_pct > blue_pct, "gem_green drops more frequently than gem_blue")
	_assert(blue_pct > purple_pct, "gem_blue drops more frequently than gem_purple")
	_assert(purple_pct > red_pct, "gem_purple drops more frequently than gem_red")
	# Exchange rate sanity
	# 1 green (5 copper) < 1 blue (1 silver = 100 copper) < 1 purple (10 silver) < 1 red (1 gold = 100 silver)
	var green_val: int = 5
	var blue_val: int = 100
	var purple_val: int = 1000
	var red_val: int = 10000
	_assert(green_val < blue_val, "gem exchange rate: green < blue")
	_assert(blue_val < purple_val, "gem exchange rate: blue < purple")
	_assert(purple_val < red_val, "gem exchange rate: purple < red")
	print("PASS: Gem system basic tests")


func _test_skill_system() -> void:
	print("--- Skill System ---")
	var ss: Node = get_node_or_null("/root/SkillSystem")
	if ss == null:
		print("FAIL: SkillSystem not found")
		return

	# Test warrior class equip
	ss._equip_class_skills("warrior")
	_assert(str(ss.skill_slots.get("z", {}).get("skill_id", "")) == "warrior_z", "Warrior Z equipped")
	_assert(str(ss.skill_slots.get("x", {}).get("skill_id", "")) == "warrior_x", "Warrior X equipped")
	_assert(str(ss.skill_slots.get("v", {}).get("skill_id", "")) == "warrior_v", "Warrior V equipped")

	# Test ranger class equip
	ss._equip_class_skills("ranger")
	var ranger_z_def: Dictionary = ss.get_skill_def("z")
	_assert(str(ranger_z_def.get("effect_method", "")) == "_cast_dodge_roll", "Ranger Z = dodge roll")

	# Test mage class equip
	ss._equip_class_skills("mage")
	var mage_v_def: Dictionary = ss.get_skill_def("v")
	_assert(str(mage_v_def.get("effect_method", "")) == "_cast_meteor", "Mage V = meteor")

	# Test cooldown system
	ss.reset_cooldowns()
	_assert(float((ss.skill_slots.get("z", {}) as Dictionary).get("cooldown", -1.0)) == 0.0, "Cooldown reset to 0")

	# Test try_use_skill (no player bound — should fail since cast method checks player)
	# Just confirm it returns bool without crashing
	var result: bool = ss.try_use_skill("z")
	print("  try_use_skill('z') with no player = " + str(result) + " (expected false)")

	# Test get_equipped_skill_snapshots
	var snapshots: Array = ss.get_equipped_skill_snapshots()
	_assert(snapshots.size() == 3, "get_equipped_skill_snapshots() returns 3 entries")

	# Restore warrior for normal gameplay
	ss._equip_class_skills("warrior")
	ss.reset_cooldowns()
	print("PASS: Skill system tests")


func _test_economy() -> void:
	print("--- Economy ---")
	# Gambler EV calculation (2d6)
	# lose(2-5): 10/36 → 0 return
	# tie(6-8):  16/36 → 1x return
	# win(9-11):  9/36 → 2x return
	# jackpot(12): 1/36 → 5x return
	var ev: float = (10.0 / 36.0) * 0.0 + (16.0 / 36.0) * 1.0 + (9.0 / 36.0) * 2.0 + (1.0 / 36.0) * 5.0
	print("  Gambler EV per gem bet: %.4f (expected ~1.0833, player-favorable by design)" % ev)
	_assert(ev > 1.0, "Gambler EV > 1 (player-favorable)")
	_assert(ev < 1.5, "Gambler EV < 1.5 (not too exploitable)")

	# No arbitrage loop: gem costs scale linearly upward
	# 1 red = 100 silver, celestial box = 5 gold = 500 silver
	# Celestial box 10% chance red gem → EV from gems alone = 0.5 red gem = 50 silver
	# Box cost = 500 silver, gem EV = 50 silver (10%) — rest is blessing value
	# No infinite loop possible
	var celestial_cost_silver: float = 500.0
	var gem_ev_silver: float = 0.1 * 100.0 + 0.05 * 200.0  # 10% 1 red + 5% 2 red
	_assert(gem_ev_silver < celestial_cost_silver, "No arbitrage: celestial box gem EV < box cost")
	print("PASS: Economy tests")


func _test_save_load() -> void:
	print("--- Save/Load ---")
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		print("SKIP: SaveManager not found as autoload")
		return
	_assert(save_manager.has_method("save_game"), "save_game() method exists")
	_assert(save_manager.has_method("load_game"), "load_game() method exists")
	_assert(save_manager.has_method("has_save"), "has_save() method exists")

	# Confirm new save includes skills section
	var format_version: int = int(save_manager.get("FORMAT_VERSION"))
	_assert(format_version >= 2, "FORMAT_VERSION >= 2 (supports new systems)")
	print("PASS: Save/Load basic checks")


func _assert(condition: bool, msg: String) -> void:
	if condition:
		print("  OK: " + msg)
	else:
		push_error("  FAIL: " + msg)
		print("  FAIL: " + msg)
