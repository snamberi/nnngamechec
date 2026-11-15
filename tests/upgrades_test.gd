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

func setup() -> void:
	game.start_game()
	game.rng.seed = 123
	game.set_physics_process(false)
	game.controlled = game.carrier
	for i in range(3, 6):
		game.players[i].pos = Vector2(100, 120 + i * 25)
	game.players[game.carrier].pos = Vector2(380, 200)
	game.ball = game.players[game.carrier].pos

func key(code: int, pressed: bool = true) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game._unhandled_key_input(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	setup()
	var original_hand: float = game.players[game.carrier].hand
	key(KEY_Z)
	check(game.players[game.carrier].action == "cross" and game.players[game.carrier].hand == -original_hand, "Z crossover switches dribble hand")
	check(game.players[game.carrier].stamina < 0.9, "crossover spends stamina")
	check(not game.perform_move("spin"), "move cooldown prevents spam")
	var origin: Vector2 = game.players[game.carrier].pos
	for i in range(15):
		game.tick(1.0 / 60)
	check(absf(game.players[game.carrier].pos.y - origin.y) > 10, "crossover creates lateral separation over time")
	setup()
	key(KEY_X)
	origin = game.players[game.carrier].pos
	for i in range(15):
		game.tick(1.0 / 60)
	check(game.players[game.carrier].pos.x > origin.x + 15, "spin drives forward")
	setup()
	key(KEY_C)
	origin = game.players[game.carrier].pos
	for i in range(15):
		game.tick(1.0 / 60)
	check(game.players[game.carrier].pos.x < origin.x - 15, "stepback creates shooting space")
	setup()
	game.players[game.carrier].stamina = 0.01
	check(not game.perform_move("spin"), "exhausted player cannot spin")
	setup()
	game.players[3].pos = game.players[game.carrier].pos + Vector2(22, 0)
	var before: float = game.contest_at(game.carrier)
	key(KEY_SPACE)
	game.tick(0.08)
	key(KEY_SPACE, false)
	check(game.carrier >= 0 and game.flight.is_empty() and game.players[game.carrier].action == "fake", "quick shot tap pump-fakes without releasing ball")
	check(game.players[3].stun > 0 and game.contest_at(game.carrier) < before, "pump fake draws a defender and reduces contest")
	setup()
	game.players[game.carrier].pos = Vector2(540, 200)
	check(game.finish_for(game.carrier, Vector2.RIGHT, false) == "layup", "normal close finish is layup")
	check(game.finish_for(game.carrier, Vector2.LEFT, false) == "reverse", "away input selects reverse layup")
	check(game.finish_for(game.carrier, Vector2.RIGHT, true) == "two_hand", "sprint selects two-hand dunk")
	check(game.finish_for(game.carrier, Vector2.DOWN, true) == "tomahawk", "lateral sprint selects tomahawk")
	game.players[game.carrier].stamina = 0.1
	check(game.finish_for(game.carrier, Vector2.RIGHT, true) == "layup", "low stamina falls back from dunk to layup")
	game.players[game.carrier].pos = Vector2(500, 200)
	check(game.finish_for(game.carrier, Vector2.RIGHT, false) == "floater", "short-range finish is floater")
	setup()
	key(KEY_R)
	check(not game.play_call.is_empty() and game.play_call.phase == "setup", "R calls pick and roll")
	var screener: int = game.play_call.screener
	game.players[screener].pos = game.play_call.spot
	game.Tactics.tick(game, 0.02)
	check(game.play_call.phase == "hold", "screen becomes planted after teammate arrives")
	game.players[3].pos = game.play_call.spot + Vector2(15, 0)
	check(game.Tactics.is_screened(game, 3), "planted screen slows nearby defender")
	game.Tactics.tick(game, 1.2)
	check(game.play_call.phase == "roll" and game.Tactics.target_for(game, screener).x > 500, "screener rolls to basket")
	setup()
	var passer: int = game.carrier
	key(KEY_F)
	check(game.flight.kind == "pass" and game.cuts.has(passer), "F launches give-and-go pass and cutter")
	game.update_flight(1)
	check(game.controlled == game.carrier and game.carrier != passer, "receiver remains user-controlled after give-and-go")
	check(game.Tactics.target_for(game, passer).x > 500, "passer cuts to basket")
	setup()
	game.players[0].pos = Vector2(500, 200)
	game.players[3].pos = Vector2(440, 200)
	game.begin_pass(0)
	game.update_flight(1)
	check(game.possession == 1 and game.carrier == 3 and game.flight.is_empty(), "defender intercepts pass lane, including large time step")
	setup()
	game.shot_clock = 0.05
	game.begin_pass(0)
	game.tick(0.1)
	check(game.possession == 1 and game.shot_clock > 23, "pass flight cannot bypass shot clock")
	setup()
	game.Tactics.assign_defenders(game)
	var matchups: Array = game.assignments.values()
	check(matchups.size() == 3 and matchups.has(0) and matchups.has(1) and matchups.has(2), "defensive rotations cover each attacker")
	setup()
	key(KEY_H)
	origin = game.players[game.carrier].pos
	var time_before: float = game.clock_time
	game.tick(1)
	check(game.paused and game.help_visible and game.clock_time == time_before, "help pauses the match")
	key(KEY_ESCAPE)
	check(not game.paused and not game.help_visible, "escape closes help and resumes")
	var total_passes = 0
	var total_screens = 0
	for style in range(3):
		setup()
		game.style = style
		game.reset_positions(1)
		for frame in range(60 * 100):
			game.tick(1.0 / 60)
			for p in game.players:
				assert(p.pos.is_finite() and p.pos.x >= 51 and p.pos.x <= 589 and p.pos.y >= 100 and p.pos.y <= 301)
				assert(p.stamina >= 0 and p.stamina <= 1)
		check(game.scores[1] > 0, "AI style %s completes scoring possessions" % game.STYLES[style])
		total_passes += game.match_stats.ai_passes
		total_screens += game.match_stats.screens
	check(total_passes > 0, "AI makes passes in live simulations")
	check(total_screens > 0, "AI calls screens in live simulations")
	print("ALL %d UPGRADE CHECKS PASSED; AI passes=%d, screens=%d" % [count, total_passes, total_screens])
	game.free()
	quit()
