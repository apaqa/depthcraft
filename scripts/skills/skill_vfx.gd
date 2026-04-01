extends Node2D
class_name SkillVfx

@export var mode: String = "whirlwind"

var elapsed: float = 0.0
var duration: float = 0.3
var max_radius: float = 42.0
var ring_color: Color = Color(1.0, 1.0, 1.0, 0.7)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _draw() -> void:
	var t: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	match mode:
		"whirlwind":
			var alpha: float = 1.0 - t
			for index: int in range(3):
				var start_angle: float = t * TAU * 2.0 + float(index) * (TAU / 3.0)
				draw_arc(Vector2.ZERO, 18.0 + float(index) * 8.0, start_angle, start_angle + 1.4, 18, Color(1.0, 1.0, 1.0, alpha), 2.5)
		"war_cry":
			var radius: float = lerpf(8.0, max_radius, t)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 42, Color(1.0, 0.9, 0.35, 1.0 - t), 3.0)
		"ring":
			var radius: float = lerpf(4.0, max_radius, t)
			var alpha: float = 1.0 - t
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * alpha), 3.0)
