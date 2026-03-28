extends SceneTree

const SAVE_SLOT: int = 99
const SAVE_SLOT_PATH: String = "user://save_slot_99.json"
const PLAYER_SAVE_PATH: String = "user://player_save.json"
const BUILDING_SAVE_PATH: String = "user://world_save.json"
const CLASS_SAVE_PATH: String = "user://class_save.json"
const ACHIEVEMENT_SAVE_PATH: String = "user://achievements.json"
const QUEST_SAVE_PATH: String = "user://quests.json"

var _failures: PackedStringArray = []


class FakePlayerStats extends Node:
	var base_attack: int = 15
	var base_defense: int = 4
	var base_max_hp: int = 140
	var base_speed: float = 90.0
	var equipment_bonuses: Dictionary = {}
	var rebuilt_talents: Array[String] = []

	func rebuild_talent_bonuses(unlocked_talents: Array[String]) -> void:
		rebuilt_talents = unlocked_talents.duplicate()

	func set_equipment_bonuses(effects: Dictionary) -> void:
		equipment_bonuses = effects.duplicate(true)

	func get_total_attack() -> int:
		return base_attack + int(round(float(equipment_bonuses.get("attack", 0.0))))

	func get_total_defense() -> int:
		return base_defense + int(round(float(equipment_bonuses.get("defense", 0.0))))

	func get_total_max_hp() -> int:
		return base_max_hp + int(round(float(equipment_bonuses.get("max_hp", 0.0))))

	func get_total_speed() -> float:
		return base_speed + float(equipment_bonuses.get("speed", 0.0))


class FakeInventory extends Node:
	var items: Array[Dictionary] = []

	func get_state() -> Array[Dictionary]:
		return _duplicate_items(items)

	func load_state(saved_items: Array) -> void:
		items.clear()
		for item_variant: Variant in saved_items:
			if item_variant is Dictionary:
				items.append((item_variant as Dictionary).duplicate(true))

	func get_item_count(item_id: String) -> int:
		var total: int = 0
		for item: Dictionary in items:
			if str(item.get("id", "")) == item_id:
				total += int(item.get("quantity", 0))
		return total

	func remove_item(item_id: String, quantity: int) -> bool:
		if quantity <= 0:
			return true
		if get_item_count(item_id) < quantity:
			return false
		var remaining: int = quantity
		for index: int in range(items.size() - 1, -1, -1):
			var item: Dictionary = items[index]
			if str(item.get("id", "")) != item_id:
				continue
			var removed: int = min(remaining, int(item.get("quantity", 0)))
			item["quantity"] = int(item.get("quantity", 0)) - removed
			remaining -= removed
			if int(item.get("quantity", 0)) <= 0:
				items.remove_at(index)
			else:
				items[index] = item
			if remaining <= 0:
				return true
		return true

	func add_item(item_id: String, quantity: int) -> bool:
		if quantity <= 0:
			return true
		for index: int in range(items.size()):
			var item: Dictionary = items[index]
			if str(item.get("id", "")) != item_id:
				continue
			item["quantity"] = int(item.get("quantity", 0)) + quantity
			items[index] = item
			return true
		items.append({
			"id": item_id,
			"quantity": quantity,
			"type": "currency",
			"max_stack": 999,
		})
		return true

	func _duplicate_items(source_items: Array[Dictionary]) -> Array[Dictionary]:
		var duplicated_items: Array[Dictionary] = []
		for item: Dictionary in source_items:
			duplicated_items.append(item.duplicate(true))
		return duplicated_items


class FakeEquipmentSystem extends Node:
	const SLOT_ORDER: PackedStringArray = ["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand", "tool"]

	var equipped: Dictionary = {}

	func _init() -> void:
		for slot_name: String in SLOT_ORDER:
			equipped[slot_name] = {}

	func get_slot_order() -> PackedStringArray:
		return SLOT_ORDER

	func serialize_state() -> Dictionary:
		return {"equipped": _duplicate_equipped_map(equipped)}

	func load_state(data: Dictionary) -> void:
		for slot_name: String in SLOT_ORDER:
			equipped[slot_name] = {}
		var equipped_payload: Dictionary = data.get("equipped", {}) as Dictionary
		for slot_name: String in SLOT_ORDER:
			if equipped_payload.has(slot_name):
				equipped[slot_name] = (equipped_payload.get(slot_name, {}) as Dictionary).duplicate(true)

	func equip(item_data: Dictionary, slot_name: String) -> Dictionary:
		var previous: Dictionary = (equipped.get(slot_name, {}) as Dictionary).duplicate(true)
		equipped[slot_name] = item_data.duplicate(true)
		return previous

	func get_total_bonus_map() -> Dictionary:
		var totals: Dictionary = {}
		for slot_name: String in SLOT_ORDER:
			var item: Dictionary = equipped.get(slot_name, {}) as Dictionary
			var item_stats: Dictionary = item.get("stats", {}) as Dictionary
			for stat_name_variant: Variant in item_stats.keys():
				var stat_name: String = str(stat_name_variant)
				totals[stat_name] = float(totals.get(stat_name, 0.0)) + float(item_stats.get(stat_name_variant, 0.0))
		return totals

	func _duplicate_equipped_map(source_map: Dictionary) -> Dictionary:
		var duplicated_map: Dictionary = {}
		for slot_name: String in SLOT_ORDER:
			duplicated_map[slot_name] = (source_map.get(slot_name, {}) as Dictionary).duplicate(true)
		return duplicated_map


class FakeBuildingInstance extends Node:
	var serialized_payload: Dictionary = {}

	func _init(data: Dictionary = {}) -> void:
		serialized_payload = data.duplicate(true)

	func serialize_data() -> Dictionary:
		return serialized_payload.duplicate(true)


class FakeBuildingSystem extends Node:
	var placed_buildings: Dictionary = {}
	var building_instances: Dictionary = {}
	var placed_facilities: Dictionary = {}
	var facility_instances: Dictionary = {}
	var home_core_position: Vector2 = Vector2.ZERO
	var active_level_id: String = "overworld"
	var active_level: Node = null
	var _loaded_from_save: bool = false
	var apply_saved_state_calls: int = 0

	func _apply_saved_state_to_level() -> void:
		apply_saved_state_calls += 1


class FakeHud extends Node:
	var class_label: Label = Label.new()
	var last_day_label: int = 0

	func _init() -> void:
		add_child(class_label)

	func update_day_label(day_value: int) -> void:
		last_day_label = day_value


class FakeLevel extends Node:
	var day_count: int = 0
	var deepest_floor_reached: int = 0

	func set_day_count(day_value: int) -> void:
		day_count = day_value

	func set_deepest_floor_reached(floor_value: int) -> void:
		deepest_floor_reached = floor_value


class FakeMainScene extends Node:
	var current_day: int = 1
	var deepest_dungeon_floor_reached: int = 1
	var hud: Node = null
	var current_level: Node = null


class FakePlayer extends Node2D:
	signal stats_changed
	signal hp_changed(current_hp: int, max_hp: int)

	var current_hp: int = 100
	var max_hp: int = 100
	var speed: float = 0.0
	var unlocked_talents: Array[String] = []
	var persistent_save_calls: int = 0
	var inventory: Node = null
	var equipment_system: Node = null
	var building_system: FakeBuildingSystem = null
	var player_stats: FakePlayerStats = null

	func _init() -> void:
		inventory = FakeInventory.new()
		inventory.name = "Inventory"
		add_child(inventory)

		equipment_system = FakeEquipmentSystem.new()
		equipment_system.name = "EquipmentSystem"
		add_child(equipment_system)

		building_system = FakeBuildingSystem.new()
		building_system.name = "BuildingSystem"
		add_child(building_system)

		player_stats = FakePlayerStats.new()
		player_stats.name = "PlayerStats"
		add_child(player_stats)

	func _ready() -> void:
		add_to_group("player")

	func _refresh_all_stats() -> void:
		max_hp = player_stats.get_total_max_hp()
		speed = player_stats.get_total_speed()
		current_hp = clampi(current_hp, 0, max_hp)

	func _save_persistent_state() -> void:
		persistent_save_calls += 1

	func get_unlocked_talents() -> Array[String]:
		return unlocked_talents.duplicate()

	func get_attack_damage() -> int:
		return player_stats.get_total_attack()


func _initialize() -> void:
	var backup_paths: Array[String] = [
		SAVE_SLOT_PATH,
		PLAYER_SAVE_PATH,
		BUILDING_SAVE_PATH,
		CLASS_SAVE_PATH,
		ACHIEVEMENT_SAVE_PATH,
		QUEST_SAVE_PATH,
	]
	var backups: Dictionary = _backup_files(backup_paths)
	await test_save_load_round_trip()
	await _cleanup_active_scene()
	_restore_files(backups)
	_report_results()


func test_save_load_round_trip() -> void:
	var setup: Dictionary = await _create_test_setup()
	var main_scene: FakeMainScene = setup["main_scene"] as FakeMainScene
	var player: FakePlayer = setup["player"] as FakePlayer

	var expected_snapshot: Dictionary = _capture_snapshot(main_scene, player)

	_save_manager().call("save_game", SAVE_SLOT)
	var saved_payload: Dictionary = _read_json_file(SAVE_SLOT_PATH)
	_assert_saved_payload(saved_payload)

	_clear_runtime_state(main_scene, player)
	_save_manager().call("load_game", SAVE_SLOT)
	await process_frame

	var restored_snapshot: Dictionary = _capture_snapshot(main_scene, player)
	_assert(restored_snapshot == expected_snapshot, "SaveManager should restore the same state that was saved.")
	_assert(player.building_system.apply_saved_state_calls > 0, "Loading buildings should re-apply saved building state to the active level.")
	_assert((main_scene.hud as FakeHud).last_day_label == int(expected_snapshot["progress"]["current_day"]), "HUD day label should refresh after load.")
	_assert((main_scene.current_level as FakeLevel).day_count == int(expected_snapshot["progress"]["current_day"]), "Current level day counter should refresh after load.")
	_assert((main_scene.current_level as FakeLevel).deepest_floor_reached == int(expected_snapshot["progress"]["deepest_floor"]), "Current level deepest floor should refresh after load.")


func _create_test_setup() -> Dictionary:
	var main_scene: FakeMainScene = FakeMainScene.new()
	main_scene.name = "FakeMainScene"

	var hud: FakeHud = FakeHud.new()
	hud.name = "HUD"
	main_scene.hud = hud
	main_scene.add_child(hud)

	var current_level: FakeLevel = FakeLevel.new()
	current_level.name = "CurrentLevel"
	main_scene.current_level = current_level
	main_scene.add_child(current_level)

	var player: FakePlayer = FakePlayer.new()
	player.name = "FakePlayer"
	main_scene.add_child(player)

	root.add_child(main_scene)
	current_scene = main_scene
	await process_frame

	_seed_runtime_state(main_scene, player)
	return {
		"main_scene": main_scene,
		"player": player,
	}


func _seed_runtime_state(main_scene: FakeMainScene, player: FakePlayer) -> void:
	_class_system().call("save_class", "warrior")

	player.player_stats.base_attack = 15
	player.player_stats.base_defense = 4
	player.player_stats.base_max_hp = 140
	player.player_stats.base_speed = 90.0
	player.unlocked_talents = ["O5", "O18", "S18"]
	player.global_position = Vector2(123.5, 456.25)

	var inventory_payload: Array = [
		{
			"id": "test_ore",
			"quantity": 7,
			"max_stack": 99,
			"type": "material",
			"stack_data": {
				"quality": "high",
				"origin": "unit_test",
			},
		},
		{
			"id": "test_bandage",
			"quantity": 3,
			"max_stack": 10,
			"type": "consumable",
			"stack_data": {
				"charges": 2,
				"note": "save_load",
			},
		},
		{"id": "gold", "quantity": 2, "max_stack": 999, "type": "currency"},
		{"id": "silver", "quantity": 4, "max_stack": 999, "type": "currency"},
		{"id": "copper", "quantity": 9, "max_stack": 999, "type": "currency"},
	]
	player.inventory.call("load_state", inventory_payload)

	var equipment_entries: Array[Dictionary] = [
		{
			"slot": "weapon",
			"id": "test_weapon",
			"type": "equipment",
			"quantity": 1,
			"rarity": "rare",
			"affixes": [{"id": "sharp", "value": 2}],
			"durability": 33,
			"max_durability": 40,
			"stats": {"attack": 6},
		},
		{
			"slot": "helmet",
			"id": "test_helmet",
			"type": "equipment",
			"quantity": 1,
			"rarity": "uncommon",
			"affixes": [{"id": "guarded", "value": 1}],
			"durability": 22,
			"max_durability": 30,
			"stats": {"defense": 3},
		},
		{
			"slot": "chest_armor",
			"id": "test_chest",
			"type": "equipment",
			"quantity": 1,
			"rarity": "epic",
			"affixes": [{"id": "fortified", "value": 8}],
			"durability": 41,
			"max_durability": 50,
			"stats": {"max_hp": 20},
		},
		{
			"slot": "boots",
			"id": "test_boots",
			"type": "equipment",
			"quantity": 1,
			"rarity": "rare",
			"affixes": [{"id": "swift", "value": 4}],
			"durability": 18,
			"max_durability": 25,
			"stats": {"speed": 4},
		},
		{
			"slot": "accessory",
			"id": "test_ring",
			"type": "equipment",
			"quantity": 1,
			"rarity": "legendary",
			"affixes": [{"id": "might", "value": 1}],
			"durability": 11,
			"max_durability": 15,
			"stats": {"attack": 2},
		},
		{
			"slot": "offhand",
			"id": "test_shield",
			"type": "equipment",
			"quantity": 1,
			"rarity": "rare",
			"affixes": [{"id": "bulwark", "value": 2}],
			"durability": 27,
			"max_durability": 35,
			"stats": {"defense": 5},
		},
		{
			"slot": "tool",
			"id": "test_tool",
			"type": "equipment",
			"quantity": 1,
			"rarity": "common",
			"affixes": [{"id": "utility", "value": 1}],
			"durability": 19,
			"max_durability": 20,
			"stats": {"max_hp": 5, "speed": 3},
		},
	]
	for equipment_entry: Dictionary in equipment_entries:
		player.equipment_system.call("equip", equipment_entry, str(equipment_entry.get("slot", "")))
	player.player_stats.set_equipment_bonuses(player.equipment_system.call("get_total_bonus_map"))
	player._refresh_all_stats()
	player.current_hp = 121

	player.building_system.home_core_position = Vector2(96.0, 160.0)
	player.building_system.placed_buildings = {
		Vector2i(2, 3): {
			"id": "wood_wall",
			"data": {
				"upgrade_level": 2,
				"current_hp": 34,
				"max_hp": 60,
			},
		},
		Vector2i(4, 5): {
			"id": "stone_floor",
			"data": {
				"upgrade_level": 1,
				"current_hp": 20,
				"max_hp": 20,
			},
		},
	}
	var wall_instance: FakeBuildingInstance = FakeBuildingInstance.new({"upgrade_level": 2, "current_hp": 34, "max_hp": 60})
	var floor_instance: FakeBuildingInstance = FakeBuildingInstance.new({"upgrade_level": 1, "current_hp": 20, "max_hp": 20})
	player.building_system.add_child(wall_instance)
	player.building_system.add_child(floor_instance)
	player.building_system.building_instances = {
		Vector2i(2, 3): wall_instance,
		Vector2i(4, 5): floor_instance,
	}
	player.building_system.placed_facilities = {
		Vector2i(6, 7): {
			"id": "workbench",
			"data": {
				"upgrade_level": 3,
				"current_hp": 88,
				"max_hp": 100,
			},
		},
	}
	var facility_instance: FakeBuildingInstance = FakeBuildingInstance.new({"upgrade_level": 3, "current_hp": 88, "max_hp": 100})
	player.building_system.add_child(facility_instance)
	player.building_system.facility_instances = {
		Vector2i(6, 7): facility_instance,
	}
	player.building_system.active_level = player.building_system
	player.building_system.apply_saved_state_calls = 0

	_achievement_manager().set("stats", {
		"enemies_killed": 5,
	})
	_achievement_manager().set("unlocked_achievements", {
		"first_kill": true,
	})

	_skill_system().call("bind_player", player)
	_skill_system().call("sync_from_player_talents")
	_skill_system().call("set_equipped_skill_ids", ["whirlwind", "execute", "sprint"])
	_npc_manager().call("restore_state", {
		"recruited_npcs": [
			{
				"id": "npc_farmer_1",
				"name": "阿洛1",
				"role": "farmer",
				"portrait_path": "res://assets/npc_dwarf.png",
				"recruited": true,
			},
			{
				"id": "npc_guard_1",
				"name": "米菈2",
				"role": "guard",
				"portrait_path": "res://assets/npc_knight_blue.png",
				"recruited": true,
			},
		],
		"current_day": 12,
		"last_processed_day": 12,
		"last_claimed_explorer_day": 11,
	})

	main_scene.current_day = 12
	main_scene.deepest_dungeon_floor_reached = 8
	_quest_manager().call("set_day", 12)


func _clear_runtime_state(main_scene: FakeMainScene, player: FakePlayer) -> void:
	player.global_position = Vector2.ZERO
	player.current_hp = 1
	player.max_hp = 1
	player.speed = 0.0
	player.unlocked_talents.clear()
	player.inventory.call("load_state", [])
	player.equipment_system.call("load_state", {})
	player.player_stats.set_equipment_bonuses({})
	player.building_system.placed_buildings = {}
	player.building_system.building_instances = {}
	player.building_system.placed_facilities = {}
	player.building_system.facility_instances = {}
	player.building_system.home_core_position = Vector2.ZERO
	player.building_system.apply_saved_state_calls = 0

	main_scene.current_day = 1
	main_scene.deepest_dungeon_floor_reached = 1
	(main_scene.hud as FakeHud).last_day_label = 0
	(main_scene.current_level as FakeLevel).day_count = 0
	(main_scene.current_level as FakeLevel).deepest_floor_reached = 0

	_class_system().call("reset_class_selection")
	_achievement_manager().set("stats", {})
	_achievement_manager().set("unlocked_achievements", {})

	var unlocked_skill_ids_variant: Variant = _skill_system().get("unlocked_skill_ids")
	if unlocked_skill_ids_variant is Array:
		(unlocked_skill_ids_variant as Array).clear()
	_skill_system().call("set_equipped_skill_ids", ["", "", ""])
	_quest_manager().call("set_day", 1)
	_npc_manager().call("clear_state")


func _capture_snapshot(main_scene: FakeMainScene, player: FakePlayer) -> Dictionary:
	var equipped_skill_ids: Array[String] = []
	var equipped_skill_ids_variant: Variant = _skill_system().get("equipped_skill_ids")
	if equipped_skill_ids_variant is Array:
		for skill_id_variant: Variant in (equipped_skill_ids_variant as Array):
			equipped_skill_ids.append(str(skill_id_variant))
	var unlocked_achievements_variant: Variant = _achievement_manager().get("unlocked_achievements")
	var unlocked_achievements: Dictionary = unlocked_achievements_variant as Dictionary if unlocked_achievements_variant is Dictionary else {}
	var unlocked_achievement_ids: Array[String] = _sorted_true_keys(unlocked_achievements)
	var achievement_stats_variant: Variant = _achievement_manager().get("stats")
	var achievement_stats: Dictionary = achievement_stats_variant as Dictionary if achievement_stats_variant is Dictionary else {}
	var snapshot: Dictionary = {
		"player": {
			"position": [float(player.global_position.x), float(player.global_position.y)],
			"hp": player.current_hp,
			"max_hp": player.max_hp,
			"class_id": str(_class_system().get("current_class_id")),
			"attack": player.player_stats.get_total_attack(),
			"defense": player.player_stats.get_total_defense(),
			"speed": player.player_stats.get_total_speed(),
		},
		"inventory": player.inventory.call("get_state"),
		"equipment": player.equipment_system.call("serialize_state"),
		"currency": {
			"gold": int(player.inventory.call("get_item_count", "gold")),
			"silver": int(player.inventory.call("get_item_count", "silver")),
			"copper": int(player.inventory.call("get_item_count", "copper")),
		},
		"buildings": {
			"buildings": _normalize_building_records(player.building_system.placed_buildings),
			"facilities": _normalize_building_records(player.building_system.placed_facilities),
			"home_core_position": [float(player.building_system.home_core_position.x), float(player.building_system.home_core_position.y)],
		},
		"talents": player.get_unlocked_talents(),
		"progress": {
			"current_day": main_scene.current_day,
			"deepest_floor": main_scene.deepest_dungeon_floor_reached,
			"total_kills": int(achievement_stats.get("enemies_killed", 0)),
			"achievements": unlocked_achievement_ids,
		},
		"skills": equipped_skill_ids,
		"npcs": _npc_manager().call("serialize_state"),
	}
	return _normalize_variant(snapshot) as Dictionary


func _normalize_building_records(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant: Variant in source.keys():
		var key_text: String = str(key_variant)
		if key_variant is Vector2i:
			var key_value: Vector2i = key_variant as Vector2i
			key_text = "%d,%d" % [key_value.x, key_value.y]
		var record: Dictionary = (source[key_variant] as Dictionary).duplicate(true)
		if not record.has("type") and record.has("id"):
			record["type"] = str(record.get("id", ""))
		normalized[key_text] = _normalize_variant(record)
	return normalized


func _normalize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var normalized_dictionary: Dictionary = {}
			for key_variant: Variant in (value as Dictionary).keys():
				normalized_dictionary[str(key_variant)] = _normalize_variant((value as Dictionary).get(key_variant))
			return normalized_dictionary
		TYPE_ARRAY:
			var normalized_array: Array = []
			for element: Variant in value as Array:
				normalized_array.append(_normalize_variant(element))
			return normalized_array
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		_:
			return value


func _sorted_true_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant: Variant in source.keys():
		if bool(source.get(key_variant, false)):
			result.append(str(key_variant))
	result.sort()
	return result


func _assert_saved_payload(payload: Dictionary) -> void:
	_assert(not payload.is_empty(), "Save payload should not be empty.")
	_assert(payload.has("player"), "Save payload should include player data.")
	_assert(payload.has("inventory"), "Save payload should include inventory data.")
	_assert(payload.has("equipment"), "Save payload should include equipment data.")
	_assert(payload.has("currency"), "Save payload should include currency data.")
	_assert(payload.has("buildings"), "Save payload should include building data.")
	_assert(payload.has("skills"), "Save payload should include skill data.")
	_assert(payload.has("npcs"), "Save payload should include NPC data.")
	_assert(payload.has("progress"), "Save payload should include progress data.")

	var player_payload: Dictionary = payload.get("player", {}) as Dictionary
	_assert(player_payload.has("position"), "Player payload should include position.")
	_assert(player_payload.has("hp"), "Player payload should include hp.")
	_assert(player_payload.has("max_hp"), "Player payload should include max_hp.")
	_assert(player_payload.has("class_id"), "Player payload should include class_id.")
	_assert(player_payload.has("attack"), "Player payload should include attack.")
	_assert(player_payload.has("defense"), "Player payload should include defense.")
	_assert(player_payload.has("speed"), "Player payload should include speed.")

	var inventory_payload: Array = payload.get("inventory", []) as Array
	_assert(not inventory_payload.is_empty(), "Inventory payload should contain saved stacks.")
	if not inventory_payload.is_empty():
		var inventory_entry: Dictionary = inventory_payload[0] as Dictionary
		_assert(inventory_entry.has("id"), "Inventory entries should include id.")
		_assert(inventory_entry.has("quantity"), "Inventory entries should include quantity.")
		_assert(inventory_entry.has("stack_data"), "Inventory entries should include stack_data.")

	var equipment_payload: Dictionary = payload.get("equipment", {}) as Dictionary
	var equipped_payload: Dictionary = equipment_payload.get("equipped", {}) as Dictionary
	_assert(equipped_payload.size() == 7, "Equipment payload should preserve all 7 equipment slots.")

	var currency_payload: Dictionary = payload.get("currency", {}) as Dictionary
	_assert(currency_payload.has("gold"), "Currency payload should include gold.")
	_assert(currency_payload.has("silver"), "Currency payload should include silver.")
	_assert(currency_payload.has("copper"), "Currency payload should include copper.")

	var building_payload: Dictionary = payload.get("buildings", {}) as Dictionary
	var building_entries: Dictionary = building_payload.get("buildings", {}) as Dictionary
	_assert(not building_entries.is_empty(), "Building payload should include placed buildings.")
	if not building_entries.is_empty():
		var first_building_key: Variant = building_entries.keys()[0]
		var first_building: Dictionary = building_entries.get(first_building_key, {}) as Dictionary
		_assert(first_building.has("type"), "Building payload should include type.")
		_assert(first_building.has("position"), "Building payload should include position.")
		_assert(first_building.has("level"), "Building payload should include level.")
		_assert(first_building.has("current_hp"), "Building payload should include current_hp.")

	var facility_entries: Array = building_payload.get("facilities", []) as Array
	_assert(not facility_entries.is_empty(), "Building payload should include facility records.")
	if not facility_entries.is_empty():
		var first_facility: Dictionary = facility_entries[0] as Dictionary
		_assert(first_facility.has("type"), "Facility payload should include type.")
		_assert(first_facility.has("position"), "Facility payload should include position.")
		_assert(first_facility.has("level"), "Facility payload should include level.")
		_assert(first_facility.has("current_hp"), "Facility payload should include current_hp.")

	var progress_payload: Dictionary = payload.get("progress", {}) as Dictionary
	_assert(progress_payload.has("current_day"), "Progress payload should include current_day.")
	_assert(progress_payload.has("deepest_floor"), "Progress payload should include deepest_floor.")
	_assert(progress_payload.has("total_kills"), "Progress payload should include total_kills.")
	_assert(progress_payload.has("achievements"), "Progress payload should include achievements.")

	var skills_payload: Dictionary = payload.get("skills", {}) as Dictionary
	_assert(skills_payload.has("equipped_skill_ids"), "Skill payload should include equipped_skill_ids.")

	var npc_payload: Dictionary = payload.get("npcs", {}) as Dictionary
	_assert(npc_payload.has("recruited_npcs"), "NPC payload should include recruited_npcs.")
	_assert(int((npc_payload.get("recruited_npcs", []) as Array).size()) == 2, "NPC payload should preserve recruited NPCs.")


func _backup_files(paths: Array[String]) -> Dictionary:
	var backups: Dictionary = {}
	for path: String in paths:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var exists: bool = FileAccess.file_exists(absolute_path)
		var text: String = ""
		if exists:
			var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(absolute_path)
			text = raw_bytes.get_string_from_utf8()
		backups[path] = {
			"exists": exists,
			"text": text,
		}
	return backups


func _restore_files(backups: Dictionary) -> void:
	for path_variant: Variant in backups.keys():
		var path: String = str(path_variant)
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var entry: Dictionary = backups.get(path, {}) as Dictionary
		if bool(entry.get("exists", false)):
			DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
			var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
			if file != null:
				file.store_string(str(entry.get("text", "")))
				file.flush()
			continue
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _read_json_file(path: String) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return {}
	var raw_text: String = FileAccess.get_file_as_string(absolute_path)
	if raw_text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw_text)
	return parsed if parsed is Dictionary else {}


func _cleanup_active_scene() -> void:
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame


func _save_manager() -> Node:
	return root.get_node("/root/SaveManager")


func _class_system() -> Node:
	return root.get_node("/root/ClassSystem")


func _achievement_manager() -> Node:
	return root.get_node("/root/AchievementManager")


func _skill_system() -> Node:
	return root.get_node("/root/SkillSystem")


func _quest_manager() -> Node:
	return root.get_node("/root/QuestManager")


func _npc_manager() -> Node:
	return root.get_node("/root/NpcManager")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report_results() -> void:
	if _failures.is_empty():
		print("Save/load test passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("Save/load test failed.")
	quit(1)
