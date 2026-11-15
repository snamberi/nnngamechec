extends RefCounted
## Team decisions and play state live here; game.gd owns the match state.

static func call_screen(g, handler: int = -1) -> bool:
	if handler < 0:
		handler = g.controlled
	if g.carrier != handler or not g.play_call.is_empty():
		return false
	var screener = -1
	var nearest = INF
	for i in range(6):
		if i == handler or g.players[i].team != g.possession:
			continue
		var distance: float = g.players[i].pos.distance_to(g.players[handler].pos)
		if distance < nearest:
			nearest = distance
			screener = i
	var forward = Vector2.RIGHT if g.possession == 0 else Vector2.LEFT
	var spot: Vector2 = g.players[handler].pos + forward * 25 + Vector2(0, 17)
	spot.x = clampf(spot.x, 60, 580)
	spot.y = clampf(spot.y, 108, 290)
	g.play_call = {"handler": handler, "screener": screener, "team": g.possession, "phase": "setup", "spot": spot, "time": 0.0}
	g.match_stats.screens += 1
	if g.possession == 0:
		g.announce("PICK & ROLL • USE THE SCREEN", 1.6)
	return true

static func tick(g, dt: float) -> void:
	for i in g.cuts.keys():
		g.cuts[i].time -= dt
		if g.cuts[i].time <= 0 or g.players[i].team != g.possession:
			g.cuts.erase(i)
	if not g.play_call.is_empty():
		var play: Dictionary = g.play_call
		play.time += dt
		if play.team != g.possession or play.time > 7.0:
			g.play_call.clear()
		elif play.phase == "setup":
			if g.players[play.screener].pos.distance_to(play.spot) < 8:
				play.phase = "hold"
				play.time = 0.0
			elif play.time > 3:
				g.play_call.clear()
		elif play.phase == "hold":
			g.players[play.screener].action = "screen"
			g.players[play.screener].action_time = 0.2
			if play.time > 1.1:
				play.phase = "roll"
				play.time = 0.0
		elif play.phase == "roll" and play.time > 2.8:
			g.play_call.clear()
	assign_defenders(g)

static func assign_defenders(g) -> void:
	# Greedy nearest matchups; the closest defender takes the ball, then
	# remaining defenders rotate to uncovered opponents instead of dogpiling.
	var previous: Dictionary = g.assignments.duplicate()
	g.assignments.clear()
	var defenders: Array = []
	var attackers: Array = []
	for i in range(6):
		if g.players[i].team == g.possession:
			attackers.append(i)
		else:
			defenders.append(i)
	if g.carrier >= 0:
		var on_ball: int = defenders[0]
		for i in defenders:
			# Keep the current matchup unless a teammate is clearly closer.
			# This avoids rapid switching when two defenders are side by side.
			var distance: float = g.players[i].pos.distance_to(g.ball) - (10 if previous.get(i, -1) == g.carrier else 0)
			var best_distance: float = g.players[on_ball].pos.distance_to(g.ball) - (10 if previous.get(on_ball, -1) == g.carrier else 0)
			if distance < best_distance:
				on_ball = i
		g.assignments[on_ball] = g.carrier
		defenders.erase(on_ball)
		attackers.erase(g.carrier)
	for attacker in attackers:
		var best: int = defenders[0]
		for i in defenders:
			if g.players[i].pos.distance_to(g.players[attacker].pos) < g.players[best].pos.distance_to(g.players[attacker].pos):
				best = i
		g.assignments[best] = attacker
		defenders.erase(best)

static func target_for(g, i: int) -> Vector2:
	var team: int = g.players[i].team
	var hoop: Vector2 = g.RIGHT if team == 0 else g.LEFT
	var forward = Vector2.RIGHT if team == 0 else Vector2.LEFT
	if g.loose:
		return g.ball
	if not g.flight.is_empty() and g.flight.kind == "shot":
		return g.flight.target + Vector2((i % 3 - 1) * 20, (i % 2 * 2 - 1) * 23)
	if g.possession == team:
		if g.cuts.has(i) and i != g.carrier:
			return g.cuts[i].target
		if not g.play_call.is_empty():
			var play: Dictionary = g.play_call
			if i == play.screener:
				if play.phase == "roll":
					return hoop - forward * 35 + Vector2(0, 22)
				return play.spot
			if i == play.handler and play.phase == "hold":
				return play.spot + forward * 38 + Vector2(0, 22)
		if i == g.carrier:
			if team == 1 and g.style == 2:
				return hoop - forward * 172 + Vector2(0, sin(g.elapsed * 0.7) * 55)
			return hoop - forward * 42 + Vector2(0, sin(g.elapsed * 1.2 + i) * 38)
		if g.transition_time > 0:
			return hoop - forward * (45 + i % 3 * 33) + Vector2(0, (i % 3 - 1) * 66)
		# Wide wings and one backdoor cutter, cycling deterministically.
		if int(g.elapsed / 4.0) % 3 == i % 3 and g.ball.distance_to(hoop) < 210:
			return hoop - forward * 42 + Vector2(0, 35 if i % 2 else -35)
		return Vector2(clampf(g.ball.x + forward.x * 65, 155, 485), 116 + i % 3 * 82)
	var own_hoop: Vector2 = g.LEFT if team == 0 else g.RIGHT
	var opponent: int = g.assignments.get(i, (i + 3) % 6)
	var enemy: Vector2 = g.players[opponent].pos
	if opponent == g.carrier:
		return enemy + enemy.direction_to(own_hoop) * (13 if g.style == 1 and team == 1 else 20)
	var target = enemy.lerp(own_hoop, 0.1)
	# Weak-side help collapses on a drive; the other matchup stays spaced.
	if g.carrier >= 0 and g.ball.distance_to(own_hoop) < 105 and i % 3 == (g.carrier + 1) % 3:
		target = g.ball.lerp(own_hoop, 0.3)
	return target

static func is_screened(g, i: int) -> bool:
	if g.play_call.is_empty() or g.play_call.phase != "hold" or g.players[i].team == g.play_call.team:
		return false
	return g.players[i].pos.distance_to(g.players[g.play_call.screener].pos) < 25

static func pass_lane_clear(g, passer: int, receiver: int) -> bool:
	for j in range(6):
		if g.players[j].team == g.players[passer].team:
			continue
		var closest = Geometry2D.get_closest_point_to_segment(g.players[j].pos, g.players[passer].pos, g.players[receiver].pos)
		if g.players[j].pos.distance_to(closest) < 15:
			return false
	return true

static func decide(g, dt: float) -> void:
	if not g.flight.is_empty() or g.carrier < 0 or g.clock_time <= 0:
		return
	# Pressure defenders can steal exposed dribbles, but successful moves
	# protect the ball briefly. Cooldowns prevent per-frame lottery rolls.
	if g.possession == 0:
		for j in range(3, 6):
			var p: Dictionary = g.players[j]
			if p.steal_cd <= 0 and p.stun <= 0 and p.pos.distance_to(g.players[g.carrier].pos) < 21:
				p.steal_cd = 1.7
				if g.players[g.carrier].action == "idle" and g.rng.randf() < (0.26 if g.style == 1 else 0.12):
					g.team_stats[1].steals += 1
					g.gain_possession(j)
					g.announce("STRIPPED • GET BACK!")
					return
		return
	g.ai_clock += dt
	var handler: int = g.carrier
	var pressure: float = g.contest_at(handler)
	if g.style == 2 and pressure < 0.3 and g.ai_clock > 1.3 and g.players[handler].pos.distance_to(g.LEFT) < 195:
		g.shoot(handler, g.rng.randf_range(0.75, 0.98))
		g.ai_clock = 0
		return
	if g.ai_clock > 0.8 and g.play_call.is_empty() and pressure > 0.25 and g.style != 2:
		call_screen(g, handler)
	var best = -1
	var best_value = -INF
	for i in range(3, 6):
		if i == handler or not pass_lane_clear(g, handler, i):
			continue
		var value: float = (1.0 - g.contest_at(i)) * 100 - g.players[i].pos.distance_to(g.LEFT) * 0.2
		if g.cuts.has(i):
			value += 25
		if value > best_value:
			best_value = value
			best = i
	var own_value: float = (1.0 - pressure) * 100 - g.players[handler].pos.distance_to(g.LEFT) * 0.2
	if best >= 0 and g.ai_clock > 0.85 and g.shot_clock > 4 and (best_value > own_value + 8 or (g.style == 2 and g.ai_clock > 1.7)):
		g.begin_pass(best, g.style != 2)
		g.match_stats.ai_passes += 1
		return
	var shooting_range = 190 if g.style == 2 else 110
	if (g.players[handler].pos.distance_to(g.LEFT) < shooting_range and g.ai_clock > 1.7) or g.shot_clock < 2:
		g.shoot(handler, g.rng.randf_range(0.66, 0.98))
		g.ai_clock = 0
