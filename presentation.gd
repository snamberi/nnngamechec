extends RefCounted
## Traditional gym and broadcast presentation, drawn at 640 x 360.
const NAVY = Color("243951")
const RED = Color("853e43")
const CREAM = Color("f5efdf")
const GOLD = Color("c59d56")
const MUTED = Color("8a938f")

static func text(g, value: String, x: float, y: float, size: int = 12, color: Color = CREAM) -> void:
	g.label(value, Vector2(x, y), size, color)

static func panel(g, box: Rect2, color: Color) -> void:
	g.draw_rect(box, color)

static func arena(g) -> void:
	panel(g, Rect2(0, 0, 640, 360), Color("242a2b"))
	# Bleachers, concrete walkways, warm house lights, and spectators.
	for row in range(2):
		panel(g, Rect2(7, 59 + row * 13, 626, 12), Color("3a4040") if row == 0 else Color("444643"))
		for col in range(39):
			var x = 13 + col * 16
			var y = 67 + row * 12
			var lift = -2 if g.crowd_energy > 0.3 and (col + row) % 3 != 0 and sin(g.elapsed * 10 + col) > 0 else 0
			var shirt: Color = [Color("757b76"), Color("586e7b"), Color("8c6f62"), Color("9a947f"), Color("5b605f")][(col * 7 + row) % 5]
			panel(g, Rect2(x, y - 4 + lift, 7, 7), shirt)
			panel(g, Rect2(x + 1, y - 9 + lift, 5, 5), Color("b89371") if col % 2 else Color("806049"))
			panel(g, Rect2(x, y + 3, 3, 2), Color("272f35"))
			panel(g, Rect2(x + 4, y + 3, 3, 2), Color("272f35"))
			if g.crowd_energy > 0.4 and col % 4 == 0:
				panel(g, Rect2(x - 2, y - 10, 2, 8), shirt)
				panel(g, Rect2(x + 7, y - 10, 2, 8), shirt)
	panel(g, Rect2(32, 85, 576, 232), Color("1c2e43"))
	panel(g, Rect2(40, 88, 560, 224), Color("e3d0a6"))
	# Long maple boards, staggered joins, subtle grain and varnish.
	for row in range(22):
		var y = 91 + row * 10
		var shade: Color = [Color("d9b77b"), Color("dfbe86"), Color("e4c48e"), Color("dcb982")][(row * 7) % 4]
		panel(g, Rect2(44, y, 552, minf(10, 309 - y)), shade)
		g.draw_line(Vector2(44, y), Vector2(596, y), Color("c7a56e"))
		for col in range(6):
			var x = 44 + col * 105 + (48 if row % 2 else 0)
			if x < 596:
				g.draw_line(Vector2(x, y), Vector2(x, minf(y + 10, 309)), Color("c8a66e"))
			var gx = clampf(x + 13, 44, 596)
			g.draw_line(Vector2(gx, y + 4), Vector2(minf(gx + 52, 596), y + 4), Color(shade.darkened(0.035)))
	panel(g, Rect2(44, 151, 100, 98), Color("3d5060"))
	panel(g, Rect2(496, 151, 100, 98), Color("844e4b"))
	var line = Color("faf1d9")
	g.draw_rect(g.COURT, line, false, 1)
	g.draw_rect(Rect2(44, 151, 100, 98), line, false, 1)
	g.draw_rect(Rect2(496, 151, 100, 98), line, false, 1)
	g.draw_line(Vector2(320, 91), Vector2(320, 309), line)
	g.draw_circle(Vector2(320, 200), 34, Color("d1ac70"))
	g.draw_arc(Vector2(320, 200), 36, 0, TAU, 64, line, 1)
	g.draw_arc(Vector2(320, 200), 28, 0, TAU, 64, NAVY, 2)
	text(g, "C", 304, 213, 36, NAVY)
	text(g, "HARBOR FIELDHOUSE", 260, 245, 8, Color("987b50"))
	var angle = asin(109.0 / 160.0)
	g.draw_arc(g.LEFT, 160, -angle, angle, 64, line)
	g.draw_arc(g.RIGHT, 160, PI - angle, PI + angle, 64, line)
	g.draw_arc(Vector2(144, 200), 34, -PI / 2, PI / 2, 32, line)
	g.draw_arc(Vector2(496, 200), 34, PI / 2, PI * 1.5, 32, line)
	for key_x in [122, 514]:
		for lane_y in [142, 253]:
			g.draw_line(Vector2(key_x, lane_y), Vector2(key_x + 9, lane_y), line, 2)
	# Backboard supports and glass; rim and net remain on gameplay target.
	for hoop in [g.LEFT, g.RIGHT]:
		var outward = -1 if hoop.x < 320 else 1
		var bx: float = hoop.x + outward * 11
		g.draw_line(Vector2(bx + outward * 9, 203), Vector2(bx, 183), Color("19262d"), 4)
		panel(g, Rect2(bx - 2, 175, 4, 39), Color("e6e1cd"))
		panel(g, Rect2(bx - 1, 178, 2, 32), Color("9baaa3"))
		for strand in range(4):
			var yy = hoop.y + strand * 2
			g.draw_line(Vector2(hoop.x - 6 + strand, yy), Vector2(hoop.x + 6 - strand, yy), Color("e2ded0"))
		g.draw_arc(hoop, 6, 0, TAU, 20, Color("a8542f"), 2)
		g.draw_line(hoop + Vector2(-4, -3), hoop + Vector2(4, -3), Color("ecac61"), 1)
	# Team benches and towels outside baselines.
	for side in range(2):
		var x = 12 if side == 0 else 616
		for seat in range(4):
			var y = 144 + seat * 30
			panel(g, Rect2(x - 5, y, 15, 12), Color("686b64"))
			panel(g, Rect2(x - 2, y - 4, 9, 9), CREAM if side == 0 else RED)
			panel(g, Rect2(x, y - 10, 5, 6), Color("a47d5b"))
			panel(g, Rect2(x - 2, y + 5, 3, 7), NAVY)
			panel(g, Rect2(x + 4, y + 5, 3, 7), NAVY)
	text(g, "HARBOR  /  HOME", 48, 328, 9, Color("b5bec0"))
	text(g, "SUMMIT  /  AWAY", 505, 328, 9, Color("b5bec0"))
	var official_x: float = clampf(g.ball.x * 0.35 + 210, 275, 365)
	panel(g, Rect2(official_x - 4, 318, 8, 8), CREAM)
	for stripe in [-3, 0, 3]:
		panel(g, Rect2(official_x + stripe, 318, 1, 8), NAVY)
	panel(g, Rect2(official_x - 3, 312, 6, 6), Color("bc9875"))
	panel(g, Rect2(official_x - 4, 326, 3, 5), Color("212a31"))
	panel(g, Rect2(official_x + 1, 326, 3, 5), Color("212a31"))

static func hud(g) -> void:
	panel(g, Rect2(0, 0, 640, 55), CREAM)
	panel(g, Rect2(0, 53, 640, 2), Color("b9ad93"))
	text(g, "COURTSIDE", 15, 23, 17, NAVY)
	text(g, "BASKETBALL  /  EXHIBITION", 16, 41, 8, Color("6e786f"))
	panel(g, Rect2(174, 7, 95, 42), NAVY)
	panel(g, Rect2(374, 7, 95, 42), RED)
	text(g, "HARBOR", 183, 23, 10)
	text(g, "%02d" % g.scores[0], 234, 41, 22)
	text(g, "SUMMIT", 384, 23, 10)
	text(g, "%02d" % g.scores[1], 433, 41, 22)
	var display_seconds = int(ceil(g.clock_time))
	g.centered("%d:%02d" % [display_seconds / 60, display_seconds % 60], 28, 23, NAVY)
	g.centered("Q%d   /   %02d" % [g.quarter, int(ceil(maxf(0, g.shot_clock)))], 45, 10, RED if g.shot_clock < 5 else NAVY)
	text(g, g.STYLES[g.style], 495, 24, 10, NAVY)
	text(g, "H HELP  TAB STATS  M " + ("MUTED" if g.muted else "SOUND"), 495, 41, 8, Color("6e786f"))
	if g.message_time > 0:
		var w: float = maxf(210, g.font.get_string_size(g.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 24)
		panel(g, Rect2((640 - w) / 2, 59, w, 20), CREAM)
		g.centered(g.message, 73, 10, NAVY)
	panel(g, Rect2(0, 338, 640, 22), CREAM)
	g.centered("WASD MOVE   SPACE SHOOT   E PASS   Z / X / C HANDLES   R SCREEN   H PLAYBOOK", 352, 9, NAVY)
	if "shot_feedback" in g and not g.shot_feedback.is_empty() and g.shot_feedback.get("time", 0) > 0:
		var fb: Dictionary = g.shot_feedback
		panel(g, Rect2(225, 312, 190, 22), NAVY)
		g.centered(fb.get("quality", "") + "  /  " + str(int(fb.get("contest", 0) * 100)) + "% CONTEST", 326, 9, CREAM)

static func title(g) -> void:
	panel(g, Rect2(0, 0, 640, 360), NAVY)
	g.draw_arc(Vector2(640, 230), 154, PI / 2, PI * 1.5, 64, Color("344b60"), 1)
	g.draw_rect(Rect2(552, 155, 88, 142), Color("344b60"), false, 1)
	panel(g, Rect2(0, 0, 313, 360), CREAM)
	panel(g, Rect2(28, 35, 38, 4), RED)
	text(g, "THE GAME. THE GYM. THE MOMENT.", 28, 62, 9, Color("6a726b"))
	text(g, "COURT", 23, 121, 58, NAVY)
	text(g, "SIDE", 23, 176, 58, NAVY)
	text(g, "B A S K E T B A L L", 28, 203, 14, RED)
	text(g, "Find the lane. Make the extra pass.", 28, 235, 11, Color("626b64"))
	panel(g, Rect2(28, 258, 257, 38), NAVY)
	text(g, "ENTER   PLAY EXHIBITION", 46, 283, 14)
	text(g, "T   OPPONENT: " + g.STYLES[g.style], 28, 321, 11, NAVY)
	text(g, "3 ON 3   /   FOUR QUARTERS   /   V0.3", 28, 343, 8, Color("7c8076"))
	text(g, "HARBOR FIELDHOUSE", 342, 36, 13)
	text(g, "HOME", 343, 59, 9, GOLD)
	text(g, "HARBOR", 343, 83, 22)
	text(g, "VS", 569, 83, 12, GOLD)
	text(g, "SUMMIT", 343, 109, 14, Color("d5b4a8"))
	g.SpriteAtlas.preview(g, Rect2(329, 120, 181, 183), 0, 0, 0)
	g.SpriteAtlas.preview(g, Rect2(472, 164, 142, 139), 1, 7, 1)
	text(g, "EXHIBITION / LOCAL SINGLE PLAYER", 342, 324, 9)
	text(g, "Press H in game for the full playbook.", 342, 344, 10, Color("bdc4be"))

static func overlay(g) -> void:
	panel(g, Rect2(0, 0, 640, 360), Color(0.06, 0.08, 0.1, 0.83))
	panel(g, Rect2(133, 100, 374, 160), CREAM)
	g.centered("TIMEOUT" if g.paused else ("HARBOR WINS" if g.scores[0] > g.scores[1] else "SUMMIT WINS"), 143, 30, NAVY)
	g.centered("%02d   —   %02d" % [g.scores[0], g.scores[1]], 184, 30, RED)
	g.centered("ESC  RESUME   /   H  PLAYBOOK" if g.paused else "ENTER  REMATCH    /    T  OPPONENT", 232, 11, NAVY)
	if not g.paused:
		panel(g, Rect2(133, 262, 374, 58), NAVY)
		var home: Dictionary = g.team_stats[0]
		var away: Dictionary = g.team_stats[1]
		g.centered("FG %d/%d  ·  REB %d  ·  AST %d   |   FG %d/%d  ·  REB %d  ·  AST %d" % [home.fgm, home.fga, home.rebounds, home.assists, away.fgm, away.fga, away.rebounds, away.assists], 284, 10)
		g.centered("HARBOR                          SUMMIT", 305, 9, Color("bcc4c0"))

static func help(g) -> void:
	panel(g, Rect2(20, 23, 600, 312), CREAM)
	panel(g, Rect2(20, 23, 600, 5), RED)
	text(g, "THE PLAYBOOK", 42, 63, 26, NAVY)
	var left = ["WASD / ARROWS   Move", "SHIFT   Sprint / dunk near rim", "SPACE   Hold, release in green", "Tap SPACE / V   Pump fake", "E   Directional pass / switch", "Q   Steal / block"]
	var right = ["Z Cross   X Spin   C Step back", "R   Call pick-and-roll", "F   Pass and cut to basket", "Away + close shot = reverse", "Sprint + side = tomahawk", "Sprint + forward = two-hand"]
	for i in range(left.size()):
		text(g, left[i], 43, 96 + i * 22, 11, NAVY)
		text(g, right[i], 333, 96 + i * 22, 11, NAVY)
	text(g, "Stop before shooting. Change pace. Use the screen, then feed the roll.", 43, 253, 11, RED)
	text(g, "Moves cost stamina.  TAB  Box score.  M  Toggle sound.", 43, 275, 10, Color("687066"))
	g.centered("H / ESC   RETURN TO THE COURT", 316, 11, NAVY)

static func box_score(g) -> void:
	panel(g, Rect2(40, 24, 560, 308), CREAM)
	panel(g, Rect2(40, 24, 560, 5), RED)
	text(g, "BOX SCORE", 62, 66, 25, NAVY)
	text(g, "HARBOR", 365, 65, 13, NAVY)
	text(g, "SUMMIT", 485, 65, 13, RED)
	var fields = ["SCORE", "FIELD GOALS", "THREE POINTERS", "REBOUNDS", "ASSISTS", "STEALS", "BLOCKS"]
	var home: Dictionary = g.team_stats[0]
	var away: Dictionary = g.team_stats[1]
	var home_values = [str(g.scores[0]), "%d / %d" % [home.fgm, home.fga], "%d / %d" % [home.three_made, home.three_attempts], str(home.rebounds), str(home.assists), str(home.steals), str(home.blocks)]
	var away_values = [str(g.scores[1]), "%d / %d" % [away.fgm, away.fga], "%d / %d" % [away.three_made, away.three_attempts], str(away.rebounds), str(away.assists), str(away.steals), str(away.blocks)]
	for i in range(fields.size()):
		var y = 101 + i * 26
		if i % 2 == 0:
			panel(g, Rect2(58, y - 16, 524, 25), Color("e7e1d1"))
		text(g, fields[i], 68, y, 11, NAVY)
		text(g, home_values[i], 383, y, 13, NAVY)
		text(g, away_values[i], 503, y, 13, RED)
	g.centered("TAB / ESC   RETURN TO THE COURT", 312, 10, NAVY)
