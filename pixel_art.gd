extends RefCounted
## Code-native pixel sprites: individual hairstyles, eight-way facing,
## articulated limbs, action poses, shadows, and colored jersey trim.

static func rect(g, x: float, y: float, w: float, h: float, color: Color) -> void:
	g.draw_rect(Rect2(roundf(x), roundf(y), w, h), color)

static func limb(g, from: Vector2, to: Vector2, color: Color, width: int = 4) -> void:
	g.draw_line(from.round(), to.round(), g.INK, width + 2, false)
	g.draw_line(from.round(), to.round(), color, width, false)

static func player(g, i: int) -> void:
	var p: Dictionary = g.players[i]
	var color: Color = g.TEAL if i < 3 else g.PINK
	var dark = Color("205b65") if i < 3 else Color("792d50")
	var skin: Color = [Color("bd8059"), Color("ebba86"), Color("88563f")][i % 3]
	var shade = skin.darkened(0.23)
	var facing: Vector2 = p.facing
	var turn = signf(facing.x)
	var rear = facing.y < -0.45
	var side = absf(facing.x) > 0.75
	var jump: float = sin(p.jump * PI) * (21 if p.action in ["two_hand", "tomahawk"] else 12)
	var running: bool = p.velocity.length() > 10
	var stride = roundf(sin(p.step) * 4) if running else 0.0
	var lean: float = clampf(p.velocity.x / 55, -2, 2)
	var pose: String = p.action
	for ghost in p.trail:
		g.draw_rect(Rect2(Vector2(ghost.pos) + Vector2(-7, -27), Vector2(14, 24)), Color(color, ghost.life * 1.8))
	g.draw_set_transform(Vector2(p.pos).round())
	for y in range(3):
		rect(g, -10 + abs(y - 1) * 2, y - 1, 20 - abs(y - 1) * 4, 1, Color(0.03, 0.04, 0.09, 0.3))
	if i == g.controlled:
		g.draw_arc(Vector2(0, 1), 13, 0, TAU, 20, color, 1)
		g.draw_colored_polygon(PackedVector2Array([Vector2(-4, -44), Vector2(4, -44), Vector2(0, -39)]), color)
	if p.stun > 0:
		rect(g, -6, -42, 3, 3, g.GOLD)
		rect(g, 5, -40, 2, 2, g.GOLD)
	var bob = -1 if running and int(p.step / PI) % 2 else 0
	g.draw_set_transform(Vector2(p.pos).round() + Vector2(lean, -roundf(jump) + bob))
	# Shoes, socks, and articulated legs.
	var left_foot = Vector2(-5 - stride * 0.5, -1 + stride * 0.45)
	var right_foot = Vector2(5 + stride * 0.5, -1 - stride * 0.45)
	if pose == "spin":
		turn = signf(sin(p.action_time * 24))
		left_foot.x += turn * 3
	if pose in ["layup", "reverse", "floater", "tomahawk"]:
		right_foot = Vector2(9, -10)
	limb(g, Vector2(-4, -13), left_foot - Vector2(0, 3), skin, 4)
	limb(g, Vector2(4, -13), right_foot - Vector2(0, 3), shade, 4)
	rect(g, left_foot.x - 2, left_foot.y - 4, 4, 3, g.WHITE)
	rect(g, right_foot.x - 2, right_foot.y - 4, 4, 3, g.WHITE)
	rect(g, left_foot.x - 3, left_foot.y, 8, 3, g.INK)
	rect(g, right_foot.x - 3, right_foot.y, 8, 3, g.INK)
	rect(g, left_foot.x - 3, left_foot.y, 6, 2, g.GOLD if i % 3 == 0 else g.WHITE)
	rect(g, right_foot.x - 3, right_foot.y, 6, 2, g.GOLD if i % 3 == 0 else g.WHITE)
	# Shorts, side stripe, jersey, shoulder panels, collar.
	rect(g, -8, -17, 16, 7, g.INK)
	rect(g, -7, -17, 6, 6, dark)
	rect(g, 1, -17, 6, 6, dark)
	rect(g, -7, -14, 2, 3, color)
	rect(g, 5, -14, 2, 3, color)
	rect(g, -8, -29, 16, 13, g.INK)
	rect(g, -7, -28, 14, 12, dark if rear else color)
	rect(g, 4, -27, 3, 10, dark)
	rect(g, -7, -27, 2, 10, g.WHITE)
	rect(g, -3, -29, 6, 3, skin)
	rect(g, -4, -26, 8, 1, g.WHITE)
	rect(g, -6, -18, 12, 2, g.WHITE)
	# Arms use separate action poses, not a single reused running sprite.
	var left_hand = Vector2(-10 - stride * 0.4, -19 - stride)
	var right_hand = Vector2(10 + stride * 0.4, -19 + stride)
	if i == g.carrier:
		if p.hand > 0:
			right_hand = Vector2(11, -13 + absf(sin(g.elapsed * 13)) * 8)
		else:
			left_hand = Vector2(-11, -13 + absf(sin(g.elapsed * 13)) * 8)
	if pose in ["jumper", "two_hand", "fake", "block"] or (i == g.controlled and g.charge >= 0):
		left_hand = Vector2(-5, -39)
		right_hand = Vector2(5, -40)
	elif pose in ["layup", "floater", "tomahawk"]:
		right_hand = Vector2(9, -44)
		left_hand = Vector2(-14, -24)
	elif pose == "reverse":
		left_hand = Vector2(-13, -38)
		right_hand = Vector2(13, -21)
	elif pose == "pass":
		left_hand = Vector2(turn * 16, -26)
		right_hand = Vector2(turn * 19, -24)
	elif pose == "screen":
		left_hand = Vector2(-3, -21)
		right_hand = Vector2(3, -21)
	elif pose == "cross":
		right_hand = Vector2(p.hand * 14, -13)
	elif pose == "spin":
		left_hand = Vector2(-turn * 12, -24)
		right_hand = Vector2(turn * 14, -15)
	limb(g, Vector2(-8, -26), left_hand, skin)
	limb(g, Vector2(8, -26), right_hand, shade)
	rect(g, right_hand.x - 2, right_hand.y - 2, 4, 2, g.WHITE)
	# Face, ears, hair silhouette. Each roster slot has a different cut.
	var hx = turn * 2 if side else 0.0
	rect(g, hx - 6, -39, 12, 11, g.INK)
	rect(g, hx - 5, -38, 10, 9, skin)
	rect(g, hx + 3, -36, 2, 7, shade)
	rect(g, hx - 7, -34, 2, 3, skin)
	rect(g, hx + 5, -34, 2, 3, shade)
	var hair = Color("251f29") if i % 3 != 1 else Color("614437")
	match i % 3:
		0:
			rect(g, hx - 6, -41, 12, 5, hair)
			rect(g, hx - 4, -43, 8, 3, hair)
		1:
			rect(g, hx - 5, -39, 10, 3, hair)
			rect(g, hx - 5, -37, 10, 2, color)
		2:
			rect(g, hx - 5, -40, 10, 4, hair)
			rect(g, hx - 7, -38, 3, 9, hair)
			rect(g, hx + 4, -38, 3, 9, hair)
	if rear:
		rect(g, hx - 5, -36, 10, 6, hair)
	else:
		if not side or turn < 0:
			rect(g, hx - 3, -34, 2, 2, g.INK)
		if not side or turn > 0:
			rect(g, hx + 2, -34, 2, 2, g.INK)
		rect(g, hx - 1 + turn, -30, 3, 1, shade)
	g.label(str(i % 3 + 1), Vector2(-3, -19), 8, g.WHITE if rear else g.INK)
	g.draw_set_transform(Vector2.ZERO)
	if i == g.controlled:
		g.draw_rect(Rect2(p.pos.x - 12, p.pos.y + 7, 24, 3), g.INK)
		g.draw_rect(Rect2(p.pos.x - 12, p.pos.y + 7, 24 * p.stamina, 2), color if p.stamina > 0.23 else g.GOLD)

static func spectators(g) -> void:
	for row in range(2):
		for col in range(37):
			var x = 19 + col * 16
			var y = 66 + row * 11
			var excited: bool = g.crowd_energy > 0.2 and (col + row) % 3 != 0
			var bob = int(sin(g.elapsed * 13 + col) * 2) if excited else 0
			var shirt: Color = [Color("495679"), Color("5f4160"), Color("34727a"), Color("8d6a51")][(col + row * 3) % 4]
			rect(g, x, y + 2, 11, 7, Color("202e48"))
			rect(g, x + 2, y + bob, 7, 6, shirt)
			rect(g, x + 3, y - 4 + bob, 5, 4, Color("bf8e73") if col % 2 else Color("805b4c"))
			if excited:
				rect(g, x, y - 5 + bob, 2, 7, shirt)
				rect(g, x + 9, y - 5 + bob, 2, 7, shirt)
	# Benches and reserves, tucked outside both baselines.
	for side in range(2):
		var x = 10 if side == 0 else 611
		var color: Color = g.TEAL if side == 0 else g.PINK
		rect(g, x - 3, 129, 19, 119, Color("26364d"))
		for seat in range(4):
			var y = 137 + seat * 29
			rect(g, x, y + 4, 12, 9, color.darkened(0.4))
			rect(g, x + 3, y - 2, 6, 6, Color("b98261"))
			rect(g, x, y + 13, 4, 5, g.WHITE)
			rect(g, x + 8, y + 13, 4, 5, g.WHITE)
	# Sideline official follows the ball; striped jersey and whistle.
	var rx: float = clampf(g.ball.x, 260, 390)
	var ry = 324
	rect(g, rx - 4, ry - 8, 8, 9, g.WHITE)
	for stripe in [-3, 0, 3]:
		rect(g, rx + stripe, ry - 8, 1, 9, g.INK)
	rect(g, rx - 3, ry - 14, 6, 6, Color("c59777"))
	rect(g, rx - 4, ry + 1, 3, 6, Color("67748a"))
	rect(g, rx + 1, ry + 1, 3, 6, Color("67748a"))

static func play_guides(g) -> void:
	if g.play_call.is_empty() or g.play_call.team != 0:
		return
	var play: Dictionary = g.play_call
	var target: Vector2 = play.spot if play.phase != "roll" else g.RIGHT + Vector2(-35, 22)
	g.draw_arc(target, 12, 0, TAU, 20, Color(g.TEAL, 0.65), 1)
	var from: Vector2 = g.players[play.screener].pos
	for dot in range(1, 9):
		g.draw_rect(Rect2(from.lerp(target, dot / 9.0), Vector2(2, 2)), Color(g.TEAL, 0.6))
	g.label("ROLL" if play.phase == "roll" else "SCREEN", target + Vector2(-16, 23), 8, g.TEAL)
