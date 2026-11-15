extends SceneTree
## Exercises Godot's actual input state and fixed-step movement.
var game

func _initialize() -> void:
	call_deferred("run")

func send_key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func require(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		quit(1)
		assert(condition, description)
	print("PASS: " + description)

func run() -> void:
	Input.use_accumulated_input = false
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	send_key(KEY_ENTER, true)
	send_key(KEY_ENTER, false)
	await frames(2)
	require(game.mode == "play", "Enter starts from title through engine input")
	var i: int = game.controlled
	var start: Vector2 = game.players[i].pos
	send_key(KEY_D, true)
	await frames(12)
	require(game.players[i].pos.x > start.x + 5 and game.players[i].velocity.x > 50, "held D accelerates player")
	send_key(KEY_SHIFT, true)
	await frames(15)
	require(game.players[i].velocity.x > 85 and game.players[i].stamina < 0.98, "held Shift adds speed and spends stamina")
	send_key(KEY_D, false)
	send_key(KEY_SHIFT, false)
	await frames(20)
	require(game.players[i].velocity.length() < 1, "release decelerates to rest")
	game.reset_positions(0)
	i = game.controlled
	for j in range(3, 6):
		game.players[j].pos = Vector2(70, 120 + j * 20)
	send_key(KEY_SPACE, true)
	await frames(40)
	require(game.charge > 0.55 and game.charge < 0.8, "held Space charges shot meter")
	send_key(KEY_SPACE, false)
	await frames(2)
	require(not game.flight.is_empty() and game.flight.kind == "shot", "release launches the shot")
	await frames(65)
	send_key(KEY_H, true)
	send_key(KEY_H, false)
	await frames(2)
	var clock_before: float = game.clock_time
	await frames(8)
	require(game.paused and game.clock_time == clock_before, "H freezes clock in actual physics loop")
	send_key(KEY_H, true)
	send_key(KEY_H, false)
	await frames(4)
	require(not game.paused and game.clock_time < clock_before, "H resumes physics")
	print("ALL ENGINE INPUT CHECKS PASSED")
	game.free()
	quit()
