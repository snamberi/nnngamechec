extends SceneTree
var game
var count = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		quit(1)
		assert(condition, description)
	count += 1
	print("PASS: " + description)

func reset() -> void:
	game.start_game()
	game.rng.seed = 17
	for i in range(6):
		game.players[i].pos = Vector2(60 + i * 75, 120)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	reset()
	game.cooldown = 0.9
	game.crowd_energy = 1
	game.elapsed = 80
	game.shot_feedback = {"quality": "OLD", "time": 2.0}
	game.start_game()
	check(game.cooldown == 0 and game.elapsed == 0 and game.crowd_energy == 0 and game.shot_feedback.is_empty(), "rematch clears cooldowns, feedback and old animation state")
	reset()
	game.carrier = -1
	game.loose = true
	game.ball = Vector2(300, 220)
	game.players[0].pos = Vector2(314, 220)
	game.players[5].pos = Vector2(302, 220)
	game.collect_rebound()
	check(game.carrier == 5 and game.possession == 1, "nearest rebounder wins regardless of roster order")
	check(game.team_stats[1].rebounds == 1 and game.shot_clock == 24, "defensive rebound records stat and full clock")
	reset()
	game.carrier = -1
	game.loose = true
	game.ball = Vector2(300, 220)
	game.players[0].pos = game.ball
	game.collect_rebound()
	check(game.carrier == 0 and game.shot_clock == 14 and game.team_stats[0].rebounds == 1, "offensive rebound records stat and 14 seconds")
	reset()
	game.carrier = 0
	game.controlled = 0
	game.players[0].pos = Vector2(120, 200)
	game.players[1].pos = Vector2(520, 200)
	game.players[3].pos = Vector2(440, 200)
	game.players[5].pos = Vector2(260, 200)
	game.begin_pass(1)
	game.update_flight(1)
	check(game.carrier == 5, "pass goes to first interceptor along flight, not lowest roster index")
	check(game.team_stats[1].steals == 1, "interception records steal")
	reset()
	game.begin_pass(-1)
	check(game.flight.is_empty(), "invalid pass target does not crash or release ball")
	game.clock_time = 0
	game.begin_pass(0)
	check(game.flight.is_empty(), "cannot begin pass after buzzer")
	reset()
	game.carrier = 0
	game.controlled = 0
	game.players[0].pos = Vector2(300, 250)
	game.players[1].pos = Vector2(390, 250)
	for i in range(3, 6):
		game.players[i].pos = Vector2(100, 120 + i * 10)
	game.begin_pass(1)
	game.update_flight(1)
	game.shoot(1, 1.0)
	check(game.team_stats[0].fga == 1 and game.team_stats[0].three_attempts == 1, "three point shot increments attempts")
	check(game.shot_feedback.quality == "EXCELLENT" and game.shot_feedback.contest == 0, "shot feedback reports timing and openness")
	game.update_flight(1)
	check(game.team_stats[0].fgm == 1 and game.team_stats[0].three_made == 1 and game.team_stats[0].assists == 1, "made pass-assisted three updates box score")
	reset()
	game.players[0].pos = Vector2(300, 240)
	game.players[1].pos = Vector2(300, 240)
	game.tick(0.001)
	check(game.players[0].pos.distance_to(game.players[1].pos) > 1, "exact player overlap is resolved")
	game.start_game()
	check(game.team_stats[0].fga == 0 and game.team_stats[1].steals == 0, "new game resets statistics")
	print("ALL %d POLISH CHECKS PASSED" % count)
	game.free()
	quit()
