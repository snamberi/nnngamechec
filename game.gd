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
const Tactics = preload("res://tactics.gd")
const PixelArt = preload("res://pixel_art.gd")
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
var play_call: Dictionary = {}
var cuts: Dictionary = {}
var assignments: Dictionary = {}
var transition_time = 0.0
var style = 0
var help_visible = false
var crowd_energy = 0.0
var last_finish = ""
var match_stats = {"ai_passes": 0, "screens": 0, "interceptions": 0}
const STYLES = ["BALANCED", "PRESSURE", "PERIMETER"]

func _ready() -> void:
	rng.randomize()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	reset_positions(0)

func reset_positions(team: int) -> void:
	var stamina = players.map(func(p): return p.stamina)
	players.clear()
	for i in range(6):
		var side = i / 3
		var lane = i % 3
		var x = 235.0 if side == 0 else 405.0
		players.append({"pos": Vector2(x + (16 if lane == 0 else -16), 145 + lane * 54), "team": side, "stamina": minf(1.0, stamina[i] + 0.12) if stamina.size() == 6 else 1.0, "step": 0.0, "jump": 0.0, "velocity": Vector2.ZERO, "facing": Vector2.RIGHT if side == 0 else Vector2.LEFT, "hand": 1.0, "action": "idle", "action_time": 0.0, "move_cd": 0.0, "stun": 0.0, "burst": Vector2.ZERO, "trail": [], "steal_cd": 1.0})
	carrier = team * 3 + 1
	controlled = 1
	possession = team
	ball = players[carrier].pos
	flight.clear()
	loose = false
	charge = -1.0
	shot_clock = 24.0
	ai_clock = 0.0
	play_call.clear()
	cuts.clear()
	assignments.clear()
	transition_time = 0

func start_game() -> void:
	scores = [0, 0]
	quarter = 1
	clock_time = QUARTER_SECONDS
	mode = "play"
	paused = false
	help_visible = false
	players.clear()
	particles.clear()
	match_stats = {"ai_passes": 0, "screens": 0, "interceptions": 0}
	reset_positions(0)
	announce("TIP OFF • YOU ATTACK RIGHT", 2.5)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key = event.physical_keycode
	if event.pressed and key == KEY_T and mode != "play":
		style = (style + 1) % STYLES.size()
		return
	if event.pressed and key == KEY_ENTER:
		if mode != "play":
			start_game()
		return
	if mode != "play":
		return
	if event.pressed and key == KEY_ESCAPE:
		paused = not paused
		help_visible = false
		charge = -1.0
	if event.pressed and key == KEY_H:
		help_visible = not help_visible
		paused = help_visible
		charge = -1.0
	if paused:
		return
	if key == KEY_SPACE:
		if event.pressed and carrier == controlled and flight.is_empty():
			charge = 0.0
		elif not event.pressed and charge >= 0.0:
			if charge < 0.16:
				perform_move("fake")
			else:
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
	if event.pressed:
		match key:
			KEY_Z: perform_move("cross")
			KEY_X: perform_move("spin")
			KEY_C: perform_move("stepback")
			KEY_V: perform_move("fake")
			KEY_R: Tactics.call_screen(self)
			KEY_F:
				if carrier == controlled:
					pass_ball(true)

func movement() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()

func _process(_delta: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if mode == "play" and not paused:
		tick(delta)

func tick(dt: float) -> void:
	if mode != "play" or paused:
		return
	elapsed += dt
	crowd_energy = maxf(0, crowd_energy - dt * 0.45)
	transition_time = maxf(0, transition_time - dt)
	message_time = maxf(0, message_time - dt)
	cooldown = maxf(0, cooldown - dt)
	pickup_delay = maxf(0, pickup_delay - dt)
	clock_time = maxf(0, clock_time - dt)
	if flight.is_empty() or flight.get("kind", "") == "pass":
		shot_clock -= dt
		if shot_clock <= 0:
			reset_positions(1 - possession)
			announce("SHOT CLOCK • TURNOVER")
	if charge >= 0:
		charge = minf(charge + dt, 1.4)
	Tactics.tick(self, dt)
	for i in range(6):
		players[i].jump = maxf(0, players[i].jump - dt * 2)
		players[i].move_cd = maxf(0, players[i].move_cd - dt)
		players[i].stun = maxf(0, players[i].stun - dt)
		players[i].steal_cd = maxf(0, players[i].steal_cd - dt)
		players[i].action_time = maxf(0, players[i].action_time - dt)
		if players[i].action_time <= 0:
			players[i].action = "idle"
		if players[i].action_time > 0 and players[i].action in ["cross", "spin", "stepback"]:
			move_player(i, players[i].burst * dt)
			players[i].burst *= pow(0.08, dt)
			players[i].trail.append({"pos": players[i].pos, "life": 0.16})
		for ghost in players[i].trail:
			ghost.life -= dt
		players[i].trail = players[i].trail.filter(func(ghost): return ghost.life > 0)
		if i == controlled:
			var sprint = Input.is_physical_key_pressed(KEY_SHIFT) and players[i].stamina > 0.04 and movement().length() > 0
			players[i].stamina = clampf(players[i].stamina + (-0.25 if sprint else 0.15) * dt, 0, 1)
			var speed = 100.0 if sprint else 70.0
			if charge >= 0:
				speed *= 0.3
			if players[i].action == "fake" or players[i].stun > 0:
				speed *= 0.2
			players[i].velocity = Vector2(players[i].velocity).move_toward(movement() * speed, 430 * dt)
			move_player(i, players[i].velocity * dt)
		else:
			players[i].stamina = minf(1, players[i].stamina + dt * 0.09)
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
		ball = players[carrier].pos + Vector2(players[carrier].hand * 10, -10 + absf(sin(elapsed * 13)) * 12)
		if players[carrier].action == "fake" or charge >= 0:
			ball = players[carrier].pos + Vector2(7, -29)
	elif loose and pickup_delay <= 0:
		for i in range(6):
			if players[i].pos.distance_to(ball) < 17:
				var old_possession = possession
				carrier = i
				possession = players[i].team
				play_call.clear()
				cuts.clear()
				transition_time = 3.5 if old_possession != possession else 0.0
				shot_clock = 14.0 if old_possession == possession else 24.0
				loose = false
				if possession == 0:
					controlled = i
				announce("REBOUND")
				break
	Tactics.decide(self, dt)
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
	if offset.length() > 0.1:
		players[i].facing = offset.normalized()

func update_ai(i: int, dt: float) -> void:
	var target: Vector2 = Tactics.target_for(self, i)
	var offset = target - Vector2(players[i].pos)
	var speed: float = 61 if i == carrier else 68
	if transition_time > 0:
		speed += 15
	if players[i].stun > 0:
		speed *= 0.18
	if Tactics.is_screened(self, i):
		speed *= 0.12
	if players[i].action == "fake":
		speed *= 0.15
	players[i].velocity = offset.normalized() * speed if offset.length() > 4 else Vector2.ZERO
	if offset.length() > 4:
		move_player(i, offset.normalized() * minf(offset.length(), speed * dt))

func contest_at(i: int) -> float:
	var pressure = 0.0
	for j in range(6):
		if players[j].team != players[i].team:
			var effectiveness = 0.25 if players[j].stun > 0 else 1.0
			pressure = maxf(pressure, clampf(1.0 - players[j].pos.distance_to(players[i].pos) / 48.0, 0, 1) * effectiveness)
	return pressure

func perform_move(kind: String) -> bool:
	if carrier != controlled or not flight.is_empty():
		return false
	var p: Dictionary = players[controlled]
	var cost = {"cross": 0.12, "spin": 0.23, "stepback": 0.18, "fake": 0.07}.get(kind, 2.0)
	if p.move_cd > 0 or p.stamina < cost:
		announce("RECOVER / NEED STAMINA", 0.7)
		return false
	p.stamina -= cost
	p.move_cd = 0.65 if kind != "spin" else 1.0
	p.action = kind
	p.action_time = 0.38 if kind != "fake" else 0.5
	var forward = (RIGHT - Vector2(p.pos)).normalized()
	var aim = movement()
	if aim == Vector2.ZERO:
		aim = forward
	p.hand *= -1
	match kind:
		"cross": p.burst = Vector2(aim.x * 0.2, p.hand).normalized() * 112
		"spin": p.burst = aim * 128
		"stepback": p.burst = -forward * 125
		"fake":
			p.burst = Vector2.ZERO
			charge = -1.0
			for j in range(3, 6):
				if players[j].pos.distance_to(p.pos) < 43 and players[j].stun <= 0:
					players[j].jump = 1.0
					players[j].stun = 0.8
					players[j].action = "block"
					players[j].action_time = 0.8
	if kind in ["cross", "spin"]:
		for j in range(3, 6):
			if players[j].pos.distance_to(p.pos) < 29:
				players[j].stun = maxf(players[j].stun, 0.32)
	announce({"cross": "CROSSOVER", "spin": "SPIN MOVE", "stepback": "STEP BACK", "fake": "PUMP FAKE"}[kind], 0.7)
	return true

func finish_for(i: int, aim: Vector2, sprint: bool) -> String:
	var hoop = RIGHT if players[i].team == 0 else LEFT
	var distance: float = players[i].pos.distance_to(hoop)
	var forward = (hoop - Vector2(players[i].pos)).normalized()
	if distance < 49:
		if sprint and players[i].stamina > 0.3:
			return "tomahawk" if absf(aim.y) > 0.4 else "two_hand"
		return "reverse" if aim.dot(forward) < -0.25 else "layup"
	if distance < 95:
		return "floater"
	return "jumper"

func shoot(i: int, timing: float) -> void:
	if carrier != i or not flight.is_empty() or clock_time <= 0:
		return
	var team: int = players[i].team
	var hoop = RIGHT if team == 0 else LEFT
	var distance: float = players[i].pos.distance_to(hoop)
	var pressure = contest_at(i)
	var finish = finish_for(i, movement() if i == controlled else Vector2.LEFT, Input.is_physical_key_pressed(KEY_SHIFT) if i == controlled else true)
	var momentum: float = players[i].velocity.length() / 100.0
	var perfect = timing > 0.93
	var probability = clampf(0.3 + timing * 0.63 - distance / 850.0 - pressure * 0.39 - momentum * 0.09 - (1.0 - players[i].stamina) * 0.12, 0.08, 0.97)
	if perfect and pressure < 0.35 and distance < 245:
		probability = 1.0
	var dunk = finish in ["two_hand", "tomahawk"]
	if dunk:
		probability = 0.96 - pressure * 0.2
		players[i].stamina = maxf(0, players[i].stamina - 0.24)
	elif finish in ["layup", "reverse", "floater"]:
		probability = clampf(0.65 + timing * 0.3 - pressure * (0.22 if finish == "reverse" else 0.36), 0.2, 0.98)
	players[i].jump = 1.0
	players[i].action = finish
	players[i].action_time = 0.75
	last_finish = finish
	flight = {"kind": "shot", "start": Vector2(players[i].pos) - Vector2(0, 26), "target": hoop, "t": 0.0, "duration": 0.48 if dunk else 0.85, "team": team, "points": 3 if distance > 160 else 2, "made": rng.randf() < probability, "green": perfect, "finish": finish, "shooter": i}
	carrier = -1
	charge = -1.0
	if team == 0:
		announce(finish.replace("_", " ").to_upper() if finish != "jumper" else ("PERFECT RELEASE" if perfect else ("EARLY / LATE" if timing < 0.65 else "GOOD RELEASE")), 1.2)
	tone(650 if perfect else 380, 0.06)

func pass_ball(give_go: bool = false) -> void:
	if carrier < 0 or not flight.is_empty():
		return
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
	begin_pass(best, give_go)

func begin_pass(receiver: int, give_go: bool = false) -> void:
	if carrier < 0 or receiver == carrier or players[receiver].team != possession:
		return
	var passer = carrier
	var hoop = RIGHT if possession == 0 else LEFT
	if give_go:
		cuts[passer] = {"target": hoop + Vector2(-39 if possession == 0 else 39, -26 if players[passer].pos.y > 200 else 26), "time": 3.3}
		announce("GIVE & GO • E TO RETURN", 1.5)
	players[passer].action = "pass"
	players[passer].action_time = 0.35
	flight = {"kind": "pass", "start": Vector2(players[passer].pos) + Vector2(0, -12), "target": Vector2(players[receiver].pos), "receiver": receiver, "passer": passer, "team": possession, "t": 0.0, "duration": clampf(players[passer].pos.distance_to(players[receiver].pos) / 380.0, 0.18, 0.6)}
	ball = flight.start
	carrier = -1
	charge = -1.0
	ai_clock = 0
	tone(270, 0.05)

func update_flight(dt: float) -> void:
	var previous_ball = ball
	flight.t += dt / flight.duration
	var t: float = minf(flight.t, 1)
	if flight.kind == "pass":
		flight.target = players[flight.receiver].pos
	ball = Vector2(flight.start).lerp(flight.target, t)
	if flight.kind == "pass":
		for j in range(6):
			if players[j].team == flight.team or players[j].stun > 0:
				continue
			var closest = Geometry2D.get_closest_point_to_segment(players[j].pos, previous_ball, ball)
			if players[j].pos.distance_to(closest) < 10 and Vector2(flight.start).distance_to(players[j].pos) > 16:
				gain_possession(j)
				match_stats.interceptions += 1
				announce("PASS INTERCEPTED!")
				return
	if t < 1:
		return
	var done = flight.duplicate()
	flight.clear()
	if done.kind == "pass":
		carrier = done.receiver
		if possession == 0:
			controlled = carrier
		return
	if done.made:
		scores[done.team] += done.points
		crowd_energy = 1.0
		burst(done.target, TEAL if done.team == 0 else PINK)
		tone(880, 0.12)
		reset_positions(1 - int(done.team))
		announce(("NIGHT OWLS" if done.team == 0 else "SUNSET CLUB") + "  +%d" % done.points)
	else:
		ball = Vector2(done.target) + Vector2(rng.randf_range(20, 65) * (-1 if done.team == 0 else 1), rng.randf_range(-45, 45))
		shot_clock = maxf(14.0, shot_clock)
		loose = true
		pickup_delay = 0.25
		announce("OFF THE RIM • GET THE BOARD", 1.2)
		tone(140, 0.08)

func defend() -> void:
	cooldown = 0.9
	players[controlled].jump = 1.0
	players[controlled].action = "block"
	players[controlled].action_time = 0.6
	if carrier >= 3 and players[controlled].pos.distance_to(players[carrier].pos) < 30:
		if rng.randf() < 0.62:
			gain_possession(controlled)
			announce("PICKPOCKET!")
		else:
			announce("REACH MISSED", 0.7)
	elif not flight.is_empty() and flight.kind == "shot" and flight.team == 1 and flight.t < 0.38 and players[controlled].pos.distance_to(flight.start) < 40:
		flight.made = false
		announce("BLOCKED!")
		tone(110, 0.1)

func gain_possession(i: int) -> void:
	carrier = i
	possession = players[i].team
	if possession == 0:
		controlled = i
	shot_clock = 24
	ai_clock = 0
	charge = -1
	loose = false
	flight.clear()
	play_call.clear()
	cuts.clear()
	transition_time = 3.5
	ball = players[i].pos

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
	PixelArt.play_guides(self)
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
		label("NC / 02", Vector2(38, 41), 14, TEAL)
		label("AFTER HOURS BASKETBALL", Vector2(38, 67), 10, GOLD)
		label("NEON", Vector2(35, 133), 64, WHITE)
		label("COURT", Vector2(35, 191), 64, TEAL)
		label("3 ON 3.  ALL HEART.", Vector2(40, 218), 14, WHITE)
		draw_rect(Rect2(40, 243, 228, 36), TEAL)
		label("ENTER  /  HIT THE COURT", Vector2(54, 267), 14, INK)
		label("WASD MOVE  /  SHIFT SPRINT", Vector2(344, 110), 11)
		label("SPACE  Hold shot / tap fake", Vector2(344, 134), 11)
		label("Z CROSS   X SPIN   C STEP BACK", Vector2(344, 158), 11, TEAL)
		label("V FAKE   E PASS   Q DEFEND", Vector2(344, 182), 11)
		label("R SCREEN   F GIVE & GO", Vector2(344, 206), 11, TEAL)
		label("H  Full controls during play", Vector2(344, 235), 10)
		label("T  OPPONENT: " + STYLES[style], Vector2(344, 268), 11, GOLD)
		label("CHANGE THE PACE. CREATE SPACE.", Vector2(40, 310), 11, TEAL)
		label("HANDLES + TEAM PLAY UPDATE  /  FOUR 90-SECOND QUARTERS", Vector2(40, 330), 9, Color("7c8ca4"))
	elif paused or mode == "final":
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.07, 0.86))
		centered("PAUSED" if paused else ("OWLS WIN" if scores[0] > scores[1] else "SUNSET WINS"), 160, 38, TEAL)
		centered("ESC  /  BACK TO THE COURT" if paused else "%d  —  %d     |     ENTER TO REMATCH" % [scores[0], scores[1]], 204, 14)
	if help_visible:
		draw_help()

func draw_arena() -> void:
	draw_rect(Rect2(0, 0, 640, 360), INK)
	PixelArt.spectators(self)
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
	# Original owl crest at center court.
	draw_colored_polygon(PackedVector2Array([Vector2(298, 183), Vector2(310, 189), Vector2(330, 189), Vector2(342, 183), Vector2(337, 211), Vector2(320, 222), Vector2(303, 211)]), Color("294b50"))
	draw_circle(Vector2(311, 201), 8, WHITE)
	draw_circle(Vector2(329, 201), 8, WHITE)
	draw_circle(Vector2(312, 201), 4, INK)
	draw_circle(Vector2(328, 201), 4, INK)
	draw_colored_polygon(PackedVector2Array([Vector2(316, 208), Vector2(324, 208), Vector2(320, 214)]), GOLD)
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
	PixelArt.player(self, i)

func draw_ball() -> void:
	var height = 0.0
	if not flight.is_empty():
		var arc_height = 56.0 if flight.kind == "shot" else 10.0
		if flight.get("finish", "") == "floater":
			arc_height = 72
		elif flight.get("finish", "") in ["two_hand", "tomahawk"]:
			arc_height = 23
		height = sin(minf(1, flight.t) * PI) * arc_height
	draw_circle(ball, 3, Color(0.05, 0.06, 0.1, 0.3))
	var p = (ball - Vector2(0, height)).round()
	draw_circle(p, 5, INK)
	draw_circle(p, 4, Color("f79645"))
	draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color("7d412d"))
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color("7d412d"))
	if charge >= 0:
		var origin: Vector2 = players[controlled].pos + Vector2(-21, -55)
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(46, 9)), INK)
		draw_rect(Rect2(origin, Vector2(42, 5)), Color("895465"))
		draw_rect(Rect2(origin + Vector2(19, 0), Vector2(5, 5)), TEAL)
		draw_rect(Rect2(origin + Vector2(charge / 1.4 * 42, -2), Vector2(2, 9)), WHITE)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, 640, 55), Color("111e33"))
	label("NEON / COURT", Vector2(16, 22), 12, TEAL)
	label("V0.2 / " + STYLES[style], Vector2(16, 41), 9, Color("7c8ca4"))
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
	centered("Z CROSS  X SPIN  C STEPBACK  V FAKE  R SCREEN  F GIVE&GO   /   H CONTROLS", 350, 9, Color("9daac0"))

func draw_help() -> void:
	draw_rect(Rect2(28, 30, 584, 302), INK)
	draw_rect(Rect2(28, 30, 584, 302), TEAL, false, 1)
	label("THE PLAYBOOK", Vector2(48, 62), 24, TEAL)
	label("WASD / ARROWS   Move", Vector2(48, 92), 12)
	label("SHIFT   Sprint / dunk near rim", Vector2(48, 115), 12)
	label("SPACE   Hold & release in green", Vector2(48, 138), 12)
	label("Tap SPACE / V   Pump fake", Vector2(48, 161), 12)
	label("E   Pass toward input / switch", Vector2(48, 184), 12)
	label("Q   Steal / block", Vector2(48, 207), 12)
	label("Z Cross   X Spin   C Step back", Vector2(334, 92), 12, TEAL)
	label("R   Call pick-and-roll", Vector2(334, 115), 12)
	label("F   Pass, then cut to basket", Vector2(334, 138), 12)
	label("Near rim: away + shot = reverse", Vector2(334, 161), 11)
	label("Sprint + side input = tomahawk", Vector2(334, 184), 11)
	label("Sprint + forward = two-hand dunk", Vector2(334, 207), 11)
	label("Moves cost stamina. Stop before a jumper for better accuracy.", Vector2(48, 251), 11, GOLD)
	label("Protect the ball. Pass around defenders. Use the screen, then feed the roll.", Vector2(48, 275), 10)
	centered("H / ESC  •  RETURN TO GAME", 311, 12, TEAL)
