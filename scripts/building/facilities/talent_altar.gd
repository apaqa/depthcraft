extends "res://scripts/building/upgradeable_facility.gd"
class_name TalentAltarFacility


func get_interaction_prompt() -> String:
	var lv_str: String = " Lv.%d" % get_upgrade_level()
	var upgrade_part: String = " / [U] " + LocaleManager.L("upgrade") if can_upgrade() else ""
	return LocaleManager.L("prompt_talent") + lv_str + upgrade_part


func interact(player) -> void:
	if player != null and player.has_method("request_talent_menu"):
		player.request_talent_menu(self)


func requires_home_core() -> bool:
	return true


func get_menu_title() -> String:
	return "%s Lv%d" % [LocaleManager.L("prompt_talent"), get_upgrade_level()]


func get_upgrade_summary() -> String:
	match get_upgrade_level():
		1:
			return "A simple altar for awakening talents."
		2:
			return "Ritual discount: -5% talent shard cost."
		3:
			return "Ritual discount: -10% talent shard cost."
		4:
			return "Ritual discount: -15% talent shard cost."
		_:
			return "Ritual discount: -20% talent shard cost. The altar is fully awakened."


func get_talent_cost_discount() -> float:
	return float(get_upgrade_level() - 1) * 0.05


func _on_upgrade_applied() -> void:
	super._on_upgrade_applied()
	print("Talent Altar upgraded to level %d — discount: %.0f%%" % [get_upgrade_level(), get_talent_cost_discount() * 100.0])
