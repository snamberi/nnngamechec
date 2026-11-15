extends Node2D
## Original, asset-free 3v3 basketball. Court coordinates are gameplay coordinates.

const INK = Color("0c1528")
const WHITE = Color("f4e7cb")
const TEAL = Color("56f4cf")
const PINK = Color("ff6488")
const GOLD = Color("ffc766")
const COURT = Rect2(44, 91, 552, 218)
const LEFT = Vector2(68, 200)
const RIGHT = Vector2(572, 200)
const QUARTER_SECONDS = 90.0
var font: Font = ThemeDB.fallback_font
var players: Array[Dictionary] = []
var controlled = 0
var carrier = 0
var possession = 0
var scores = [0, 0]
var quarter = 1
var clock_time = QUARTER_SECONDS
var shot_clock = 24.0
var mode = "title"
var paused = false
var charge = -1.0
var ball = Vector2.ZERO
var flight: Dictionary = {}
var loose = false
var pickup_delay = 0.0
var cooldown = 0.0
var ai_clock = 0.0
var elapsed = 0.0
var message = ""
var message_time = 0.0
var particles: Array[Dictionary] = []
var rng = RandomNumberGenerator.new()
var audio: AudioStreamPlayer

func _ready() -> void:
	rng.randomize()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	reset_positions(0)

func reset_positions(team: int) -> void:
	players.clear()
	for i in range(6):
		var side = i / 3
		var lane = i % 3
		var x = 235.0 if side == 0 else 405.0
		players.append({"pos": Vector2(x + (16 if lane == 0 else -16), 145 + lane * 54), "team": side, "stamina": 1.0, "step": 0.0, "jump": 0.0})
	carrier = team * 3 + 1
	controlled = 1
	possession = team
	ball = players[carrier].pos
	flight.clear()
	loose = false
	charge = -1.0
	shot_clock = 24.0
	ai_clock = 0.0

func start_game() -> void:
	scores = [0, 0]
	quarter = 1
	clock_time = QUARTER_SECONDS
	mode = "play"
	paused = false
	reset_positions(0)
	announce("TIP OFF • YOU ATTACK RIGHT", 2.5)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key = event.physical_keycode
	if event.pressed and key == KEY_ENTER:
		if mode != "play":
			start_game()
		return
	if mode != "play":
		return
	if event.pressed and key == KEY_ESCAPE:
		paused = not paused
		charge = -1.0
	if paused:
		return
	if key == KEY_SPACE:
		if event.pressed and carrier == controlled and flight.is_empty():
			charge = 0.0
		elif not event.pressed and charge >= 0.0:
			shoot(controlled, clampf(1.0 - absf(charge - 0.7) / 0.7, 0.0, 1.0))
			charge = -1.0
	if event.pressed and key == KEY_E:
		if carrier == controlled:
			pass_ball()
		else:
			var nearest = 0
			for i in range(3):
				if players[i].pos.distance_to(ball) < players[nearest].pos.distance_to(ball):
					nearest = i
			controlled = (controlled + 1) % 3 if nearest == controlled else nearest
	if event.pressed and key == KEY_Q and cooldown <= 0.0:
		defend()

func movement() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()

func _process(delta: float) -> void:
	elapsed += delta
	if mode == "play" and not paused:
		tick(delta)
	queue_redraw()

func tick(dt: float) -> void:
	message_time = maxf(0, message_time - dt)
	cooldown = maxf(0, cooldown - dt)
	pickup_delay = maxf(0, pickup_delay - dt)
	clock_time = maxf(0, clock_time - dt)
	if flight.is_empty() and not loose:
		shot_clock -= dt
		if shot_clock <= 0:
			reset_positions(1 - possession)
			announce("SHOT CLOCK • TURNOVER")
	if charge >= 0:
		charge = minf(charge + dt, 1.4)
	for i in range(6):
		players[i].jump = maxf(0, players[i].jump - dt * 2)
		if i == controlled:
			var sprint = Input.is_physical_key_pressed(KEY_SHIFT) and players[i].stamina > 0.04 and movement().length() > 0
			players[i].stamina = clampf(players[i].stamina + (-0.25 if sprint else 0.15) * dt, 0, 1)
			var speed = 100.0 if sprint else 70.0
			if charge >= 0:
				speed *= 0.3
			move_player(i, movement() * speed * dt)
		else:
			update_ai(i, dt)
	# Body separation prevents running straight through a defender.
	for i in range(6):
		for j in range(i + 1, 6):
			var offset: Vector2 = players[i].pos - players[j].pos
			if offset.length() < 13 and offset.length() > 0.01:
				var push = offset.normalized() * (13 - offset.length()) * 0.5
				move_player(i, push)
				move_player(j, -push)
	if not flight.is_empty():
		update_flight(dt)
	elif carrier >= 0:
		ball = players[carrier].pos + Vector2(8, -4 + absf(sin(elapsed * 13)) * 5)
	elif loose and pickup_delay <= 0:
		for i in range(6):
			if players[i].pos.distance_to(ball) < 17:
				var old_possession = possession
				carrier = i
				possession = players[i].team
				shot_clock = 14.0 if old_possession == possession else 24.0
				loose = false
				if possession == 0:
					controlled = i
				announce("REBOUND")
				break
	if carrier >= 3 and flight.is_empty():
		ai_clock += dt
		if (players[carrier].pos.distance_to(LEFT) < 115 and ai_clock > 1.6) or shot_clock < 2:
			shoot(carrier, rng.randf_range(0.65, 0.98))
			ai_clock = 0
	for p in particles:
		p.pos += p.vel * dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	# Let a shot released before the buzzer finish.
	if clock_time <= 0 and flight.is_empty():
		if quarter < 4:
			quarter += 1
			clock_time = QUARTER_SECONDS
			reset_positions(quarter % 2)
			announce("QUARTER %d" % quarter)
		elif scores[0] == scores[1]:
			clock_time = 45.0
			reset_positions(1 - possession)
			announce("OVERTIME • 45 SECONDS")
		else:
			mode = "final"
			tone(220, 0.3)

func move_player(i: int, offset: Vector2) -> void:
	players[i].pos += offset
	players[i].pos.x = clampf(players[i].pos.x, 51, 589)
	players[i].pos.y = clampf(players[i].pos.y, 100, 301)
	players[i].step += offset.length() * 0.3

func update_ai(i: int, dt: float) -> void:
	var target: Vector2
	var team: int = players[i].team
	var hoop = RIGHT if team == 0 else LEFT
	if loose:
		target = ball
	elif not flight.is_empty() and flight.kind == "shot":
		target = flight.target + Vector2((i % 3 - 1) * 19, (i % 2 * 2 - 1) * 22)
	elif i == carrier:
		target = hoop + Vector2(68 if team == 1 else -68, sin(elapsed * 1.2) * 43)
	elif possession == team:
		var advance = clampf(ball.x + (50 if team == 0 else -50), 130, 510)
		target = Vector2(advance - (i % 3) * 24, 125 + (i % 3) * 73)
	else:
		var opponent = (i + 3) % 6
		target = players[opponent].pos.lerp(LEFT if team == 0 else RIGHT, 0.18)
		if carrier == opponent:
			target = players[opponent].pos + Vector2(-15 if team == 0 else 15, 0)
	var offset = target - Vector2(players[i].pos)
	if offset.length() > 4:
		move_player(i, offset.normalized() * minf(offset.length(), (57 if i == carrier else 65) * dt))

func contest_at(i: int) -> float:
	var pressure = 0.0
	for j in range(6):
		if players[j].team != players[i].team:
			pressure = maxf(pressure, clampf(1.0 - players[j].pos.distance_to(players[i].pos) / 48.0, 0, 1))
	return pressure

func shoot(i: int, timing: float) -> void:
	if carrier != i or not flight.is_empty():
		return
	var team: int = players[i].team
	var hoop = RIGHT if team == 0 else LEFT
	var distance: float = players[i].pos.distance_to(hoop)
	var pressure = contest_at(i)
	var perfect = timing > 0.93
	var probability = clampf(0.3 + timing * 0.63 - distance / 850.0 - pressure * 0.39, 0.08, 0.97)
	if perfect and pressure < 0.35 and distance < 245:
		probability = 1.0
	var dunk = distance < 42 and players[i].stamina > 0.2
	if dunk:
		probability = 0.96 - pressure * 0.2
	players[i].jump = 1.0
	flight = {"kind": "shot", "start": Vector2(players[i].pos) - Vector2(0, 16), "target": hoop, "t": 0.0, "duration": 0.48 if dunk else 0.85, "team": team, "points": 3 if distance > 160 else 2, "made": rng.randf() < probability, "green": perfect}
	carrier = -1
	charge = -1.0
	if team == 0:
		announce("SLAM!" if dunk else ("PERFECT RELEASE" if perfect else ("EARLY / LATE" if timing < 0.65 else "GOOD RELEASE")), 1.2)
	tone(650 if perfect else 380, 0.06)

func pass_ball() -> void:
	var aim = movement()
	var best = -1
	var best_value = -INF
	for i in range(3):
		if i == carrier:
			continue
		var offset: Vector2 = players[i].pos - players[carrier].pos
		var value = aim.dot(offset.normalized()) * 100 if aim.length() > 0 else -contest_at(i) * 50 + players[i].pos.x * 0.1
		if value > best_value:
			best_value = value
			best = i
	flight = {"kind": "pass", "start": ball, "target": Vector2(players[best].pos), "receiver": best, "t": 0.0, "duration": 0.3}
	carrier = -1
	charge = -1.0
	tone(270, 0.05)

func update_flight(dt: float) -> void:
	flight.t += dt / flight.duration
	var t: float = minf(flight.t, 1)
	if flight.kind == "pass":
		flight.target = players[flight.receiver].pos
	ball = Vector2(flight.start).lerp(flight.target, t)
	if t < 1:
		return
	var done = flight.duplicate()
	flight.clear()
	if done.kind == "pass":
		carrier = done.receiver
		controlled = carrier
		return
	if done.made:
		scores[done.team] += done.points
		burst(done.target, TEAL if done.team == 0 else PINK)
		tone(880, 0.12)
		reset_positions(1 - int(done.team))
		announce(("NIGHT OWLS" if done.team == 0 else "SUNSET CLUB") + "  +%d" % done.points)
	else:
		ball = Vector2(done.target) + Vector2(rng.randf_range(20, 65) * (-1 if done.team == 0 else 1), rng.randf_range(-45, 45))
		loose = true
		pickup_delay = 0.25
		announce("OFF THE RIM • GET THE BOARD", 1.2)
		tone(140, 0.08)

func defend() -> void:
	cooldown = 0.9
	players[controlled].jump = 1.0
	if carrier >= 3 and players[controlled].pos.distance_to(players[carrier].pos) < 30:
		if rng.randf() < 0.62:
			carrier = controlled
			possession = 0
			shot_clock = 24
			ai_clock = 0
			announce("PICKPOCKET!")
		else:
			announce("REACH MISSED", 0.7)
	elif not flight.is_empty() and flight.kind == "shot" and flight.team == 1 and flight.t < 0.38 and players[controlled].pos.distance_to(flight.start) < 40:
		flight.made = false
		announce("BLOCKED!")
		tone(110, 0.1)

func announce(text: String, duration: float = 1.8) -> void:
	message = text
	message_time = duration

func burst(pos: Vector2, color: Color) -> void:
	for i in range(20):
		particles.append({"pos": pos, "vel": Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, 25)), "life": rng.randf_range(0.4, 1.0), "color": color})

func tone(hz: float, duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 22050
	var data = PackedByteArray()
	var count = int(duration * 22050)
	data.resize(count)
	for i in range(count):
		var sample = sin(TAU * hz * i / 22050.0) * 23 * (1.0 - float(i) / count)
		data[i] = int(sample) & 255
	sound.data = data
	audio.stream = sound
	audio.play()

func label(text: String, pos: Vector2, size: int = 12, color: Color = WHITE) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(text: String, y: float, size: int = 12, color: Color = WHITE) -> void:
	label(text, Vector2((640 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func _draw() -> void:
	draw_arena()
	var order = range(6)
	order.sort_custom(func(a, b): return players[a].pos.y < players[b].pos.y)
	for i in order:
		draw_player(i)
	draw_ball()
	for p in particles:
		draw_rect(Rect2(p.pos, Vector2(3, 3)), p.color)
	draw_hud()
	if mode == "title":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.025, 0.04, 0.08, 0.88))
		label("NC / 01", Vector2(38, 41), 14, TEAL)
		label("AFTER HOURS BASKETBALL", Vector2(38, 67), 10, GOLD)
		label("NEON", Vector2(35, 133), 64, WHITE)
		label("COURT", Vector2(35, 191), 64, TEAL)
		label("3 ON 3.  ALL HEART.", Vector2(40, 218), 14, WHITE)
		draw_rect(Rect2(40, 243, 228, 36), TEAL)
		label("ENTER  /  HIT THE COURT", Vector2(54, 267), 14, INK)
		label("WASD / ARROWS    Move", Vector2(355, 126), 12)
		label("SHIFT    Sprint", Vector2(355, 152), 12)
		label("SPACE    Hold & release shot", Vector2(355, 178), 12)
		label("E    Pass / switch player", Vector2(355, 204), 12)
		label("Q    Steal / block", Vector2(355, 230), 12)
		label("Release in the green zone.", Vector2(355, 267), 11, TEAL)
		label("Find space. Feed your team.", Vector2(355, 284), 11, WHITE)
		label("ORIGINAL TEAMS  /  FOUR 90-SECOND QUARTERS", Vector2(40, 330), 10, Color("7c8ca4"))
	elif paused or mode == "final":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.07, 0.86))
		centered("PAUSED" if paused else ("OWLS WIN" if scores[0] > scores[1] else "SUNSET WINS"), 160, 38, TEAL)
		centered("ESC  /  BACK TO THE COURT" if paused else "%d  —  %d     |     ENTER TO REMATCH" % [scores[0], scores[1]], 204, 14)

func draw_arena() -> void:
	draw_rect(Rect2(0, 0, 640, 360), INK)
	for row in range(2):
		for col in range(38):
			var x = 20 + col * 16
			var y = 66 + row * 10
			draw_rect(Rect2(x, y, 9, 6), Color("29364e") if (col + row) % 3 else Color("56516a"))
	draw_rect(Rect2(38, 85, 564, 230), TEAL)
	draw_rect(Rect2(41, 88, 558, 224), INK)
	draw_rect(COURT, Color("b47c53"))
	for x in range(44, 596, 23):
		draw_rect(Rect2(x, 91, 22, 218), Color("c18a5c") if x % 2 == 0 else Color("b98155"))
		for y in range(91, 309, 36):
			var seam_y = y + (18 if x % 2 else 0)
			if seam_y < 309:
				draw_line(Vector2(x, seam_y), Vector2(x + 22, seam_y), Color("ad764f"))
	draw_rect(Rect2(44, 151, 100, 98), Color("244d55"))
	draw_rect(Rect2(496, 151, 100, 98), Color("5d394d"))
	draw_rect(Rect2(44, 151, 100, 98), WHITE, false, 1)
	draw_rect(Rect2(496, 151, 100, 98), WHITE, false, 1)
	draw_line(Vector2(320, 91), Vector2(320, 309), WHITE)
	draw_arc(Vector2(320, 200), 40, 0, TAU, 64, WHITE)
	draw_circle(Vector2(320, 200), 29, Color("a66d4c"))
	label("NC", Vector2(299, 209), 25, WHITE)
	var arc_angle = asin(109.0 / 160.0)
	draw_arc(Vector2(68, 200), 160, -arc_angle, arc_angle, 48, WHITE)
	draw_arc(Vector2(572, 200), 160, PI - arc_angle, PI + arc_angle, 48, WHITE)
	draw_arc(Vector2(144, 200), 34, -PI / 2, PI / 2, 32, WHITE)
	draw_arc(Vector2(496, 200), 34, PI / 2, PI * 1.5, 32, WHITE)
	for hoop in [LEFT, RIGHT]:
		var back = -10 if hoop == LEFT else 10
		draw_line(hoop + Vector2(back, -20), hoop + Vector2(back, 20), INK, 5)
		draw_line(hoop + Vector2(back, -18), hoop + Vector2(back, 18), WHITE, 3)
		draw_circle(hoop, 8, INK)
		draw_arc(hoop, 6, 0, TAU, 16, Color("ff894c"), 2)
		for dy in range(-3, 5, 3):
			draw_line(hoop + Vector2(-4, dy), hoop + Vector2(4, dy), WHITE, 1)
	label("NIGHT OWLS  >>>", Vector2(65, 328), 10, TEAL)
	label("<<<  SUNSET CLUB", Vector2(471, 328), 10, PINK)

func draw_player(i: int) -> void:
	var p: Vector2 = players[i].pos.round()
	var jump: float = sin(players[i].jump * PI) * 13
	var color = TEAL if i < 3 else PINK
	draw_set_transform(p)
	draw_rect(Rect2(-7, -1, 15, 4), Color(0.05, 0.07, 0.12, 0.35))
	if i == controlled:
		draw_arc(Vector2.ZERO, 11, 0, TAU, 20, TEAL, 1)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -35), Vector2(4, -35), Vector2(0, -30)]), TEAL)
	p.y -= jump
	draw_set_transform(p)
	var step = roundf(sin(players[i].step) * 2)
	draw_rect(Rect2(-6, -8, 5, 7 + step), INK)
	draw_rect(Rect2(2, -8, 5, 7 - step), INK)
	draw_rect(Rect2(-7, -2 + step, 6, 3), WHITE)
	draw_rect(Rect2(2, -2 - step, 6, 3), WHITE)
	draw_rect(Rect2(-7, -21, 14, 14), INK)
	draw_rect(Rect2(-6, -20, 12, 11), color)
	var skin = [Color("bb7850"), Color("e1ac79"), Color("744c3a")][i % 3]
	draw_rect(Rect2(-10, -18, 4, 10), skin)
	draw_rect(Rect2(7, -18, 4, 10), skin)
	draw_rect(Rect2(-5, -29, 10, 9), skin)
	draw_rect(Rect2(-5, -30, 10, 3), INK)
	draw_rect(Rect2(-5, -26, 10, 2), color)
	label(str(i % 3 + 1), Vector2(-3, -11), 8, INK)
	draw_set_transform(Vector2.ZERO)
	if i == controlled:
		draw_rect(Rect2(p.x - 11, p.y + 7, 22, 2), INK)
		draw_rect(Rect2(p.x - 11, p.y + 7, 22 * players[i].stamina, 2), TEAL)

func draw_ball() -> void:
	var height = 0.0
	if not flight.is_empty():
		height = sin(minf(1, flight.t) * PI) * (56 if flight.kind == "shot" else 10)
	draw_circle(ball, 3, Color(0.05, 0.06, 0.1, 0.3))
	var p = (ball - Vector2(0, height)).round()
	draw_circle(p, 5, INK)
	draw_circle(p, 4, Color("f79645"))
	draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color("7d412d"))
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color("7d412d"))
	if charge >= 0:
		var origin: Vector2 = players[controlled].pos + Vector2(-21, -44)
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(46, 9)), INK)
		draw_rect(Rect2(origin, Vector2(42, 5)), Color("895465"))
		draw_rect(Rect2(origin + Vector2(19, 0), Vector2(5, 5)), TEAL)
		draw_rect(Rect2(origin + Vector2(charge / 1.4 * 42, -2), Vector2(2, 9)), WHITE)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, 640, 55), Color("111e33"))
	label("NEON / COURT", Vector2(16, 22), 12, TEAL)
	label("3v3  •  AFTER HOURS", Vector2(16, 41), 9, Color("7c8ca4"))
	label("OWLS", Vector2(190, 20), 10, TEAL)
	label("%02d" % scores[0], Vector2(190, 44), 25)
	label("SUNSET", Vector2(391, 20), 10, PINK)
	label("%02d" % scores[1], Vector2(395, 44), 25)
	centered("%d:%02d" % [int(ceil(clock_time)) / 60, int(ceil(clock_time)) % 60], 29, 22)
	centered("Q%d  /  SHOT %02d" % [quarter, int(ceil(maxf(0, shot_clock)))], 45, 10, GOLD)
	label("HOME  /  YOU", Vector2(534, 23), 10, TEAL)
	label("ESC  PAUSE", Vector2(534, 41), 9, Color("7c8ca4"))
	if message_time > 0:
		draw_rect(Rect2(165, 60, 310, 19), INK)
		centered(message, 73, 10, GOLD)
	centered("WASD MOVE     SHIFT SPRINT     SPACE SHOT     E PASS / SWITCH     Q DEFEND", 350, 9, Color("9daac0"))
