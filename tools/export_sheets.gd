extends SceneTree
## Rebuild distributable transparent atlases from the generated master image.
## Run: godot --headless --path . --script res://tools/export_sheets.gd

const Atlas = preload("res://sprite_atlas.gd")
const FRAME_SECONDS = [0.25, 1.0 / 14.0, 1.0 / 9.0, 0.75 / 8.0, 0.75 / 8.0, 0.75 / 8.0, 0.35 / 8.0, 0.6 / 8.0]

func _initialize() -> void:
	if not Atlas.ensure_loaded():
		quit(1)
		return
	var files: Array = []
	for variant in range(6):
		var sheet = Image.create(640, 640, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		for row in range(8):
			for frame in range(8):
				var sprite: Image = Atlas.textures[variant][row * 8 + frame].get_image()
				sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, Atlas.CANVAS), Vector2i(frame * 80, row * 80))
		var filename = "player_%02d.png" % (variant + 1)
		var error = sheet.save_png("res://assets/" + filename)
		if error != OK:
			push_error("Could not write %s (error %d)" % [filename, error])
			quit(1)
			return
		files.append({"file": filename, "player_index": variant, "team": "home" if variant < 3 else "away", "skin_variant": variant % 3})
		print("EXPORTED: assets/" + filename)
	var animations: Array = []
	for row in range(8):
		animations.append({"name": Atlas.ROWS[row], "row": row, "first_column": 0, "frame_count": 8, "frame_duration_seconds": FRAME_SECONDS[row], "loop": row <= 2, "timing": "movement-driven when moving; duration is nominal" if row in [1, 2] else "action-progress or elapsed-time driven"})
	var metadata = {
		"format_version": 1,
		"source": "players.png",
		"generator": "res://tools/export_sheets.gd",
		"sheet_size": [640, 640],
		"cell_size": [80, 80],
		"columns": 8,
		"rows": 8,
		"pivot": [40, 70],
		"pivot_origin": "top-left of each cell; pivot marks floor contact",
		"alpha": "straight RGBA8, transparent background",
		"filter": "nearest",
		"files": files,
		"animations": animations,
		"action_mapping": {
			"cross": "dribble", "spin": "dribble", "stepback": "dribble",
			"jumper": "shot", "fake": "shot (first four frames)",
			"reverse": "layup", "floater": "layup", "two_hand": "dunk", "tomahawk": "dunk",
			"block": "defend", "screen": "defend (hold column 1)"
		},
		"runtime_notes": "Game uses the same cached frames derived from players.png. Charge holds the first four shot frames. Run cycles follow distance; stationary dribbling runs at 9 fps. Game code supplies horizontal facing flip and vertical jump offset."
	}
	var file = FileAccess.open("res://assets/animations.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write assets/animations.json")
		quit(1)
		return
	file.store_string(JSON.stringify(metadata, "\t") + "\n")
	file.close()
	print("EXPORTED: assets/animations.json")
	quit()
