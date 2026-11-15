extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		quit(1)
		assert(condition, description)
	print("PASS: " + description)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_game()
	game.rng.seed = 42
	check(game.players.size() == 6 and game.possession == 0, "3v3 tipoff")
	game.controlled = game.carrier
	game.pass_ball()
	check(game.carrier == -1 and game.flight.kind == "pass", "pass travels through flight state")
	game.update_flight(1.0)
	check(game.carrier == game.controlled and game.carrier < 3, "pass switches control to receiver")
	game.players[game.carrier].pos = Vector2(390, 200)
	for i in range(3, 6):
		game.players[i].pos = Vector2(150, 110 + i * 20)
	game.shoot(game.carrier, 1.0)
	check(game.flight.points == 3 and game.flight.made, "open perfect three is guaranteed")
	game.update_flight(1.0)
	check(game.scores[0] == 3 and game.possession == 1, "made three scores and changes possession")
	game.shoot(game.carrier, 0.1)
	game.flight.made = false
	game.update_flight(1.0)
	check(game.loose and game.carrier == -1, "miss creates rebound")
	game.players[0].pos = game.ball
	game.pickup_delay = 0
	game.tick(0.001)
	check(game.carrier == 0 and game.possession == 0, "defensive rebound changes possession")
	game.shot_clock = 0.001
	game.tick(0.01)
	check(game.possession == 1, "24-second violation")
	game.clock_time = 0
	game.tick(0.001)
	check(game.quarter == 2 and game.clock_time > 80, "quarter transition")
	game.quarter = 4
	game.scores = [10, 10]
	game.clock_time = 0
	game.tick(0.001)
	check(game.mode == "play" and game.clock_time == 45, "tie enters overtime")
	game.scores = [12, 10]
	game.clock_time = 0
	game.tick(0.001)
	check(game.mode == "final", "final buzzer ends game")
	game.start_game()
	game.rng.seed = 99
	for i in range(18000):
		game.tick(1.0 / 60.0)
		for player in game.players:
			check_bounds(player.pos)
	check(game.scores[1] > 0, "AI scores during extended simulation")
	print("ALL MATCH TESTS PASSED")
	game.audio.stop()
	game.audio.stream = null
	await process_frame
	game.free()
	await process_frame
	quit()

func check_bounds(pos: Vector2) -> void:
	assert(pos.x >= 51 and pos.x <= 589 and pos.y >= 100 and pos.y <= 301)
