extends StaticBody2D
class_name FarmPlotFacility

signal farm_changed

enum PlotState {
	EMPTY,
	PLANTED,
	GROWING,
	READY,
}

const GROWTH_DURATION := 120.0

@onready var dirt_polygon: Polygon2D = $Dirt
@onready var sprout_polygon: Polygon2D = $Sprout
@onready var crop_polygon: Polygon2D = $Crop

var state: int = PlotState.EMPTY
var planted_at_unix: float = 0.0


func _ready() -> void:
	set_process(true)
	_refresh_visuals()


func _process(_delta: float) -> void:
	_update_growth_state()


func get_interaction_prompt() -> String:
	_update_growth_state()
	match state:
		PlotState.EMPTY:
			return "[E] ç¨®æ? (1ç¨®å?)"
		PlotState.READY:
			return "[E] ?¶ç©«"
		_:
			return "Growing... %d seconds left" % int(ceil(get_time_remaining()))


func interact(player) -> void:
	_update_growth_state()
	if player == null:
		return
	match state:
		PlotState.EMPTY:
			if player.inventory.get_item_count("seed") < 1:
				if player.has_method("show_status_message"):
					player.show_status_message("?€è¦?ç¨®å?", Color(1.0, 0.6, 0.4, 1.0))
				return
			player.inventory.remove_item("seed", 1)
			state = PlotState.PLANTED
			planted_at_unix = Time.get_unix_time_from_system()
			_refresh_visuals()
			farm_changed.emit()
		PlotState.READY:
			var wheat_amount := randi_range(2, 3)
			player.inventory.add_item("wheat", wheat_amount)
			if randf() <= 0.5:
				player.inventory.add_item("seed", 1)
			state = PlotState.EMPTY
			planted_at_unix = 0.0
			_refresh_visuals()
			farm_changed.emit()


func requires_home_core() -> bool:
	return true


func serialize_data() -> Dictionary:
	return {
		"state": state,
		"planted_at_unix": planted_at_unix,
	}


func load_from_data(data: Dictionary) -> void:
	state = int(data.get("state", PlotState.EMPTY))
	planted_at_unix = float(data.get("planted_at_unix", 0.0))
	_update_growth_state()
	_refresh_visuals()


func get_time_remaining() -> float:
	if planted_at_unix <= 0.0:
		return GROWTH_DURATION
	return max(GROWTH_DURATION - (Time.get_unix_time_from_system() - planted_at_unix), 0.0)


func _update_growth_state() -> void:
	if state == PlotState.EMPTY or planted_at_unix <= 0.0:
		return
	if get_time_remaining() <= 0.0:
		state = PlotState.READY
	elif get_time_remaining() <= GROWTH_DURATION * 0.5:
		state = PlotState.GROWING
	else:
		state = PlotState.PLANTED
	_refresh_visuals()


func _refresh_visuals() -> void:
	if dirt_polygon != null:
		dirt_polygon.color = Color(0.39, 0.24, 0.12, 1.0)
	if sprout_polygon != null:
		sprout_polygon.visible = state == PlotState.PLANTED or state == PlotState.GROWING
		sprout_polygon.scale = Vector2.ONE if state == PlotState.PLANTED else Vector2(1.25, 1.25)
	if crop_polygon != null:
		crop_polygon.visible = state == PlotState.READY

