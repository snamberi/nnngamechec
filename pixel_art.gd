extends RefCounted
## Subtle floor markers for a called play.
static func play_guides(g) -> void:
	if g.play_call.is_empty() or g.play_call.team != 0:
		return
	var play: Dictionary = g.play_call
	var target: Vector2 = play.spot if play.phase != "roll" else g.RIGHT + Vector2(-35, 22)
	var color = Color("efe5ce")
	g.draw_arc(target, 12, 0, TAU, 20, color, 1)
	var origin: Vector2 = g.players[play.screener].pos
	for dot in range(1, 9):
		g.draw_rect(Rect2(origin.lerp(target, dot / 9.0), Vector2(1, 1)), color)
	g.label("ROLL" if play.phase == "roll" else "SCREEN", target + Vector2(-16, 23), 8, g.INK)
