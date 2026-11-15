extends Node2D
## Courtside Basketball. Court coordinates are gameplay coordinates.

const INK = Color("25384b")
const WHITE = Color("f5efdf")
const TEAL = Color("557289")
const PINK = Color("914e50")
const GOLD = Color("c59d56")
const COURT = Rect2(44, 91, 552, 218)
const LEFT = Vector2(68, 200)
const RIGHT = Vector2(572, 200)
const QUARTER_SECONDS = 90.0
const Tactics = preload("res://tactics.gd")
const PixelArt = preload("res://pixel_art.gd")
const Presentation = preload("res://presentation.gd")
const SpriteAtlas = preload("res://sprite_atlas.gd")
const CourtSound = preload("res://court_sound.gd")
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
var stats_visible = false
var crowd_energy = 0.0
var last_finish = ""
var muted = false
var bounce_time = 0.0
var bounce_audio: AudioStreamPlayer
var shot_feedback: Dictionary = {}
var rebound_team = -1
var team_stats: Array[Dictionary] = []
var last_pass: Dictionary = {}
var match_stats = {"ai_passes": 0, "screens": 0, "interceptions": 0}
const STYLES = ["BALANCED", "PRESSURE", "PERIMETER"]

func _ready() -> void:
	rng.randomize()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	bounce_audio = AudioStreamPlayer.new()
	add_child(bounce_audio)
	reset_stats()
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
	rebound_team = -1
	last_pass.clear()

func start_game() -> void:
	scores = [0, 0]
	quarter = 1
	clock_time = QUARTER_SECONDS
	mode = "play"
	paused = false
	help_visible = false
	stats_visible = false
	cooldown = 0.0
	pickup_delay = 0.0
	elapsed = 0.0
	crowd_energy = 0.0
	last_finish = ""
	bounce_time = 0.0
	shot_feedback.clear()
	reset_stats()
	players.clear()
	particles.clear()
	match_stats = {"ai_passes": 0, "screens": 0, "interceptions": 0}
	reset_positions(0)
	announce("TIP OFF • YOU ATTACK RIGHT", 2.5)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key = event.physical_keycode
	if event.pressed and key == KEY_M:
		muted = not muted
		audio.stop()
		bounce_audio.stop()
		return
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
		stats_visible = false
		charge = -1.0
	if event.pressed and key == KEY_H:
		stats_visible = false
		help_visible = not help_visible
		paused = help_visible
		charge = -1.0
	if event.pressed and key == KEY_TAB:
		help_visible = false
		stats_visible = not stats_visible
		paused = stats_visible
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
	bounce_time -= dt
	if carrier >= 0 and charge < 0 and players[carrier].action != "fake" and bounce_time <= 0:
		bounce_time = 0.46
		if not muted:
			CourtSound.play(bounce_audio, "bounce")
	crowd_energy = maxf(0, crowd_energy - dt * 0.45)
	transition_time = maxf(0, transition_time - dt)
	message_time = maxf(0, message_time - dt)
	if not shot_feedback.is_empty():
		shot_feedback.time -= dt
		if shot_feedback.time <= 0:
			shot_feedback.clear()
	if not last_pass.is_empty():
		last_pass.time += dt
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
			if offset.length() <= 0.01:
				offset = Vector2.RIGHT.rotated(float(i + j) * 1.1) * 0.1
			if offset.length() < 13:
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
		collect_rebound()
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
	team_stats[team].fga += 1
	if distance > 160:
		team_stats[team].three_attempts += 1
	if dunk:
		probability = 0.96 - pressure * 0.2
		players[i].stamina = maxf(0, players[i].stamina - 0.24)
	elif finish in ["layup", "reverse", "floater"]:
		probability = clampf(0.65 + timing * 0.3 - pressure * (0.22 if finish == "reverse" else 0.36), 0.2, 0.98)
	players[i].jump = 1.0
	players[i].action = finish
	players[i].action_time = 0.75
	last_finish = finish
	if team == 0:
		shot_feedback = {"timing": timing, "contest": pressure, "time": 2.4, "quality": "EXCELLENT" if perfect else ("GOOD" if timing > 0.65 else "OFF TIMING"), "finish": finish}
	flight = {"kind": "shot", "start": Vector2(players[i].pos) - Vector2(0, 26), "target": hoop, "t": 0.0, "duration": 0.48 if dunk else 0.85, "team": team, "points": 3 if distance > 160 else 2, "made": rng.randf() < probability, "green": perfect, "finish": finish, "shooter": i}
	flight["assisted"] = not last_pass.is_empty() and last_pass.receiver == i and last_pass.time < 4.0
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
	if carrier < 0 or receiver < 0 or receiver >= players.size() or receiver == carrier or players[receiver].team != possession or not flight.is_empty() or clock_time <= 0:
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
		var interceptor = -1
		var first_contact = INF
		for j in range(6):
			if players[j].team == flight.team or players[j].stun > 0:
				continue
			var closest = Geometry2D.get_closest_point_to_segment(players[j].pos, previous_ball, ball)
			if players[j].pos.distance_to(closest) < 10 and Vector2(flight.start).distance_to(players[j].pos) > 16:
				var along: float = previous_ball.distance_to(closest)
				if along < first_contact:
					first_contact = along
					interceptor = j
		if interceptor >= 0:
			team_stats[players[interceptor].team].steals += 1
			gain_possession(interceptor)
			match_stats.interceptions += 1
			announce("PASS INTERCEPTED!")
			return
	if t < 1:
		return
	var done = flight.duplicate()
	flight.clear()
	if done.kind == "pass":
		carrier = done.receiver
		last_pass = {"receiver": carrier, "passer": done.passer, "time": 0.0}
		if possession == 0:
			controlled = carrier
		return
	if done.made:
		scores[done.team] += done.points
		team_stats[done.team].fgm += 1
		if done.points == 3:
			team_stats[done.team].three_made += 1
		if done.get("assisted", false):
			team_stats[done.team].assists += 1
		crowd_energy = 1.0
		burst(done.target, TEAL if done.team == 0 else PINK)
		tone(880, 0.12)
		reset_positions(1 - int(done.team))
		announce(("HARBOR" if done.team == 0 else "SUMMIT") + "  +%d" % done.points)
	else:
		ball = Vector2(done.target) + Vector2(rng.randf_range(20, 65) * (-1 if done.team == 0 else 1), rng.randf_range(-45, 45))
		shot_clock = maxf(14.0, shot_clock)
		loose = true
		rebound_team = int(done.team)
		pickup_delay = 0.25
		announce("OFF THE RIM • GET THE BOARD", 1.2)
		tone(140, 0.08)

func defend() -> void:
	if possession == 0 and not loose:
		return
	cooldown = 0.9
	players[controlled].jump = 1.0
	players[controlled].action = "block"
	players[controlled].action_time = 0.6
	if carrier >= 3 and players[controlled].pos.distance_to(players[carrier].pos) < 30:
		if rng.randf() < 0.62:
			team_stats[0].steals += 1
			gain_possession(controlled)
			announce("PICKPOCKET!")
		else:
			announce("REACH MISSED", 0.7)
	elif not flight.is_empty() and flight.kind == "shot" and flight.team == 1 and flight.t < 0.38 and players[controlled].pos.distance_to(flight.start) < 40:
		if not flight.get("blocked", false):
			team_stats[0].blocks += 1
		flight.made = false
		flight["blocked"] = true
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
	rebound_team = -1
	last_pass.clear()

func collect_rebound() -> void:
	# The closest eligible player earns a loose ball, regardless of team or
	# roster order. A jumping player has a slightly larger collection reach.
	var winner = -1
	var nearest = INF
	for i in range(6):
		var distance: float = players[i].pos.distance_to(ball)
		var reach = 20.0 if players[i].jump > 0.1 else 17.0
		if distance < reach and distance < nearest:
			nearest = distance
			winner = i
	if winner < 0:
		return
	var old_possession = possession
	team_stats[players[winner].team].rebounds += 1
	gain_possession(winner)
	shot_clock = 14.0 if old_possession == possession else 24.0
	transition_time = 3.5 if old_possession != possession else 0.0
	announce("OFFENSIVE REBOUND" if old_possession == possession else "DEFENSIVE REBOUND")

func reset_stats() -> void:
	team_stats.clear()
	for team in range(2):
		team_stats.append({"fgm": 0, "fga": 0, "three_made": 0, "three_attempts": 0, "rebounds": 0, "steals": 0, "blocks": 0, "assists": 0})
	last_pass.clear()

func announce(text: String, duration: float = 1.8) -> void:
	message = text
	message_time = duration

func burst(pos: Vector2, color: Color) -> void:
	for i in range(20):
		particles.append({"pos": pos, "vel": Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, 25)), "life": rng.randf_range(0.4, 1.0), "color": color})

func tone(hz: float, _duration: float) -> void:
	if muted:
		return
	var kind = "release"
	if hz == 880:
		kind = "swish"
	elif hz == 270:
		kind = "pass"
	elif hz <= 150:
		kind = "rim"
	elif hz == 220:
		kind = "whistle"
	CourtSound.play(audio, kind)
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
		draw_rect(Rect2(p.pos, Vector2(2, 2)), p.color)
	draw_hud()
	if mode == "title":
		Presentation.title(self)
	elif paused or mode == "final":
		Presentation.overlay(self)
	if help_visible:
		draw_help()
	if stats_visible:
		Presentation.box_score(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if mode == "title":
			if Rect2(28, 258, 257, 38).has_point(get_global_mouse_position()):
				start_game()
			elif Rect2(25, 302, 260, 30).has_point(get_global_mouse_position()):
				style = (style + 1) % STYLES.size()
func draw_arena() -> void:
	Presentation.arena(self)

func draw_player(i: int) -> void:
	SpriteAtlas.player(self, i)

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
	Presentation.hud(self)

func draw_help() -> void:
	Presentation.help(self)
