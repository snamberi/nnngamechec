extends SceneTree

const Atlas = preload("res://sprite_atlas.gd")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		quit(1)
		assert(condition, description)
	print("PASS: " + description)

func run() -> void:
	check(Atlas.ensure_loaded(), "animation sheet loads without editor import cache")
	check(Atlas.source_size.x >= 1024 and Atlas.source_size.y >= 1024, "source atlas retains full sprite detail")
	check(Atlas.source_rects.size() == 64 and Atlas.frame_bounds.size() == 64, "8 by 8 grid yields 64 nonempty animation frames")
	check(Atlas.textures.size() == 6, "six player palette variants")
	for variant in Atlas.textures:
		check(variant.size() == 64, "player variant has all 64 frames")
		for frame in variant:
			var pixels: Image = frame.get_image()
			assert(pixels.get_used_rect().size.y > 20)
			assert(pixels.get_used_rect().position.y > 0)
	check(Atlas.textures[0][0].get_image().get_data() != Atlas.textures[3][0].get_image().get_data(), "away uniforms have distinct palette")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_game()
	var i: int = game.controlled
	var actions = {"jumper": 3, "layup": 4, "reverse": 4, "two_hand": 5, "tomahawk": 5, "pass": 6, "block": 7, "screen": 7}
	for action in actions:
		game.players[i].action = action
		game.players[i].action_time = 0.25
		check(Atlas.animation_for(game, i).y == actions[action], "action %s selects its sheet row" % action)
	game.players[i].action = "jumper"
	game.players[i].action_time = 0.7
	var early = Atlas.animation_for(game, i)
	game.players[i].action_time = 0.1
	check(Atlas.animation_for(game, i).x > early.x, "shot progresses through frames")
	game.players[i].action = "idle"
	game.players[i].velocity = Vector2(70, 0)
	check(Atlas.animation_for(game, i).y == 2, "moving ball handler uses dribble row")
	game.carrier = (i + 1) % 3
	check(Atlas.animation_for(game, i).y == 1, "off-ball movement uses run row")
	game.free()
	print("ALL ATLAS CHECKS PASSED")
	quit()
