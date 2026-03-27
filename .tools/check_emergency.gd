extends Node

const TARGETS := [
	"res://scripts/ui/home_arrow.gd",
	"res://scripts/world/merchant.gd",
	"res://scripts/dungeon/dungeon_merchant.gd",
]

func _ready() -> void:
	var had_error := false
	for path in TARGETS:
		var res := load(path)
		if res == null:
			printerr("PARSE_FAIL ", path)
			had_error = true
		else:
			print("PARSE_OK ", path)
	await get_tree().process_frame
	get_tree().quit(1 if had_error else 0)